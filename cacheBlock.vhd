library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_block is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;

        CA        : in  std_logic_vector(5 downto 0);
        CD_in     : in  std_logic_vector(7 downto 0);
        CD_out    : out std_logic_vector(7 downto 0);
        OE_CD     : in  std_logic;                
        RD_WR     : in  std_logic;                    
        START     : in  std_logic;                     

        MD_in     : in  std_logic_vector(7 downto 0);
        MA_out    : out std_logic_vector(7 downto 0);

        latch_req       : in  std_logic;
        cache_we        : in  std_logic;
        src_is_mem      : in  std_logic;
        byte_sel        : in  std_logic_vector(1 downto 0);
        set_tag_valid   : in  std_logic; 
        invalidate_all  : in  std_logic;

        hit         : out std_logic       -- 1 when tag matches & valid for current index (using latched addr)
    );
end cache_block;

architecture rtl of cache_block is


    signal tag_q      : std_logic_vector(1 downto 0) := (others => '0');
    signal index_q    : unsigned(1 downto 0)         := (others => '0');
    signal byte_q     : unsigned(1 downto 0)         := (others => '0');
    signal rdwr_q     : std_logic := '0';
    signal cd_in_q    : std_logic_vector(7 downto 0) := (others => '0');

    -- 4 blocks × 4 bytes of 8-bit
    type block_t is array (0 to 3) of std_logic_vector(7 downto 0);
    type cache_t is array (0 to 3) of block_t;
    signal data_ram : cache_t;

    -- tag/valid arrays per block
    type tag_array_t is array (0 to 3) of std_logic_vector(1 downto 0);
    type val_array_t is array (0 to 3) of std_logic;
    signal tag_ram : tag_array_t := (others => (others => '0'));
    signal valid_b : val_array_t := (others => '0');

    -- Output register to the CPU, latched on negedge when OE_CD=1
    signal cd_out_q : std_logic_vector(7 downto 0) := (others => '0');

    -- Combinational helpers
    function to_uint(s: std_logic_vector) return integer is
    begin
        return to_integer(unsigned(s));
    end function;

begin
    CD_out <= cd_out_q;

    process(clk)
    begin
        if falling_edge(clk) then
            if reset = '1' then
                tag_q   <= (others => '0');
                index_q <= (others => '0');
                byte_q  <= (others => '0');
                rdwr_q  <= '0';
                cd_in_q <= (others => '0');
            else
                if latch_req = '1' then
                    tag_q   <= CA(5 downto 4);
                    index_q <= unsigned(CA(3 downto 2));
                    byte_q  <= unsigned(CA(1 downto 0));
                    rdwr_q  <= RD_WR;
                    cd_in_q <= CD_in;
                end if;
            end if;
        end if;
    end process;

    hit <= '1' when (valid_b(to_integer(index_q)) = '1' and
                     tag_ram(to_integer(index_q))  = tag_q) else '0';

    MA_out <= tag_q & std_logic_vector(index_q) & "00";

    process(clk)
        variable idx  : integer;
        variable bsel : integer;
        variable din  : std_logic_vector(7 downto 0);
    begin
        if falling_edge(clk) then
            if reset = '1' then
                valid_b <= (others => '0');
                -- optional: clear data/tag (not strictly required)
                tag_ram <= (others => (others => '0'));
            else
                -- Invalidate all (e.g., at reset entry), optional pulse
                if invalidate_all = '1' then
                    valid_b <= (others => '0');
                end if;

                idx  := to_integer(index_q);
                bsel := to_integer(unsigned(byte_sel));

                -- Cache write (either write-hit from CPU or read-miss fill from MD)
                if cache_we = '1' then
                    if src_is_mem = '1' then
                        din := MD_in;      -- fill from memory
                    else
                        din := cd_in_q;    -- write-hit from CPU
                    end if;

                    data_ram(idx)(bsel) <= din;
                end if;

                -- Set tag + valid (typically the first fill byte during a read-miss)
                if set_tag_valid = '1' then
                    tag_ram(idx) <= tag_q;
                    valid_b(idx) <= '1';
                end if;

                -- Output latch to CPU when OE_CD asserted by FSM
                if OE_CD = '1' then
                    cd_out_q <= data_ram(idx)(to_integer(unsigned(byte_sel)));
                end if;
            end if;
        end if;
    end process;

end rtl;

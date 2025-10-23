library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_block is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;

        -- Selected by external decoder (1 when this line is addressed)
        enable      : in  std_logic;

        -- CPU side
        data_in     : in  std_logic_vector(7 downto 0);
        data_out    : out std_logic_vector(7 downto 0);
        byte_sel    : in  std_logic_vector(1 downto 0);
        rd_wr       : in  std_logic;                     -- 1=read, 0=write (original CPU op)

        -- Memory side (for refill)
        mem_in      : in  std_logic_vector(7 downto 0);

        -- Top-level generated controls (not from the FSM)
        we          : in  std_logic;                     -- one-negedge pulse for writes (hit or refill)
        set_tag     : in  std_logic;                     -- one-negedge pulse when first refill byte arrives
        tag_in      : in  std_logic_vector(1 downto 0);  -- tag to compare / to write on refill

        -- Status back up
        valid_out   : out std_logic;
        tag_out     : out std_logic_vector(1 downto 0);
        hit_miss    : out std_logic                      -- 1=hit, 0=miss (combinational)
    );
end cache_block;

architecture rtl of cache_block is
    -- 1 line = 4 bytes
    type block_t is array (0 to 3) of std_logic_vector(7 downto 0);
    signal data_ram : block_t := (others => (others => '0'));

    signal tag_reg  : std_logic_vector(1 downto 0) := (others => '0');
    signal valid    : std_logic := '0';
    signal dout     : std_logic_vector(7 downto 0) := (others => '0');

    -- Internal hit detect (so we don't read an OUT port)
    signal is_hit   : std_logic;
begin
    -- Expose status/data
    data_out  <= dout;
    valid_out <= valid;
    tag_out   <= tag_reg;

    -- Combinational hit (OK to read internal signals)
    is_hit   <= '1' when (enable = '1' and valid = '1' and tag_reg = tag_in) else '0';
    hit_miss <= is_hit;

    -- Registered operations
    process(clk)
        variable idx : integer;
    begin
        if rising_edge(clk) then
            if reset = '1' then
                data_ram <= (others => (others => '0'));
                tag_reg  <= (others => '0');
                valid    <= '0';
                dout     <= (others => '0');

            elsif enable = '1' then
                idx := to_integer(unsigned(byte_sel));

                -- Write path:
                --  - refill (read-miss) writes mem_in with rd_wr='1' and we='1'
                --  - write-hit writes data_in with rd_wr='0' and we='1'
                if we = '1' then
                    if rd_wr = '1' then
                        data_ram(idx) <= mem_in;
                    else
                        data_ram(idx) <= data_in;
                    end if;
                end if;

                -- Tag+valid update only when set_tag=1 (first refill byte)
                if set_tag = '1' then
                    tag_reg <= tag_in;
                    valid   <= '1';
                end if;

                -- Read path for CPU (registered)
                if rd_wr = '1' then
                    dout <= data_ram(idx);
                end if;
            end if;
        end if;
    end process;
end rtl;

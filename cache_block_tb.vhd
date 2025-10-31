library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_block_tb is
end cache_block_tb;

architecture sim of cache_block_tb is

    ----------------------------------------------------------------
    -- UUT component: must MATCH cache_block.vhd exactly
    ----------------------------------------------------------------
    component cache_block
        port (
            clk        : in  std_logic;
            reset      : in  std_logic;

            enable     : in  std_logic;

            data_in    : in  std_logic_vector(7 downto 0);
            data_out   : out std_logic_vector(7 downto 0);
            byte_sel   : in  std_logic_vector(1 downto 0);
            rd_wr      : in  std_logic;                     -- '1' = read
                                                             -- '0' = write from CPU

            mem_in     : in  std_logic_vector(7 downto 0);

            we         : in  std_logic;                     -- write enable to cache byte
            set_tag    : in  std_logic;                     -- load tag+valid
            tag_in     : in  std_logic_vector(1 downto 0);  -- tag from address

            valid_out  : out std_logic;
            tag_out    : out std_logic_vector(1 downto 0);
            hit_miss   : out std_logic                      -- '1' = hit
        );
    end component;

    ----------------------------------------------------------------
    -- Testbench signals
    ----------------------------------------------------------------
    signal clk        : std_logic := '0';
    signal reset      : std_logic := '0';
    signal enable     : std_logic := '0';

    signal data_in    : std_logic_vector(7 downto 0) := (others => '0');
    signal data_out   : std_logic_vector(7 downto 0);
    signal byte_sel   : std_logic_vector(1 downto 0) := "00";
    signal rd_wr      : std_logic := '0';  -- we'll drive this

    signal mem_in     : std_logic_vector(7 downto 0) := (others => '0');
    signal we         : std_logic := '0';

    signal tag_in     : std_logic_vector(1 downto 0) := (others => '0');
    signal set_tag    : std_logic := '0';
    signal tag_out    : std_logic_vector(1 downto 0);
    signal valid_out  : std_logic;

    signal hit_miss   : std_logic;

    ----------------------------------------------------------------
    -- helper to make hex constants nicer
    ----------------------------------------------------------------
    function U8(val : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(val, 8));
    end U8;

begin
    ----------------------------------------------------------------
    -- DUT instantiation
    ----------------------------------------------------------------
    dut: cache_block
        port map (
            clk        => clk,
            reset      => reset,
            enable     => enable,

            data_in    => data_in,
            data_out   => data_out,
            byte_sel   => byte_sel,
            rd_wr      => rd_wr,

            mem_in     => mem_in,

            we         => we,
            set_tag    => set_tag,
            tag_in     => tag_in,

            valid_out  => valid_out,
            tag_out    => tag_out,
            hit_miss   => hit_miss
        );

    ----------------------------------------------------------------
    -- Clock: 10 ns period
    ----------------------------------------------------------------
    clk <= not clk after 5 ns;

    ----------------------------------------------------------------
    -- Stimulus
    ----------------------------------------------------------------
    stim_proc : process
    begin
        ------------------------------------------------------------
        -- Apply reset
        ------------------------------------------------------------
        reset <= '1';
        wait until rising_edge(clk);
        reset <= '0';

        ------------------------------------------------------------
        -- Enable the block so internal enables can propagate
        ------------------------------------------------------------
        enable <= '1';

        ----------------------------------------------------------------
        -- Simulate a block fill from memory:
        -- We want:
        --   - cache byte[0] = 0x11
        --   - cache byte[1] = 0x22
        --   - cache byte[2] = 0x33
        --   - cache byte[3] = 0x44
        --
        -- In the structural design:
        --   rd_wr = '1'  -> choose mem_in as data source
        --   we   = '1'   -> allow write into selected byte
        --   byte_sel chooses which byte register gets written
        --   set_tag='1'  (at least for first fill) to latch tag and set valid
        ----------------------------------------------------------------

        rd_wr     <= '1';         -- "read/miss fill from memory" mode (select mem_in)
        set_tag   <= '1';         -- load tag + set valid on first write
        we        <= '1';         -- allow write
        tag_in    <= "10";        -- new tag for this block

        -- write byte 0
        mem_in    <= U8(16#11#);
        byte_sel  <= "00";
        wait until rising_edge(clk);

        -- after first word, we don't need to keep asserting set_tag,
        -- but leaving it '1' for this cycle won't break anything:
        set_tag   <= '0';

        -- write byte 1
        mem_in    <= U8(16#22#);
        byte_sel  <= "01";
        wait until rising_edge(clk);

        -- write byte 2
        mem_in    <= U8(16#33#);
        byte_sel  <= "10";
        wait until rising_edge(clk);

        -- write byte 3
        mem_in    <= U8(16#44#);
        byte_sel  <= "11";
        wait until rising_edge(clk);

        -- stop writing
        we      <= '0';
        rd_wr   <= '0';  -- back to "cpu write mode" selection if we ever write again

        ------------------------------------------------------------
        -- At this point:
        --   tag_out should be "10"
        --   valid_out should be '1'
        --   hit_miss should go high if we present tag_in="10"
        ------------------------------------------------------------

        -- present WRONG tag, expect miss
        tag_in   <= "01";
        wait for 10 ns;

        -- present CORRECT tag, expect hit
        tag_in   <= "10";
        wait for 10 ns;

        ------------------------------------------------------------
        -- Now test READ HIT back to CPU:
        -- We do:
        --   rd_wr = '1'  -> read path active
        --   byte_sel chooses which cached byte we want
        --   outreg_en = enable AND rd_wr, so output register loads
        ------------------------------------------------------------
        rd_wr    <= '1';
        byte_sel <= "10";   -- should read back 0x33
        wait until rising_edge(clk);

        ------------------------------------------------------------
        -- Now test CPU WRITE HIT:
        -- We do:
        --   rd_wr = '0'   -> choose data_in for write_data
        --   we   = '1'
        --   byte_sel selects which cached byte we overwrite
        ------------------------------------------------------------
        rd_wr    <= '0';             -- select CPU data_in instead of mem_in
        data_in  <= U8(16#A5#);      -- new byte to store
        byte_sel <= "01";            -- overwrite byte1
        we       <= '1';
        wait until rising_edge(clk);
        we       <= '0';

        ------------------------------------------------------------
        -- Re-read that same byte to confirm we overwrote it:
        ------------------------------------------------------------
        rd_wr    <= '1';             -- go back to read mode
        byte_sel <= "01";            -- read the updated byte
        wait until rising_edge(clk);

        -- give some time to look at waves
        wait for 50 ns;
        assert false report "Simulation finished." severity failure;
    end process;

end sim;

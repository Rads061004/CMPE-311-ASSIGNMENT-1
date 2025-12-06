library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_chip_extra is
end tb_chip_extra;

architecture sim of tb_chip_extra is

    ----------------------------------------------------------------------
    -- DUT PORT SIGNALS
    ----------------------------------------------------------------------
    signal cpu_add       : std_logic_vector(5 downto 0);
    signal cpu_data      : std_logic_vector(7 downto 0);
    signal cpu_rd_wrn    : std_logic;
    signal start         : std_logic;
    signal clk           : std_logic := '0';
    signal reset         : std_logic;

    signal mem_data      : std_logic_vector(7 downto 0);

    signal busy          : std_logic;
    signal mem_en        : std_logic;
    signal mem_add       : std_logic_vector(5 downto 0);

    ----------------------------------------------------------------------
    -- CPU to DUT bidirectional bus simulation
    ----------------------------------------------------------------------
    signal cpu_data_drv     : std_logic_vector(7 downto 0);
    signal cpu_data_oe_sim  : std_logic := '0';

begin

    ----------------------------------------------------------------------
    -- CLOCK: 20 ns period (50MHz)
    ----------------------------------------------------------------------
    clk <= not clk after 10 ns;

    ----------------------------------------------------------------------
    -- DUT INSTANTIATION (VHDL‑93 style)
    ----------------------------------------------------------------------
    uut: chip_extra
        port map(
            cpu_add    => cpu_add,
            cpu_data   => cpu_data,
            cpu_rd_wrn => cpu_rd_wrn,
            start      => start,
            clk        => clk,
            reset      => reset,
            mem_data   => mem_data,
            busy       => busy,
            mem_en     => mem_en,
            mem_add    => mem_add
        );

    ----------------------------------------------------------------------
    -- TRI-STATE BUS MODEL
    ----------------------------------------------------------------------
    cpu_data <= cpu_data_drv when cpu_data_oe_sim = '1' else (others => 'Z');

    ----------------------------------------------------------------------
    -- SIMPLE MEMORY MODEL
    ----------------------------------------------------------------------
    mem_data <= std_logic_vector(to_unsigned(to_integer(unsigned(mem_add)), 8));

    ----------------------------------------------------------------------
    -- TESTBENCH STIMULUS
    ----------------------------------------------------------------------
    stim: process
    begin

        ------------------------------------------------------------------
        -- INITIALIZE
        ------------------------------------------------------------------
        cpu_data_drv    <= (others => '0');
        cpu_data_oe_sim <= '0';
        cpu_rd_wrn      <= '1';
        cpu_add         <= (others => '0');
        start           <= '0';

        reset <= '1';
        wait for 50 ns;
        reset <= '0';
        wait for 50 ns;

        ------------------------------------------------------------------
        -- TEST 1: Read MISS to bank0 refill
        ------------------------------------------------------------------
        report "==============================================================";
        report "TEST 1: READ MISS triggers refill into bank0 (LRU=0)";
        report "==============================================================";

        cpu_add    <= "000100";  -- tag=00 index=01 offset=00
        cpu_rd_wrn <= '1';
        start      <= '1';
        wait for 20 ns;
        start <= '0';

        wait until busy = '0';
        wait for 20 ns;

        ------------------------------------------------------------------
        -- TEST 2: Repeat to HIT in bank0
        ------------------------------------------------------------------
        report "TEST 2: READ HIT in bank0";

        cpu_add    <= "000100";
        cpu_rd_wrn <= '1';
        start <= '1';
        wait for 20 ns;
        start <= '0';

        wait until busy = '0';
        wait for 20 ns;

        ------------------------------------------------------------------
        -- TEST 3: New tag to MISS to refill bank1
        ------------------------------------------------------------------
        report "==============================================================";
        report "TEST 3: New tag, MISS fills bank1 (LRU flips to 1)";
        report "==============================================================";

        cpu_add <= "010100";
        cpu_rd_wrn <= '1';
        start <= '1';
        wait for 20 ns;
        start <= '0';

        wait until busy='0';
        wait for 20 ns;

        ------------------------------------------------------------------
        -- TEST 4: Re-access both blocks to flip LRU
        ------------------------------------------------------------------
        report "TEST 4: LRU flip verification";

        cpu_add <= "000100";
        start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        cpu_add <= "010100";
        start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        ------------------------------------------------------------------
        -- TEST 5: WRITE HIT
        ------------------------------------------------------------------
        report "==============================================================";
        report "TEST 5: WRITE HIT to bank1 (should only update bank1)";
        report "==============================================================";

        cpu_data_drv    <= x"AA";
        cpu_data_oe_sim <= '1';
        cpu_rd_wrn      <= '0';
        cpu_add         <= "010100";

        start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        cpu_data_oe_sim <= '0';

        ------------------------------------------------------------------
        -- TEST 6: READ BACK THE WRITTEN VALUE
        ------------------------------------------------------------------
        report "TEST 6: Read back; expected returned value = AA";

        cpu_rd_wrn <= '1';
        cpu_add    <= "010100";

        start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        ------------------------------------------------------------------
        -- FINISH
        ------------------------------------------------------------------
        report "ALL TESTS COMPLETED";
        wait;
    end process;

end sim;

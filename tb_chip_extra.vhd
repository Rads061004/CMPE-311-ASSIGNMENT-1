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

    ----------------------------------------------------------------------
    -- DUT COMPONENT DECLARATION (required by Cadence)
    ----------------------------------------------------------------------
    component chip_extra
        port(
            cpu_add    : in  std_logic_vector(5 downto 0);
            cpu_data   : inout std_logic_vector(7 downto 0);
            cpu_rd_wrn : in  std_logic;
            start      : in  std_logic;
            clk        : in  std_logic;
            reset      : in  std_logic;
            mem_data   : in  std_logic_vector(7 downto 0);
            busy       : out std_logic;
            mem_en     : out std_logic;
            mem_add    : out std_logic_vector(5 downto 0)
        );
    end component;

begin   

    ----------------------------------------------------------------------
    -- CLOCK: 20 ns period (50MHz)
    ----------------------------------------------------------------------
    clk <= not clk after 10 ns;

    ----------------------------------------------------------------------
    -- DUT INSTANTIATION (with explicit component)
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
    cpu_data <= cpu_data_drv when cpu_data_oe_sim = '1'
                else (others => 'Z');

    ----------------------------------------------------------------------
    -- SIMPLE MEMORY MODEL:
    -- Returns byte equal to mem_add for every read
    ----------------------------------------------------------------------
    mem_data <= std_logic_vector(to_unsigned(
                    to_integer(unsigned(mem_add)), 8));

    ----------------------------------------------------------------------
    -- TEST SEQUENCE
    ----------------------------------------------------------------------
    stim: process
    begin
        ----------------------------------------------------------
        -- INITIALIZE
        ----------------------------------------------------------
        cpu_data_drv    <= (others => '0');
        cpu_data_oe_sim <= '0';
        cpu_rd_wrn      <= '1';
        cpu_add         <= (others => '0');
        start           <= '0';

        reset <= '1';
        wait for 50 ns;
        reset <= '0';
        wait for 50 ns;

        ----------------------------------------------------------
        -- TEST 1: READ MISS → refill → bank0
        ----------------------------------------------------------
        report "TEST 1: READ MISS refills bank0";

        cpu_add    <= "000100";  -- tag=00 index=01 offset=00
        cpu_rd_wrn <= '1';
        start <= '1'; wait for 20 ns; start <= '0';
        wait until busy = '0';

        wait for 30 ns;

        ----------------------------------------------------------
        -- TEST 2: READ HIT in bank0
        ----------------------------------------------------------
        report "TEST 2: HIT in bank0";

        start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        ----------------------------------------------------------
        -- TEST 3: NEW TAG → MISS → refill bank1
        ----------------------------------------------------------
        report "TEST 3: MISS refills bank1";

        cpu_add <= "010100";  -- different tag
        start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        ----------------------------------------------------------
        -- TEST 4: VERIFY LRU flip logic
        ----------------------------------------------------------
        report "TEST 4: Access bank0 then bank1 to flip LRU";

        cpu_add <= "000100"; start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        cpu_add <= "010100"; start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        ----------------------------------------------------------
        -- TEST 5: WRITE HIT → should update only used bank
        ----------------------------------------------------------
        report "TEST 5: WRITE HIT into bank1 (value AA)";

        cpu_data_drv    <= x"AA";
        cpu_data_oe_sim <= '1';
        cpu_rd_wrn      <= '0';      -- write
        cpu_add         <= "010100";

        start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        cpu_data_oe_sim <= '0';

        ----------------------------------------------------------
        -- TEST 6: READ BACK
        ----------------------------------------------------------
        report "TEST 6: Read back, should get 0xAA";

        cpu_rd_wrn <= '1';
        start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        report "CHECK SIM OUTPUT: Expected = AA";

        ----------------------------------------------------------
        -- FINISH
        ----------------------------------------------------------
        report "ALL TESTS FINISHED";
        wait;
    end process;

end sim;

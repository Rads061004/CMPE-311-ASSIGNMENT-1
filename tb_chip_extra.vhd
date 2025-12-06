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
    -- CPU BUS DRIVER (for writes)
    ----------------------------------------------------------------------
    signal cpu_data_drv     : std_logic_vector(7 downto 0) := (others => '0');
    signal cpu_data_drive   : std_logic := '0';

begin

    assert false report "TESTBENCH STARTED!" severity note;
    ----------------------------------------------------------------------
    -- CLOCK GENERATION
    ----------------------------------------------------------------------
    clk <= not clk after 10 ns;

    ----------------------------------------------------------------------
    -- BIDIRECTIONAL CPU BUS
    ----------------------------------------------------------------------
    cpu_data <= cpu_data_drv when cpu_data_drive = '1'
                else (others => 'Z');

    ----------------------------------------------------------------------
    -- SIMPLE MEMORY MODEL
    -- returns mem_data = mem_add (byte address)
    ----------------------------------------------------------------------
    mem_data <= std_logic_vector(to_unsigned(to_integer(unsigned(mem_add)), 8));

    ----------------------------------------------------------------------
    -- DUT INSTANTIATION (Cadence syntax)
    ----------------------------------------------------------------------
    uut: entity work.chip_extra
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
    -- MAIN TEST PROCESS
    ----------------------------------------------------------------------
    stimulus : process
    begin
        ----------------------------------------------------------
        -- INITIAL RESET
        ----------------------------------------------------------
        reset <= '1';
        cpu_rd_wrn <= '1';
        start <= '0';
        cpu_data_drive <= '0';
        wait for 40 ns;

        reset <= '0';
        wait for 40 ns;

        ----------------------------------------------------------
        -- TEST 1: READ MISS (fills bank0)
        ----------------------------------------------------------
        report "TEST 1: READ MISS (expect BANK0 refill)" severity note;

        cpu_add <= "000100";    -- tag=00 index=01 offset=00
        cpu_rd_wrn <= '1';      -- read
        start <= '1'; wait for 20 ns; start <= '0';

        wait until busy = '0';
        wait for 20 ns;

        ----------------------------------------------------------
        -- TEST 2: READ HIT
        ----------------------------------------------------------
        report "TEST 2: READ HIT in bank0" severity note;

        start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        ----------------------------------------------------------
        -- TEST 3: READ MISS (fills bank1)
        ----------------------------------------------------------
        report "TEST 3: NEW TAG causes MISS (bank1 refill)" severity note;

        cpu_add <= "010100";    -- different tag
        start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        ----------------------------------------------------------
        -- TEST 4: WRITE HIT to bank1
        ----------------------------------------------------------
        report "TEST 4: WRITE HIT to bank1 (write 0xAA)" severity note;

        cpu_rd_wrn <= '0';           -- write
        cpu_data_drv <= x"AA";       -- data
        cpu_data_drive <= '1';       -- drive bus

        start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        cpu_data_drive <= '0';       -- release bus

        ----------------------------------------------------------
        -- TEST 5: READ BACK THE WRITTEN VALUE
        ----------------------------------------------------------
        report "TEST 5: READ BACK written byte (expect 0xAA)" severity note;

        cpu_rd_wrn <= '1';   -- read
        start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        report "SIM: Check waveform: cpu_data should show 0xAA" severity note;

        ----------------------------------------------------------
        -- END
        ----------------------------------------------------------
        report "ALL TESTS COMPLETED" severity note;
        wait;
    end process;

end sim;

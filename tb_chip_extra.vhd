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

    -- Clock period constant
    constant CLK_PERIOD : time := 20 ns;

begin

    ----------------------------------------------------------------------
    -- CLOCK GENERATION
    ----------------------------------------------------------------------
    clk_proc: process
    begin
        clk <= '0';
        wait for CLK_PERIOD/2;
        clk <= '1';
        wait for CLK_PERIOD/2;
    end process;

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
    -- DUT INSTANTIATION
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
        report "TESTBENCH STARTED!" severity note;
        
        -- Initialize signals
        cpu_add <= (others => '0');
        cpu_rd_wrn <= '1';
        start <= '0';
        cpu_data_drive <= '0';
        cpu_data_drv <= (others => '0');
        reset <= '1';
        
        -- Hold reset for a few clocks
        wait for CLK_PERIOD * 3;
        wait until rising_edge(clk);
        reset <= '0';
        wait for CLK_PERIOD * 2;

        ----------------------------------------------------------
        -- TEST 1: READ MISS (fills bank0)
        ----------------------------------------------------------
        report "TEST 1: READ MISS (expect BANK0 refill)" severity note;
        
        wait until rising_edge(clk);
        cpu_add <= "000100";    -- tag=00 index=01 offset=00
        cpu_rd_wrn <= '1';      -- read
        start <= '1';
        
        wait until rising_edge(clk);
        start <= '0';

        wait until busy = '0';
        wait for CLK_PERIOD * 2;

        ----------------------------------------------------------
        -- TEST 2: READ HIT
        ----------------------------------------------------------
        report "TEST 2: READ HIT in bank0" severity note;
        
        wait until rising_edge(clk);
        start <= '1';
        
        wait until rising_edge(clk);
        start <= '0';

        wait until busy='0';
        wait for CLK_PERIOD * 2;

        ----------------------------------------------------------
        -- TEST 3: READ MISS (fills bank1)
        ----------------------------------------------------------
        report "TEST 3: NEW TAG causes MISS (bank1 refill)" severity note;
        
        wait until rising_edge(clk);
        cpu_add <= "010100";    -- different tag
        start <= '1';
        
        wait until rising_edge(clk);
        start <= '0';

        wait until busy='0';
        wait for CLK_PERIOD * 2;

        ----------------------------------------------------------
        -- TEST 4: WRITE HIT to bank1
        ----------------------------------------------------------
        report "TEST 4: WRITE HIT to bank1 (write 0xAA)" severity note;
        
        wait until rising_edge(clk);
        cpu_rd_wrn <= '0';           -- write
        cpu_data_drv <= x"AA";       -- data
        cpu_data_drive <= '1';       -- drive bus
        start <= '1';
        
        wait until rising_edge(clk);
        start <= '0';

        wait until busy='0';
        wait for CLK_PERIOD;
        
        cpu_data_drive <= '0';       -- release bus
        wait for CLK_PERIOD;

        ----------------------------------------------------------
        -- TEST 5: READ BACK THE WRITTEN VALUE
        ----------------------------------------------------------
        report "TEST 5: READ BACK written byte (expect 0xAA)" severity note;
        
        wait until rising_edge(clk);
        cpu_rd_wrn <= '1';   -- read
        start <= '1';
        
        wait until rising_edge(clk);
        start <= '0';

        wait until busy='0';
        wait for CLK_PERIOD * 2;

        report "SIM: Check waveform: cpu_data should show 0xAA" severity note;

        ----------------------------------------------------------
        -- END
        ----------------------------------------------------------
        report "ALL TESTS COMPLETED" severity note;
        wait;
    end process;

end sim;

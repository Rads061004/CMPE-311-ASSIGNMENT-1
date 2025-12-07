library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_chip_extra is
end tb_chip_extra;

architecture sim of tb_chip_extra is

    -- DUT PORT SIGNALS
    signal cpu_add       : std_logic_vector(5 downto 0) := (others => '0');
    signal cpu_data      : std_logic_vector(7 downto 0);
    signal cpu_rd_wrn    : std_logic := '1';
    signal start         : std_logic := '0';
    signal clk           : std_logic := '0';
    signal reset         : std_logic := '1';

    signal mem_data      : std_logic_vector(7 downto 0);
    signal busy          : std_logic;
    signal mem_en        : std_logic;
    signal mem_add       : std_logic_vector(5 downto 0);

    -- CPU BUS DRIVER (for writes)
    signal cpu_data_drv     : std_logic_vector(7 downto 0) := (others => '0');
    signal cpu_data_drive   : std_logic := '0';

    constant CLK_PERIOD : time := 20 ns;
    
    -- Simulation control
    signal sim_done : boolean := false;

begin

    -- CLOCK GENERATION - runs continuously
    clk <= not clk after CLK_PERIOD/2 when not sim_done else '0';

    -- BIDIRECTIONAL CPU BUS
    cpu_data <= cpu_data_drv when cpu_data_drive = '1' else (others => 'Z');

    -- SIMPLE MEMORY MODEL
    mem_data <= std_logic_vector(to_unsigned(to_integer(unsigned(mem_add)), 8));

    -- DUT INSTANTIATION
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

    -- MAIN TEST PROCESS
    stimulus : process
    begin
        report "=== TESTBENCH STARTED ===" severity note;
        
        -- Wait a bit for clock to start
        wait for 1 ns;
        
        report "Releasing reset..." severity note;
        wait for 100 ns;
        reset <= '0';
        wait for 100 ns;
        
        report "TEST 1: Asserting START signal" severity note;
        cpu_add <= "000100";
        cpu_rd_wrn <= '1';
        
        wait for 20 ns;
        start <= '1';
        report "START = 1" severity note;
        
        wait for 40 ns;
        start <= '0';
        report "START = 0" severity note;
        
        wait for 500 ns;
        
        report "TEST 2: Read same address (should HIT in bank0)" severity note;
        wait for 20 ns;
        start <= '1';
        wait for 40 ns;
        start <= '0';
        wait until busy = '0';
        wait for 100 ns;
        
        report "TEST 3: Read different tag, same index (fills bank1)" severity note;
        cpu_add <= "010100";  -- tag=01, index=01, offset=00
        wait for 20 ns;
        start <= '1';
        wait for 40 ns;
        start <= '0';
        wait until busy = '0';
        wait for 100 ns;
        
        report "TEST 4: Read original tag again (should HIT in bank0)" severity note;
        cpu_add <= "000100";  -- back to tag=00
        wait for 20 ns;
        start <= '1';
        wait for 40 ns;
        start <= '0';
        wait until busy = '0';
        wait for 100 ns;
        
        report "TEST 5: Write to bank1 location" severity note;
        cpu_add <= "010100";  -- tag=01
        cpu_rd_wrn <= '0';    -- write
        cpu_data_drv <= x"AA";
        cpu_data_drive <= '1';
        wait for 20 ns;
        start <= '1';
        wait for 40 ns;
        start <= '0';
        wait until busy = '0';
        cpu_data_drive <= '0';
        wait for 100 ns;
        
        report "TEST 6: Read back written value (should be 0xAA)" severity note;
        cpu_rd_wrn <= '1';    -- read
        wait for 20 ns;
        start <= '1';
        wait for 40 ns;
        start <= '0';
        wait until busy = '0';
        wait for 100 ns;
        
        report "TEST 7: Third tag to same index (evicts LRU)" severity note;
        cpu_add <= "100100";  -- tag=10, same index=01
        wait for 20 ns;
        start <= '1';
        wait for 40 ns;
        start <= '0';
        wait until busy = '0';
        wait for 100 ns;
        
        report "=== ALL TESTS COMPLETED ===" severity note;
        sim_done <= true;
        wait;
    end process;

end sim;

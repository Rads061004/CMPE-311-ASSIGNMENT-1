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
    
    -- Test markers for waveform
    signal test_num : integer := 0;

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
        variable timeout_count : integer;
    begin
        test_num <= 0;
        report "=== TESTBENCH STARTED ===" severity note;
        
        -- Wait a bit for clock to start
        wait for 1 ns;
        
        report "Releasing reset..." severity note;
        wait for 50 ns;
        reset <= '0';
        wait for 50 ns;
        
        -----------------------------------------------------------
        -- TEST 1: First Read Miss (fills bank 0)
        -----------------------------------------------------------
        test_num <= 1;
        report "TEST 1: First read MISS - fills bank0" severity note;
        cpu_add <= "000100";  -- tag=00, index=01, offset=00
        cpu_rd_wrn <= '1';    -- read
        
        wait for 20 ns;
        start <= '1';
        wait for 40 ns;
        start <= '0';
        
        -- Wait with timeout
        timeout_count := 0;
        while busy = '1' and timeout_count < 200 loop
            wait for CLK_PERIOD;
            timeout_count := timeout_count + 1;
        end loop;
        
        if timeout_count >= 200 then
            report "TEST 1 TIMEOUT!" severity error;
        else
            report "TEST 1 COMPLETE after " & integer'image(timeout_count) & " clocks" severity note;
        end if;
        wait for 100 ns;
        
        -----------------------------------------------------------
        -- TEST 2: Read Same Address (should HIT in bank0)
        -----------------------------------------------------------
        test_num <= 2;
        report "TEST 2: Read same address - should HIT in bank0" severity note;
        
        wait for 20 ns;
        start <= '1';
        wait for 40 ns;
        start <= '0';
        
        timeout_count := 0;
        while busy = '1' and timeout_count < 200 loop
            wait for CLK_PERIOD;
            timeout_count := timeout_count + 1;
        end loop;
        
        if timeout_count >= 200 then
            report "TEST 2 TIMEOUT!" severity error;
        else
            report "TEST 2 COMPLETE after " & integer'image(timeout_count) & " clocks" severity note;
        end if;
        wait for 100 ns;
            
        -----------------------------------------------------------
        -- TEST 3: Read Different Tag, Same Index (fills bank1)
        -----------------------------------------------------------
        test_num <= 3;
        report "TEST 3: Different tag, same index - fills bank1" severity note;
        cpu_add <= "010100";  -- tag=01, index=01, offset=00
        
        wait for 20 ns;
        start <= '1';
        wait for 40 ns;
        start <= '0';
        
        timeout_count := 0;
        while busy = '1' and timeout_count < 200 loop
            wait for CLK_PERIOD;
            timeout_count := timeout_count + 1;
        end loop;
        
        if timeout_count >= 200 then
            report "TEST 3 TIMEOUT!" severity error;
        else
            report "TEST 3 COMPLETE after " & integer'image(timeout_count) & " clocks" severity note;
        end if;
        wait for 100 ns;
        
        -----------------------------------------------------------
        -- TEST 4: Read Original Tag Again (should HIT in bank0)
        -----------------------------------------------------------
        test_num <= 4;
        report "TEST 4: Back to original tag - should HIT in bank0" severity note;
        cpu_add <= "000100";  -- back to tag=00
        
        wait for 20 ns;
        start <= '1';
        wait for 40 ns;
        start <= '0';
        
        timeout_count := 0;
        while busy = '1' and timeout_count < 200 loop
            wait for CLK_PERIOD;
            timeout_count := timeout_count + 1;
        end loop;
        
        if timeout_count >= 200 then
            report "TEST 4 TIMEOUT!" severity error;
        else
            report "TEST 4 COMPLETE after " & integer'image(timeout_count) & " clocks" severity note;
        end if;
        wait for 100 ns;
        
        -----------------------------------------------------------
        -- TEST 5: Write to Bank1 Location
        -----------------------------------------------------------
        test_num <= 5;
        report "TEST 5: Write 0xAA to bank1 location" severity note;
        cpu_add <= "010100";  -- tag=01, index=01
        cpu_rd_wrn <= '0';    -- write
        cpu_data_drv <= x"AA";
        cpu_data_drive <= '1';
        
        wait for 20 ns;
        report "TEST 5: Asserting start..." severity note;
        start <= '1';
        wait for 40 ns;
        start <= '0';
        report "TEST 5: Start deasserted, waiting for busy to go low..." severity note;
        
        -- Wait with timeout and reporting
        timeout_count := 0;
        while busy = '1' and timeout_count < 50 loop
            wait for CLK_PERIOD;
            timeout_count := timeout_count + 1;
            if timeout_count mod 10 = 0 then
                report "TEST 5: Still waiting... busy still high after " & 
                       integer'image(timeout_count) & " clocks" severity note;
            end if;
        end loop;
        
        if timeout_count >= 50 then
            report "TEST 5 TIMEOUT! busy stuck high" severity error;
            report "This indicates FSM is not completing write hit cycle" severity error;
            sim_done <= true;
            wait;
        else
            report "TEST 5 COMPLETE after " & integer'image(timeout_count) & " clocks" severity note;
        end if;
        
        cpu_data_drive <= '0';
        wait for 100 ns;
        
        -----------------------------------------------------------
        -- TEST 6: Read Back Written Value
        -----------------------------------------------------------
        test_num <= 6;
        report "TEST 6: Read back - should return 0xAA" severity note;
        cpu_rd_wrn <= '1';    -- read
        
        wait for 20 ns;
        start <= '1';
        wait for 40 ns;
        start <= '0';
        
        timeout_count := 0;
        while busy = '1' and timeout_count < 200 loop
            wait for CLK_PERIOD;
            timeout_count := timeout_count + 1;
        end loop;
        
        if timeout_count >= 200 then
            report "TEST 6 TIMEOUT!" severity error;
        else
            report "TEST 6 COMPLETE - check cpu_data for 0xAA" severity note;
        end if;
        wait for 100 ns;
        
        -----------------------------------------------------------
        -- TEST 7: Third Tag to Same Index (should evict LRU)
        -----------------------------------------------------------
        test_num <= 7;
        report "TEST 7: Third tag, same index - evicts LRU bank" severity note;
        cpu_add <= "100100";  -- tag=10, index=01, offset=00
        
        wait for 20 ns;
        start <= '1';
        wait for 40 ns;
        start <= '0';
        
        timeout_count := 0;
        while busy = '1' and timeout_count < 200 loop
            wait for CLK_PERIOD;
            timeout_count := timeout_count + 1;
        end loop;
        
        if timeout_count >= 200 then
            report "TEST 7 TIMEOUT!" severity error;
        else
            report "TEST 7 COMPLETE after " & integer'image(timeout_count) & " clocks" severity note;
        end if;
        wait for 100 ns;
        
        test_num <= 99;
        report "=== ALL TESTS COMPLETED ===" severity note;
        wait for 200 ns;
        sim_done <= true;
        wait;
    end process;

end sim;

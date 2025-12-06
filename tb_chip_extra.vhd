library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_chip_extra is
end tb_chip_extra;

architecture sim of tb_chip_extra is

    -- DUT ports
    signal cpu_add    : std_logic_vector(5 downto 0);
    signal cpu_data   : std_logic_vector(7 downto 0);
    signal cpu_rd_wrn : std_logic;
    signal start      : std_logic;
    signal clk        : std_logic := '0';
    signal reset      : std_logic;

    signal mem_data   : std_logic_vector(7 downto 0);

    signal busy       : std_logic;
    signal mem_en     : std_logic;
    signal mem_add    : std_logic_vector(5 downto 0);

    -- Internal tristate buffer simulation
    signal cpu_data_drv : std_logic_vector(7 downto 0);
    signal cpu_data_oe_sim : std_logic := '0';

begin

    ----------------------------------------------------------------------
    --  Clock process
    ----------------------------------------------------------------------
    clk <= not clk after 10 ns;

    ----------------------------------------------------------------------
    --  DUT instantiation
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
    -- CPU ↔ DUT Bus Handling
    -- Simulates bidirectional bus
    ----------------------------------------------------------------------
    cpu_data <= cpu_data_drv when cpu_data_oe_sim = '1' else (others => 'Z');

    ----------------------------------------------------------------------
    -- Memory model (simple ROM based on mem_add)
    -- Each line returns a 4-byte block:
    --   address X returns bytes: X, X+1, X+2, X+3
    ----------------------------------------------------------------------
    mem_data <= std_logic_vector(to_unsigned(to_integer(unsigned(mem_add)) + 
                                             to_integer(unsigned(cpu_add(1 downto 0))), 8));

    ----------------------------------------------------------------------
    -- TESTBENCH STIMULUS
    ----------------------------------------------------------------------
    stim: process
    begin
        ------------------------------------------------------------------
        -- INITIALIZE
        ------------------------------------------------------------------
        cpu_data_drv <= (others => '0');
        cpu_data_oe_sim <= '0';
        cpu_rd_wrn <= '1';
        cpu_add <= (others => '0');
        start <= '0';

        reset <= '1';
        wait for 50 ns;
        reset <= '0';
        wait for 50 ns;

        ------------------------------------------------------------------
        -- TEST 1: Read MISS → triggers refill into LRU bank (bank0 initially)
        ------------------------------------------------------------------
        report "------------------------------------------------------------------";
        report "TEST 1: READ MISS triggers refill into bank0 (LRU=0)";
        report "------------------------------------------------------------------";

        cpu_add <= "000100";  -- tag=00 index=01 offset=00
        cpu_rd_wrn <= '1';    -- read
        start <= '1';
        wait for 20 ns;
        start <= '0';

        wait until busy = '0';
        wait for 20 ns;

        ------------------------------------------------------------------
        -- TEST 2: Repeat same read → should HIT in bank0
        ------------------------------------------------------------------
        report "TEST 2: READ HIT in bank0";
        cpu_add <= "000100";   
        cpu_rd_wrn <= '1';
        start <= '1';
        wait for 20 ns;
        start <= '0';
        wait until busy = '0';
        wait for 20 ns;

        ------------------------------------------------------------------
        -- TEST 3: Access a different tag → MISS → go to bank1 (LRU flips)
        ------------------------------------------------------------------
        report "------------------------------------------------------------------";
        report "TEST 3: READ MISS fills bank1 (LRU=1)";
        report "------------------------------------------------------------------";

        cpu_add <= "010100";  -- tag=01 index=01 offset=00
        cpu_rd_wrn <= '1';
        start <= '1';
        wait for 20 ns;
        start <= '0';

        wait until busy = '0';
        wait for 20 ns;

        ------------------------------------------------------------------
        -- TEST 4: Read both again → verify LRU flip behavior
        ------------------------------------------------------------------
        report "TEST 4: Verify LRU: next miss should evict the least recently used bank";

        -- Access old block (bank0)
        cpu_add <= "000100";
        start <= '1';
        wait for 20 ns; start <= '0';
        wait until busy='0';

        -- Access block in bank1
        cpu_add <= "010100";
        start <= '1';
        wait for 20 ns; start <= '0';
        wait until busy='0';

        ------------------------------------------------------------------
        -- TEST 5: WRITE HIT test (must update only the used bank)
        ------------------------------------------------------------------
        report "------------------------------------------------------------------";
        report "TEST 5: WRITE HIT updates only selected bank";
        report "------------------------------------------------------------------";

        cpu_data_drv <= x"AA";  -- write AA
        cpu_data_oe_sim <= '1'; -- drive CPU→cache
        cpu_rd_wrn <= '0';      -- write
        cpu_add <= "010100";    -- tag 01 index 01 offset 00
        start <= '1';
        wait for 20 ns; start <= '0';

        wait until busy='0';
        cpu_data_oe_sim <= '0'; -- release bus

        ------------------------------------------------------------------
        -- TEST 6: Confirm write took effect (read back)
        ------------------------------------------------------------------
        report "TEST 6: Confirm write returned from correct bank";

        cpu_rd_wrn <= '1';
        cpu_add <= "010100";
        start <= '1'; wait for 20 ns; start <= '0';
        wait until busy='0';

        report "IF working: returned value should be AA";

        ------------------------------------------------------------------
        -- FINISH SIMULATION
        ------------------------------------------------------------------
        report "ALL TESTS COMPLETED";
        wait;
    end process;

end sim;

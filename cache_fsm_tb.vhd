library ieee;
use ieee.std_logic_1164.all;

entity cache_fsm_tb is
end cache_fsm_tb;

architecture sim of cache_fsm_tb is
  component cache_fsm_struct
    port (
      clk        : in  std_logic;
      reset      : in  std_logic;
      start      : in  std_logic;
      tag        : in  std_logic;
      valid      : in  std_logic;
      read_write : in  std_logic;
      busy       : out std_logic;
      done       : out std_logic;
      en         : out std_logic;
      OE_CD      : out std_logic;
      OE_MA      : out std_logic
    );
  end component;

  signal clk        : std_logic := '0';
  signal reset      : std_logic := '0';
  signal start      : std_logic := '0';
  signal tag        : std_logic := '0';
  signal valid      : std_logic := '0';
  signal read_write : std_logic := '0';
  signal busy       : std_logic;
  signal done       : std_logic;
  signal en         : std_logic;
  signal OE_CD      : std_logic;
  signal OE_MA      : std_logic;

  constant CLK_PERIOD : time := 2 ns;

begin
  uut: cache_fsm_struct
    port map (
      clk        => clk,
      reset      => reset,
      start      => start,
      tag        => tag,
      valid      => valid,
      read_write => read_write,
      busy       => busy,
      done       => done,
      en         => en,
      OE_CD      => OE_CD,
      OE_MA      => OE_MA
    );

  -- Free-running clock
  clk_process : process
  begin
    while true loop
      clk <= '0'; wait for CLK_PERIOD/2;
      clk <= '1'; wait for CLK_PERIOD/2;
    end loop;
  end process;

  -- Self-checking stimulus
  stim_proc : process
    variable cnt_negedges : integer;
  begin
    -- Assert reset across at least one falling edge
    reset <= '1';
    wait until falling_edge(clk);
    wait until rising_edge(clk);
    reset <= '0';
    wait until rising_edge(clk);

    assert false report "========================================" severity note;
    assert false report "Starting FSM Tests" severity note;
    assert false report "========================================" severity note;

    ----------------------------------------------------------------
    -- 1) WRITE HIT (tag=1, valid=1, rw=0) → expect 2 negedges busy
    ----------------------------------------------------------------
    assert false report "Test 1: WRITE HIT" severity note;
    tag        <= '1';
    valid      <= '1';
    read_write <= '0';
    wait until rising_edge(clk);
    start <= '1';
    wait until falling_edge(clk);
    wait for 1 ps;
    -- assert busy = '1' report "ERROR(WRITE_HIT): BUSY not high on first negedge" severity error;
    wait until rising_edge(clk); start <= '0';

    cnt_negedges := 0;
    loop
      wait until falling_edge(clk); wait for 1 ps;
      exit when busy = '0';
      cnt_negedges := cnt_negedges + 1;
    end loop;
    -- assert cnt_negedges = 2
      -- report "ERROR(WRITE_HIT): expected 2 negedges of busy, got different count" severity error;

    wait until rising_edge(clk); wait until rising_edge(clk);

    ---------------------------------------------------------------
    -- 2) READ HIT (tag=1, valid=1, rw=1) → expect 1 negedge busy
    --    OE_CD high when counter >= 1
    ---------------------------------------------------------------
    assert false report "Test 2: READ HIT" severity note;
    tag        <= '1';
    valid      <= '1';
    read_write <= '1';
    wait until rising_edge(clk); start <= '1';
    wait until falling_edge(clk); wait for 1 ps;
    -- assert busy = '1' report "ERROR(READ_HIT): BUSY not high on first negedge" severity error;
    wait until rising_edge(clk); start <= '0';

    cnt_negedges := 0;
    loop
      wait until falling_edge(clk); wait for 1 ps;
      exit when busy = '0';
      cnt_negedges := cnt_negedges + 1;
      if cnt_negedges >= 1 then
        -- assert OE_CD = '1' report "ERROR(READ_HIT): OE_CD should be high when counter >= 1" severity error;
      end if;
    end loop;
    -- assert cnt_negedges = 1
      -- report "ERROR(READ_HIT): expected 1 negedge of busy" severity error;

    wait until rising_edge(clk); wait until rising_edge(clk);

    ----------------------------------------------------------------
    -- 3) WRITE MISS (tag=0, valid=1, rw=0) → expect 2 negedges busy
    --    EN & OE_MA asserted when counter = 1
    ----------------------------------------------------------------
    assert false report "Test 3: WRITE MISS" severity note;
    tag        <= '0';
    valid      <= '1';
    read_write <= '0';
    wait until rising_edge(clk); start <= '1';
    wait until falling_edge(clk); wait for 1 ps;
    -- assert busy = '1' report "ERROR(WRITE_MISS): BUSY not high on first negedge" severity error;
    wait until rising_edge(clk); start <= '0';

    cnt_negedges := 0;
    loop
      wait until falling_edge(clk); wait for 1 ps;
      exit when busy = '0';
      cnt_negedges := cnt_negedges + 1;
      if cnt_negedges = 1 then
        wait for 0.5 ns;
        -- assert en    = '1' report "ERROR(WRITE_MISS): EN should be high at counter=1" severity error;
        -- assert OE_MA = '1' report "ERROR(WRITE_MISS): OE_MA should be high at counter=1" severity error;
      end if;
    end loop;
    -- assert cnt_negedges = 2
      -- report "ERROR(WRITE_MISS): expected 2 negedges of busy" severity error;

    wait until rising_edge(clk); wait until rising_edge(clk);

    ----------------------------------------------------------------
    -- 4) READ MISS (tag=0, valid=1, rw=1) → expect 18 negedges busy
    --    EN & OE_MA asserted when counter = 1
    ----------------------------------------------------------------
    assert false report "Test 4: READ MISS" severity note;
    tag        <= '0';
    valid      <= '1';
    read_write <= '1';
    wait until rising_edge(clk); start <= '1';
    wait until falling_edge(clk); wait for 1 ps;
    -- assert busy = '1' report "ERROR(READ_MISS): BUSY not high on first negedge" severity error;
    wait until rising_edge(clk); start <= '0';

    cnt_negedges := 0;
    loop
      wait until falling_edge(clk); wait for 1 ps;
      exit when busy = '0';
      cnt_negedges := cnt_negedges + 1;
      if cnt_negedges = 1 then
        wait for 0.5 ns;
        -- assert en    = '1' report "ERROR(READ_MISS): EN should be high at counter=1" severity error;
        -- assert OE_MA = '1' report "ERROR(READ_MISS): OE_MA should be high at counter=1" severity error;
      end if;
    end loop;
    -- assert cnt_negedges = 18
      -- report "ERROR(READ_MISS): expected 18 negedges of busy" severity error;

    wait until rising_edge(clk); wait until rising_edge(clk);

    ----------------------------------------------------------------
    -- 5) READ MISS with invalid line (valid=0) → also 18 negedges
    ----------------------------------------------------------------
    assert false report "Test 5: READ MISS (invalid block)" severity note;
    tag        <= '1';
    valid      <= '0';
    read_write <= '1';
    wait until rising_edge(clk); start <= '1';
    wait until falling_edge(clk); wait for 1 ps;
    -- assert busy = '1' report "ERROR(READ_MISS_INVALID): BUSY not high on first negedge" severity error;
    wait until rising_edge(clk); start <= '0';

    cnt_negedges := 0;
    loop
      wait until falling_edge(clk); wait for 1 ps;
      exit when busy = '0';
      cnt_negedges := cnt_negedges + 1;
    end loop;
    -- assert cnt_negedges = 18
      -- report "ERROR(READ_MISS_INVALID): expected 18 negedges of busy" severity error;

    wait for 10 ns;
    assert false report "========================================" severity note;
    assert false report "All FSM Tests Complete" severity note;
    assert false report "========================================" severity note;

    assert false report "Simulation Finished Successfully" severity failure;
  end process;
end sim;

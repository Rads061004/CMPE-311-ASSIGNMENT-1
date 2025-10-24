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
      done       : out std_logic
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
      done       => done
    );

  clk_process : process
  begin
    clk <= '0'; wait for 1 ns;
    clk <= '1'; wait for 1 ns;
  end process;

  stim_proc : process
    variable cnt_negedges : integer;
  begin
    wait until rising_edge(clk);
    reset <= '1';
    wait until rising_edge(clk);
    reset <= '0';

    tag        <= '1';
    valid      <= '1';
    read_write <= '0';         
    wait until rising_edge(clk);
    start <= '1';

    wait until falling_edge(clk); wait for 1 ps;  
    assert busy = '1'
      report "ERROR(WRITE_HIT): BUSY not high on first negedge" severity error;

    wait until rising_edge(clk);
    start <= '0';

    cnt_negedges := 0;
    loop
      wait until falling_edge(clk); wait for 1 ps;
      exit when busy = '0';
      cnt_negedges := cnt_negedges + 1;
    end loop;

    wait until rising_edge(clk);

    tag        <= '1';
    valid      <= '1';
    read_write <= '1';          -- read
    wait until rising_edge(clk);
    start <= '1';

    wait until falling_edge(clk); wait for 1 ps;

    wait until rising_edge(clk);
    start <= '0';

    cnt_negedges := 0;
    loop
      wait until falling_edge(clk); wait for 1 ps;
      exit when busy = '0';
      cnt_negedges := cnt_negedges + 1;
    end loop;

    wait until rising_edge(clk);

    tag        <= '0'; valid <= '1'; read_write <= '0';
    wait until rising_edge(clk);
    start <= '1';

    wait until falling_edge(clk); wait for 1 ps;

    wait until rising_edge(clk);
    start <= '0';

    cnt_negedges := 0;
    loop
      wait until falling_edge(clk); wait for 1 ps;
      exit when busy = '0';
      cnt_negedges := cnt_negedges + 1;
    end loop;

    wait until rising_edge(clk);

    tag        <= '0'; valid <= '1'; read_write <= '1';
    wait until rising_edge(clk);
    start <= '1';

    wait until falling_edge(clk); wait for 1 ps;

    wait until rising_edge(clk);
    start <= '0';

    cnt_negedges := 0;
    loop
      wait until falling_edge(clk); wait for 1 ps;
      exit when busy = '0';
      cnt_negedges := cnt_negedges + 1;
    end loop;

    wait for 10 ns;
    assert false report "Simulation Finished" severity failure;
  end process;
end sim;

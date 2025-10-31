library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_fsm_tb is
end cache_fsm_tb;

architecture sim of cache_fsm_tb is

  component cache_fsm_struct
    port (
      clk            : in  std_logic;
      reset          : in  std_logic;
      start          : in  std_logic;
      tag            : in  std_logic;
      valid          : in  std_logic;
      read_write     : in  std_logic;
      busy           : out std_logic;
      done           : out std_logic;
      en             : out std_logic;
      OE_CD          : out std_logic;
      OE_MA          : out std_logic;
      state_dbg      : out std_logic_vector(2 downto 0);
      next_state_dbg : out std_logic_vector(2 downto 0);
      counter_dbg    : out std_logic_vector(4 downto 0)
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
  signal state_dbg_sig      : std_logic_vector(2 downto 0);
  signal next_state_dbg_sig : std_logic_vector(2 downto 0);
  signal counter_dbg_sig    : std_logic_vector(4 downto 0);

  constant CLK_PERIOD : time := 2 ns;

begin

  uut: cache_fsm_struct
    port map (
      clk            => clk,
      reset          => reset,
      start          => start,
      tag            => tag,
      valid          => valid,
      read_write     => read_write,
      busy           => busy,
      done           => done,
      en             => en,
      OE_CD          => OE_CD,
      OE_MA          => OE_MA,
      state_dbg      => state_dbg_sig,
      next_state_dbg => next_state_dbg_sig,
      counter_dbg    => counter_dbg_sig
    );

  clk_process : process
  begin
    while true loop
      clk <= '0'; wait for CLK_PERIOD/2;
      clk <= '1'; wait for CLK_PERIOD/2;
    end loop;
  end process;

  stim_proc : process
    variable cnt_negedges : integer;
  begin
    wait until rising_edge(clk);
    reset <= '1';
    wait until rising_edge(clk);
    reset <= '0';

    ----------------------------------------------------------------
    -- 1) WRITE HIT
    ----------------------------------------------------------------
    report "=== Starting WRITE HIT Test ===" severity note;
    tag        <= '1';
    valid      <= '1';
    read_write <= '0';
    wait until rising_edge(clk);
    start <= '1';

    wait until falling_edge(clk); 
    wait for 1 ps;

    wait until rising_edge(clk);
    start <= '0';

    cnt_negedges := 0;
    loop
      wait until falling_edge(clk); 
      wait for 1 ps;
      if busy = '1' then
        cnt_negedges := cnt_negedges + 1;
        report "WRITE_HIT: busy edge #" & integer'image(cnt_negedges) & 
               ", state=" & integer'image(to_integer(unsigned(state_dbg_sig))) &
               ", next=" & integer'image(to_integer(unsigned(next_state_dbg_sig))) &
               ", counter=" & integer'image(to_integer(unsigned(counter_dbg_sig)))
               severity note;
      end if;
      exit when busy = '0';
    end loop;
    report "WRITE_HIT: Total = " & integer'image(cnt_negedges) & " (expected 2)" severity note;

    wait until rising_edge(clk);

    ----------------------------------------------------------------
    -- 2) READ HIT
    ----------------------------------------------------------------
    report "=== Starting READ HIT Test ===" severity note;
    tag        <= '1';
    valid      <= '1';
    read_write <= '1';
    wait until rising_edge(clk);
    start <= '1';

    wait until falling_edge(clk); 
    wait for 1 ps;

    wait until rising_edge(clk);
    start <= '0';

    cnt_negedges := 0;
    loop
      wait until falling_edge(clk); 
      wait for 1 ps;
      if busy = '1' then
        cnt_negedges := cnt_negedges + 1;
        report "READ_HIT: busy edge #" & integer'image(cnt_negedges) & 
               ", state=" & integer'image(to_integer(unsigned(state_dbg_sig))) &
               ", next=" & integer'image(to_integer(unsigned(next_state_dbg_sig))) &
               ", counter=" & integer'image(to_integer(unsigned(counter_dbg_sig)))
               severity note;
      end if;
      exit when busy = '0';
    end loop;
    report "READ_HIT: Total = " & integer'image(cnt_negedges) & " (expected 1)" severity note;

    wait until rising_edge(clk);

    ----------------------------------------------------------------
    -- 3) WRITE MISS
    ----------------------------------------------------------------
    report "=== Starting WRITE MISS Test ===" severity note;
    tag        <= '0';
    valid      <= '1';
    read_write <= '0';
    wait until rising_edge(clk);
    start <= '1';

    wait until falling_edge(clk); 
    wait for 1 ps;

    wait until rising_edge(clk);
    start <= '0';

    cnt_negedges := 0;
    loop
      wait until falling_edge(clk); 
      wait for 1 ps;
      if busy = '1' then
        cnt_negedges := cnt_negedges + 1;
        report "WRITE_MISS: busy edge #" & integer'image(cnt_negedges) & 
               ", state=" & integer'image(to_integer(unsigned(state_dbg_sig))) &
               ", next=" & integer'image(to_integer(unsigned(next_state_dbg_sig))) &
               ", counter=" & integer'image(to_integer(unsigned(counter_dbg_sig)))
               severity note;
      end if;
      exit when busy = '0';
    end loop;
    report "WRITE_MISS: Total = " & integer'image(cnt_negedges) & " (expected 2)" severity note;

    wait until rising_edge(clk);

    ----------------------------------------------------------------
    -- 4) READ MISS
    ----------------------------------------------------------------
    report "=== Starting READ MISS Test ===" severity note;
    tag        <= '0';
    valid      <= '1';
    read_write <= '1';
    wait until rising_edge(clk);
    start <= '1';

    wait until falling_edge(clk); 
    wait for 1 ps;

    wait until rising_edge(clk);
    start <= '0';

    cnt_negedges := 0;
    loop
      wait until falling_edge(clk); 
      wait for 1 ps;
      if busy = '1' then
        cnt_negedges := cnt_negedges + 1;
        if cnt_negedges <= 5 or cnt_negedges >= 16 then
          report "READ_MISS: busy edge #" & integer'image(cnt_negedges) & 
                 ", state=" & integer'image(to_integer(unsigned(state_dbg_sig))) &
                 ", next=" & integer'image(to_integer(unsigned(next_state_dbg_sig))) &
                 ", counter=" & integer'image(to_integer(unsigned(counter_dbg_sig)))
                 severity note;
        end if;
      end if;
      exit when busy = '0';
    end loop;
    report "READ_MISS: Total = " & integer'image(cnt_negedges) & " (expected 18)" severity note;

    wait for 10 ns;
    report "=== Simulation Finished ===" severity failure;
  end process;

end sim;
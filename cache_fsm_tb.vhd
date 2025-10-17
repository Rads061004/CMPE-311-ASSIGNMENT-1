library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library std;
use std.textio.all;
use IEEE.std_logic_textio.all;

entity cache_fsm_tb is
end cache_fsm_tb;

architecture tb of cache_fsm_tb is
  signal clk        : std_logic := '0';
  signal reset      : std_logic := '0';
  signal start      : std_logic := '0';
  signal tag        : std_logic := '0';
  signal valid      : std_logic := '0';
  signal read_write : std_logic := '0';
  signal busy       : std_logic;
  signal done       : std_logic;

  constant TCLK : time := 10 ns;

  component cache_fsm
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

  -- Minimal transaction record (no string field)
  type txn_t is record
    tag   : std_logic;
    valid : std_logic;
    rw    : std_logic;  -- 1=read, 0=write
  end record;

  type txn_vec_t is array (natural range <>) of txn_t;

  constant TXNS : txn_vec_t(0 to 5) := (
    (tag=>'1', valid=>'1', rw=>'1'), -- read hit
    (tag=>'1', valid=>'1', rw=>'0'), -- write hit
    (tag=>'0', valid=>'1', rw=>'1'), -- read miss (tag mismatch)
    (tag=>'1', valid=>'0', rw=>'0'), -- write miss (invalid)
    (tag=>'1', valid=>'1', rw=>'1'), -- read hit #2
    (tag=>'0', valid=>'1', rw=>'0')  -- write miss (tag mismatch)
  );
begin
  -- UUT
  UUT : cache_fsm
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

  -- Clock
  clk <= not clk after TCLK/2;

  -- Reset
  process
  begin
    reset <= '1';
    wait for 3*TCLK;
    reset <= '0';
    wait;
  end process;

  -- Stimulus (local procedure with waits)
  stim : process
    procedure run_txn(
      constant s_tag   : in std_logic;
      constant s_valid : in std_logic;
      constant s_rw    : in std_logic
    ) is
      variable l      : line;
      variable cycles : integer := 0;
    begin
      tag        <= s_tag;
      valid      <= s_valid;
      read_write <= s_rw;

      -- one-cycle start pulse
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';

      -- count cycles until done
      cycles := 0;
      while done = '0' loop
        wait until rising_edge(clk);
        cycles := cycles + 1;
      end loop;

      -- print summary
      write(l, string'("txn tag="));   write(l, s_tag);
      write(l, string'(" valid="));    write(l, s_valid);
      write(l, string'(" rw="));       write(l, s_rw);
      write(l, string'(" -> cycles_to_done=")); write(l, cycles);
      writeline(output, l);

      -- allow DONE->IDLE
      wait until rising_edge(clk);
    end run_txn;

    variable l : line;
  begin
    write(l, string'("# cache_fsm TB (stdout prints)"));
    writeline(output, l);
    write(l, string'("# Expect: READ_HIT=2, WRITE_HIT=3, READ_MISS=19, WRITE_MISS=3 cycles"));
    writeline(output, l);

    wait until reset = '0';
    wait until rising_edge(clk);

    for i in TXNS'range loop
      run_txn(TXNS(i).tag, TXNS(i).valid, TXNS(i).rw);
    end loop;

    write(l, string'("# Done. Stopping simulation."));
    writeline(output, l);
    wait for 5*TCLK;

    std.env.stop;
    wait;
  end process stim;
end;

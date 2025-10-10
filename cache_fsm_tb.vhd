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

  type txn_t is record
    start  : std_logic;  -- (kept for readability; we always pulse start)
    tag    : std_logic;
    valid  : std_logic;
    rw     : std_logic;  -- 1=read, 0=write
    name   : string(1 to 16);
  end record;

  -- Named, unconstrained array type + constrained constant
  type txn_vec_t is array (natural range <>) of txn_t;

  constant TXNS : txn_vec_t(0 to 5) := (
    (start=>'1', tag=>'1', valid=>'1', rw=>'1', name=>"READ_HIT       "),
    (start=>'1', tag=>'1', valid=>'1', rw=>'0', name=>"WRITE_HIT      "),
    (start=>'1', tag=>'0', valid=>'1', rw=>'1', name=>"READ_MISS(tag) "),
    (start=>'1', tag=>'1', valid=>'0', rw=>'0', name=>"WRITE_MISS(inv)"),
    (start=>'1', tag=>'1', valid=>'1', rw=>'1', name=>"READ_HIT #2    "),
    (start=>'1', tag=>'0', valid=>'1', rw=>'0', name=>"WRITE_MISS(tag)")
  );
begin
  -- DUT
  dut: entity work.cache_fsm
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

  -- Clock & reset
  clk <= not clk after TCLK/2;

  process
  begin
    reset <= '1';
    wait for 3*TCLK;
    reset <= '0';
    wait;
  end process;

  -- One-transaction runner + stdout print
  procedure run_txn(
    constant label    : in string;
    constant s_tag    : in std_logic;
    constant s_valid  : in std_logic;
    constant s_rw     : in std_logic;
    variable cycles   : out integer
  ) is
    variable l : line;
  begin
    tag        <= s_tag;
    valid      <= s_valid;
    read_write <= s_rw;

    start <= '1';
    wait until rising_edge(clk);
    start <= '0';

    cycles := 0;
    while done = '0' loop
      wait until rising_edge(clk);
      cycles := cycles + 1;
    end loop;

    write(l, string'("txn "));
    write(l, label);
    write(l, string'(" : tag="));   write(l, s_tag);
    write(l, string'(" valid="));   write(l, s_valid);
    write(l, string'(" rw="));      write(l, s_rw);
    write(l, string'("  -> cycles_to_done=")); write(l, cycles);
    writeline(output, l);

    wait until rising_edge(clk);  -- DONE->IDLE
  end procedure;

  -- Stimulus
  process
    variable l : line;
    variable c : integer;
  begin
    write(l, string'("# cache_fsm TB (self-contained stimuli; stdout prints)"));
    writeline(output, l);
    write(l, string'("# Expect: READ_HIT=2, WRITE_HIT=3, READ_MISS=19, WRITE_MISS=3 cycles"));
    writeline(output, l);

    wait until reset = '0';
    wait until rising_edge(clk);

    for i in TXNS'range loop
      run_txn(TXNS(i).name, TXNS(i).tag, TXNS(i).valid, TXNS(i).rw, c);
    end loop;

    write(l, string'("# Done. Stopping simulation."));
    writeline(output, l);
    wait for 5*TCLK;
    std.env.stop;  -- or: assert false severity failure;
    wait;
  end process;
end architecture tb;

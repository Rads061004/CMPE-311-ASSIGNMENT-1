library ieee;
use ieee.std_logic_1164.all;

-- req_qualifier:
-- Captures the request attributes (start, write?, hit?) on the falling edge
-- and holds them stable for the rest of the transaction.
--
-- latch_go       := registered copy of start_in
-- latched_write  := on a falling edge:
--                      if start_in='1' then is_write_in
--                      else hold previous latched_write
-- latched_hit    := same pattern using is_hit_in
--
-- All flops async reset to '0'.
-- Implemented structurally using dff_fall + gates. No processes.

entity req_qualifier is
  port (
    clk           : in  std_logic;
    reset         : in  std_logic;
    start_in      : in  std_logic;  -- asserted when CPU issues a new request
    is_write_in   : in  std_logic;  -- 1 = write, 0 = read
    is_hit_in     : in  std_logic;  -- 1 = hit,   0 = miss

    latch_go      : out std_logic;  -- registered start pulse
    latched_write : out std_logic;  -- sticky captured write/read qualifier
    latched_hit   : out std_logic   -- sticky captured hit/miss qualifier
  );
end req_qualifier;

architecture structural of req_qualifier is

  --------------------------------------------------------------------
  -- Components we need (pure structural building blocks)
  --------------------------------------------------------------------

  component dff_fall
    port (
      clk   : in  std_logic;
      reset : in  std_logic;
      d     : in  std_logic;
      q     : out std_logic
    );
  end component;

  component and2
    port (
      a : in  std_logic;
      b : in  std_logic;
      y : out std_logic
    );
  end component;

  component or2
    port (
      a : in  std_logic;
      b : in  std_logic;
      y : out std_logic
    );
  end component;

  component inv
    port (
      a : in  std_logic;
      y : out std_logic
    );
  end component;

  --------------------------------------------------------------------
  -- Internal nets
  --------------------------------------------------------------------

  -- Flop outputs
  signal latch_go_q       : std_logic;
  signal latched_write_q  : std_logic;
  signal latched_hit_q    : std_logic;

  -- Mux control logic for conditional capture
  -- For write:  D = (start_in & is_write_in) OR ((~start_in) & latched_write_q)
  -- For hit:    D = (start_in & is_hit_in)   OR ((~start_in) & latched_hit_q)

  signal start_n               : std_logic;

  -- write path
  signal cap_write_path        : std_logic;  -- start_in AND is_write_in
  signal hold_write_path       : std_logic;  -- (~start_in) AND latched_write_q
  signal next_latched_write_d  : std_logic;  -- OR of the two

  -- hit path
  signal cap_hit_path          : std_logic;  -- start_in AND is_hit_in
  signal hold_hit_path         : std_logic;  -- (~start_in) AND latched_hit_q
  signal next_latched_hit_d    : std_logic;  -- OR of the two

begin

  --------------------------------------------------------------------
  -- Invert start_in once
  --------------------------------------------------------------------
  u_inv_start : inv
    port map (
      a => start_in,
      y => start_n
    );

  --------------------------------------------------------------------
  -- WRITE qualifier capture mux logic
  --------------------------------------------------------------------

  -- cap_write_path = start_in AND is_write_in
  u_cap_write : and2
    port map (
      a => start_in,
      b => is_write_in,
      y => cap_write_path
    );

  -- hold_write_path = (~start_in) AND latched_write_q
  u_hold_write_and : and2
    port map (
      a => start_n,
      b => latched_write_q,
      y => hold_write_path
    );

  -- next_latched_write_d = cap_write_path OR hold_write_path
  u_or_write : or2
    port map (
      a => cap_write_path,
      b => hold_write_path,
      y => next_latched_write_d
    );

  --------------------------------------------------------------------
  -- HIT qualifier capture mux logic
  --------------------------------------------------------------------

  -- cap_hit_path = start_in AND is_hit_in
  u_cap_hit : and2
    port map (
      a => start_in,
      b => is_hit_in,
      y => cap_hit_path
    );

  -- hold_hit_path = (~start_in) AND latched_hit_q
  u_hold_hit_and : and2
    port map (
      a => start_n,
      b => latched_hit_q,
      y => hold_hit_path
    );

  -- next_latched_hit_d = cap_hit_path OR hold_hit_path
  u_or_hit : or2
    port map (
      a => cap_hit_path,
      b => hold_hit_path,
      y => next_latched_hit_d
    );

  --------------------------------------------------------------------
  -- Flop for latch_go_q:
  -- latch_go_q <= start_in on each falling edge (async reset to '0')
  --------------------------------------------------------------------

  u_ff_latch_go : dff_fall
    port map (
      clk   => clk,
      reset => reset,
      d     => start_in,
      q     => latch_go_q
    );

  --------------------------------------------------------------------
  -- Flop for latched_write_q:
  -- D is next_latched_write_d computed above (structural mux)
  --------------------------------------------------------------------

  u_ff_latched_write : dff_fall
    port map (
      clk   => clk,
      reset => reset,
      d     => next_latched_write_d,
      q     => latched_write_q
    );

  --------------------------------------------------------------------
  -- Flop for latched_hit_q:
  -- D is next_latched_hit_d computed above (structural mux)
  --------------------------------------------------------------------

  u_ff_latched_hit : dff_fall
    port map (
      clk   => clk,
      reset => reset,
      d     => next_latched_hit_d,
      q     => latched_hit_q
    );

  --------------------------------------------------------------------
  -- Drive outputs
  --------------------------------------------------------------------
  latch_go      <= latch_go_q;
  latched_write <= latched_write_q;
  latched_hit   <= latched_hit_q;

end structural;

library ieee;
use ieee.std_logic_1164.all;

entity req_qualifier is
  port (
    clk           : in  std_logic;
    reset         : in  std_logic;
    start_in      : in  std_logic;  
    is_write_in   : in  std_logic;  
    is_hit_in     : in  std_logic;  

    latch_go      : out std_logic;  
    latched_write : out std_logic;  
    latched_hit   : out std_logic   
  );
end req_qualifier;

architecture structural of req_qualifier is

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

  signal latch_go_q       : std_logic;
  signal latched_write_q  : std_logic;
  signal latched_hit_q    : std_logic;

  signal start_n               : std_logic;

  signal cap_write_path        : std_logic;  
  signal hold_write_path       : std_logic;  
  signal next_latched_write_d  : std_logic;  

  signal cap_hit_path          : std_logic;  
  signal hold_hit_path         : std_logic;  
  signal next_latched_hit_d    : std_logic;  

begin

  u_inv_start : inv
    port map (
      a => start_in,
      y => start_n
    );

  u_cap_write : and2
    port map (
      a => start_in,
      b => is_write_in,
      y => cap_write_path
    );

  u_hold_write_and : and2
    port map (
      a => start_n,
      b => latched_write_q,
      y => hold_write_path
    );

  u_or_write : or2
    port map (
      a => cap_write_path,
      b => hold_write_path,
      y => next_latched_write_d
    );

  u_cap_hit : and2
    port map (
      a => start_in,
      b => is_hit_in,
      y => cap_hit_path
    );

  u_hold_hit_and : and2
    port map (
      a => start_n,
      b => latched_hit_q,
      y => hold_hit_path
    );

  u_or_hit : or2
    port map (
      a => cap_hit_path,
      b => hold_hit_path,
      y => next_latched_hit_d
    );

  u_ff_latch_go : dff_fall
    port map (
      clk   => clk,
      reset => reset,
      d     => start_in,
      q     => latch_go_q
    );

  u_ff_latched_write : dff_fall
    port map (
      clk   => clk,
      reset => reset,
      d     => next_latched_write_d,
      q     => latched_write_q
    );

  u_ff_latched_hit : dff_fall
    port map (
      clk   => clk,
      reset => reset,
      d     => next_latched_hit_d,
      q     => latched_hit_q
    );

  latch_go      <= latch_go_q;
  latched_write <= latched_write_q;
  latched_hit   <= latched_hit_q;

end structural;


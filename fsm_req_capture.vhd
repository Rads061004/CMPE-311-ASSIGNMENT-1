library ieee;
use ieee.std_logic_1164.all;

entity fsm_req_capture is
  port (
    clk         : in  std_logic;
    reset       : in  std_logic;

    start_in    : in  std_logic;
    rdwr_in     : in  std_logic;  -- cpu_rd_wrn (1=read, 0=write)
    hit_in      : in  std_logic;  -- hit_sel  (1=hit this index)
    valid_in    : in  std_logic;  -- valid_sel

    start_q     : out std_logic;
    rdwr_q      : out std_logic;
    hit_q       : out std_logic;
    valid_q     : out std_logic
  );
end fsm_req_capture;

architecture structural of fsm_req_capture is

  ----------------------------------------------------------------
  -- We will reuse your falling-edge DFF primitive for each bit.
  -- dff_fall must already exist in your file list and looks like:
  --   entity dff_fall is
  --     port ( clk, reset : in std_logic; d : in std_logic; q : out std_logic );
  --   end dff_fall;
  ----------------------------------------------------------------
  component dff_fall
    port (
      clk   : in  std_logic;
      reset : in  std_logic;
      d     : in  std_logic;
      q     : out std_logic
    );
  end component;

begin

  u_cap_start : dff_fall
    port map (
      clk   => clk,
      reset => reset,
      d     => start_in,
      q     => start_q
    );

  u_cap_rw : dff_fall
    port map (
      clk   => clk,
      reset => reset,
      d     => rdwr_in,
      q     => rdwr_q
    );

  u_cap_hit : dff_fall
    port map (
      clk   => clk,
      reset => reset,
      d     => hit_in,
      q     => hit_q
    );

  u_cap_valid : dff_fall
    port map (
      clk   => clk,
      reset => reset,
      d     => valid_in,
      q     => valid_q
    );

end structural;

library ieee;
use ieee.std_logic_1164.all;

entity req_latch is
  port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    start_in    : in  std_logic;
    cpu_rd_wrn  : in  std_logic;
    hit_sel_in  : in  std_logic;
    latch_go    : out std_logic;
    L_is_write  : out std_logic;
    L_is_hit    : out std_logic
  );
end req_latch;

architecture behavioral of req_latch is
  signal latch_go_q   : std_logic := '0';
  signal L_is_write_q : std_logic := '0';
  signal L_is_hit_q   : std_logic := '0';
  
  -- Sample hit_sel on RISING edge (half cycle after address change)
  -- This gives the combinational hit detection path time to settle
  signal hit_sampled  : std_logic := '0';
  signal start_sampled : std_logic := '0';
  signal rd_wrn_sampled : std_logic := '1';
begin
  --------------------------------------------------------------------
  -- Stage 1: Sample inputs on RISING edge
  -- This occurs half a cycle AFTER the falling edge where address
  -- and start change, giving combinational paths time to settle.
  --------------------------------------------------------------------
  process(clk, reset)
  begin
    if reset = '1' then
      start_sampled  <= '0';
      rd_wrn_sampled <= '1';
      hit_sampled    <= '0';
    elsif rising_edge(clk) then
      start_sampled  <= start_in;
      rd_wrn_sampled <= cpu_rd_wrn;
      hit_sampled    <= hit_sel_in;  -- NOW stable!
    end if;
  end process;
  
  --------------------------------------------------------------------
  -- Stage 2: Use the stable sampled values on FALLING edge
  --------------------------------------------------------------------
  process(clk, reset)
  begin
    if reset = '1' then
      latch_go_q   <= '0';
      L_is_write_q <= '0';
      L_is_hit_q   <= '0';
    elsif falling_edge(clk) then
      latch_go_q <= start_sampled;
      if start_sampled = '1' then
        L_is_write_q <= not rd_wrn_sampled;
        L_is_hit_q   <= hit_sampled;  -- Use stable sampled value
      end if;
    end if;
  end process;
  
  latch_go   <= latch_go_q;
  L_is_write <= L_is_write_q;
  L_is_hit   <= L_is_hit_q;
end behavioral;
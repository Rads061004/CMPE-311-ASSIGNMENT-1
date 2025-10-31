library ieee;
use ieee.std_logic_1164.all;

entity hit_stabilizer is
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;

    start_in   : in  std_logic;
    hit_raw    : in  std_logic;   -- raw combinational hit_sel
    hit_sync   : out std_logic    -- registered, stable version
  );
end hit_stabilizer;

architecture behavioral of hit_stabilizer is
  signal hit_q : std_logic := '0';
begin
  process(clk, reset)
  begin
    if reset = '1' then
      hit_q <= '0';
    elsif rising_edge(clk) then
      -- Latch only when a new request is launched by CPU
      if start_in = '1' then
        hit_q <= hit_raw;
      end if;
    end if;
  end process;

  hit_sync <= hit_q;
end behavioral;

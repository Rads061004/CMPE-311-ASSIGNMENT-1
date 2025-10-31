library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity refill_ctrl is
  port (
    clk            : in  std_logic;
    reset          : in  std_logic;
    fsm_en         : in  std_logic;

    mem_en_q       : out std_logic;
    refill_active  : out std_logic;
    refill_cnt     : out std_logic_vector(4 downto 0)  -- 0..31
  );
end refill_ctrl;

architecture behavioral of refill_ctrl is
  signal mem_en_q_q      : std_logic := '0';
  signal refill_active_q : std_logic := '0';
  signal refill_cnt_q    : unsigned(4 downto 0) := (others => '0');
begin
  process(clk, reset)
  begin
    if reset = '1' then
      mem_en_q_q      <= '0';
      refill_active_q <= '0';
      refill_cnt_q    <= (others => '0');
    elsif falling_edge(clk) then
      -- track previous mem_en
      mem_en_q_q <= fsm_en;

      -- start refill on rising edge of fsm_en
      if (mem_en_q_q = '0' and fsm_en = '1') then
        refill_active_q <= '1';
        refill_cnt_q    <= (others => '0');
      elsif refill_active_q = '1' then
        refill_cnt_q <= refill_cnt_q + 1;
        if refill_cnt_q >= to_unsigned(16, 5) then
          refill_active_q <= '0';
        end if;
      end if;
    end if;
  end process;

  mem_en_q      <= mem_en_q_q;
  refill_active <= refill_active_q;
  refill_cnt    <= std_logic_vector(refill_cnt_q);
end behavioral;

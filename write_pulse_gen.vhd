library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity write_pulse_gen is
  port (
    clk            : in  std_logic;
    reset          : in  std_logic;

    latch_go       : in  std_logic;
    L_is_write     : in  std_logic;
    L_is_hit       : in  std_logic;

    refill_active  : in  std_logic;
    refill_cnt     : in  std_logic_vector(4 downto 0);

    we_top         : out std_logic;
    set_tag_top    : out std_logic
  );
end write_pulse_gen;

architecture behavioral of write_pulse_gen is
  signal we_q      : std_logic := '0';
  signal settag_q  : std_logic := '0';

  -- convenience casts
  function u5(s : std_logic_vector(4 downto 0)) return unsigned is
  begin
    return unsigned(s);
  end u5;
begin
  process(clk, reset)
    variable we_pulse      : std_logic;
    variable set_tag_pulse : std_logic;
  begin
    if reset = '1' then
      we_q     <= '0';
      settag_q <= '0';
    elsif falling_edge(clk) then
      we_pulse      := '0';
      set_tag_pulse := '0';

      -- CPU write hit pulse
      if (latch_go = '1') and (L_is_write = '1') and (L_is_hit = '1') then
        we_pulse := '1';
      end if;

      -- Refill write pulses from memory at counts 8,10,12,14
      if refill_active = '1' then
        if    u5(refill_cnt) = to_unsigned(8,5)
           or u5(refill_cnt) = to_unsigned(10,5)
           or u5(refill_cnt) = to_unsigned(12,5)
           or u5(refill_cnt) = to_unsigned(14,5) then
          we_pulse := '1';

          -- first refill beat also sets tag/valid
          if u5(refill_cnt) = to_unsigned(8,5) then
            set_tag_pulse := '1';
          end if;
        end if;
      end if;

      we_q     <= we_pulse;
      settag_q <= set_tag_pulse;
    end if;
  end process;

  we_top      <= we_q;
  set_tag_top <= settag_q;
end behavioral;

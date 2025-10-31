library ieee;
use ieee.std_logic_1164.all;

entity tbuf8 is
  port (
    d   : in  std_logic_vector(7 downto 0);
    en  : in  std_logic;
    b   : out std_logic_vector(7 downto 0)
  );
end tbuf8;

architecture behavioral of tbuf8 is
begin
  b <= d when en = '1' else (others => 'Z');
end behavioral;


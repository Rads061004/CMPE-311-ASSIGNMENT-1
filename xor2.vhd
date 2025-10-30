library ieee;
use ieee.std_logic_1164.all;

entity xor2 is
  port (
    a, b : in  std_logic;
    y    : out std_logic
  );
end xor2;

architecture structural of xor2 is
  component not1 port (a : in std_logic; y : out std_logic); end component;
  component and2 port (a, b : in std_logic; y : out std_logic); end component;
  component or2 port (a, b : in std_logic; y : out std_logic); end component;

  signal a_n, b_n     : std_logic;
  signal term_a, term_b : std_logic;
  
begin
  u_not_a : not1 port map (a => a, y => a_n);
  u_not_b : not1 port map (a => b, y => b_n);
  
  u_and_a : and2 port map (a => a_n, b => b, y => term_a);
  u_and_b : and2 port map (a => a, b => b_n, y => term_b);
  
  u_or_y : or2 port map (a => term_a, b => term_b, y => y);
end structural;
library ieee;
use ieee.std_logic_1164.all;

entity xnor2 is
  port (
    a, b : in  std_logic;
    z    : out std_logic
  );
end xnor2;

architecture structural of xnor2 is
  component xor2 port (a, b : in std_logic; z : out std_logic); end component;
  component not1 port (a : in std_logic; z : out std_logic); end component;
  
  signal xor_out : std_logic;
  
begin
  u_xor : xor2 port map (a => a, b => b, z => xor_out);
  u_not : not1 port map (a => xor_out, z => z);
end structural;
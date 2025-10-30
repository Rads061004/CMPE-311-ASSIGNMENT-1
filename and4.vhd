library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity and4 is
    port (
        a, b, c, d : in  STD_LOGIC;
        y          : out STD_LOGIC
    );
end and4;

architecture behavioral of and4 is
begin
    y <= a and b and c and d;
end behavioral;
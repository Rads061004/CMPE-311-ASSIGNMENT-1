library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity and3 is
    port (
        a, b, c : in  STD_LOGIC;
        y       : out STD_LOGIC
    );
end and3;

architecture behavioral of and3 is
begin
    y <= a and b and c;
end behavioral;
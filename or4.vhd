library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity or4 is
    port (
        a, b, c, d : in  STD_LOGIC;
        y          : out STD_LOGIC
    );
end or4;

architecture behavioral of or4 is
begin
    y <= a or b or c or d;
end behavioral;
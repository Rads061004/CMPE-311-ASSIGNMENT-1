library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity or3 is
    port (
        a, b, c : in  STD_LOGIC;
        y       : out STD_LOGIC
    );
end or3;

architecture behavioral of or3 is
begin
    y <= a or b or c;
end behavioral;
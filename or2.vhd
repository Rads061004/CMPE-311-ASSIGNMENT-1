library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity or2 is
    port (
        a, b : in  STD_LOGIC;
        y    : out STD_LOGIC
    );
end or2;

architecture behavioral of or2 is
begin
    y <= a or b;
end behavioral;
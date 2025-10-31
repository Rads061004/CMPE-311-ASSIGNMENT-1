library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity and2 is
    port (
        a, b : in  STD_LOGIC;
        y    : out STD_LOGIC
    );
end and2;

architecture behavioral of and2 is
begin
    y <= a and b;

end behavioral;

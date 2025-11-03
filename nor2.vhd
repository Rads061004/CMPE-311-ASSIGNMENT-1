library ieee;
use ieee.std_logic_1164.all;

entity nor2 is
    port (
        a, b : in  STD_LOGIC;
        y    : out STD_LOGIC
    );
end nor2;

architecture behavioral of nor2 is
begin
    y <= a nor b;
end behavioral;
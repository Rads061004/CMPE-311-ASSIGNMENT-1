library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity inv is
    port (
        a : in  STD_LOGIC;
        y : out STD_LOGIC
    );
end inv;

architecture behavioral of inv is
begin
    y <= not a;
end behavioral;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity or8 is
    port (
        a, b, c, d, e, f, g, h : in  STD_LOGIC;
        y                      : out STD_LOGIC
    );
end or8;

architecture behavioral of or8 is
begin
    y <= a or b or c or d or e or f or g or h;
end behavioral;
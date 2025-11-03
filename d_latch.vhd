library ieee;
use ieee.std_logic_1164.all;

entity dlatch is
    port (
        enable : in  STD_LOGIC;
        d      : in  STD_LOGIC;
        q      : out STD_LOGIC
    );
end dlatch;

architecture behavioral of dlatch is
begin
    process(enable, d)
    begin
        if enable = '1' then
            q <= d;
        end if;
    end process;
end behavioral;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Compare counter >= 0 (always true)
entity gte_zero is
    port (
        a   : in  STD_LOGIC_VECTOR(4 downto 0);
        gte : out STD_LOGIC
    );
end gte_zero;

architecture structural of gte_zero is
    signal vdd : STD_LOGIC;
begin
    vdd <= '1';
    gte <= vdd;
end structural;
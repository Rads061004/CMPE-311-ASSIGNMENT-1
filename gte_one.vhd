
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Compare counter >= 1
entity gte_one is
    port (
        a   : in  STD_LOGIC_VECTOR(4 downto 0);
        gte : out STD_LOGIC
    );
end gte_one;

architecture structural of gte_one is
    component gte5
        port (a, b : in STD_LOGIC_VECTOR(4 downto 0); gte : out STD_LOGIC);
    end component;
    
    signal one : STD_LOGIC_VECTOR(4 downto 0);
begin
    one <= "00001";
    u_gte: gte5 port map (a => a, b => one, gte => gte);
end structural;
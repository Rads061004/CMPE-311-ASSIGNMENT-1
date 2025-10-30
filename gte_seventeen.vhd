
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Compare counter >= 17
entity gte_seventeen is
    port (
        a   : in  STD_LOGIC_VECTOR(4 downto 0);
        gte : out STD_LOGIC
    );
end gte_seventeen;

architecture structural of gte_seventeen is
    component gte5
        port (a, b : in STD_LOGIC_VECTOR(4 downto 0); gte : out STD_LOGIC);
    end component;
    
    signal seventeen : STD_LOGIC_VECTOR(4 downto 0);
begin
    seventeen <= "10001";
    u_gte: gte5 port map (a => a, b => seventeen, gte => gte);
end structural;
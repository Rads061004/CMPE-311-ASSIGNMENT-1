library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity eq2 is
    port (
        a, b : in  STD_LOGIC_VECTOR(1 downto 0);
        eq   : out STD_LOGIC
    );
end eq2;

architecture structural of eq2 is
    component xnor2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    component and2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    signal xnor_out : STD_LOGIC_VECTOR(1 downto 0);
begin
    u_xnor0: xnor2 port map (a => a(0), b => b(0), y => xnor_out(0));
    u_xnor1: xnor2 port map (a => a(1), b => b(1), y => xnor_out(1));
    u_and: and2 port map (a => xnor_out(0), b => xnor_out(1), y => eq);
end structural;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity eq3 is
    port (
        a, b : in  STD_LOGIC_VECTOR(2 downto 0);
        eq   : out STD_LOGIC
    );
end eq3;

architecture structural of eq3 is
    component xnor2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    component and3
        port (a, b, c : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    signal xnor_out : STD_LOGIC_VECTOR(2 downto 0);
begin
    u_xnor0: xnor2 port map (a => a(0), b => b(0), y => xnor_out(0));
    u_xnor1: xnor2 port map (a => a(1), b => b(1), y => xnor_out(1));
    u_xnor2: xnor2 port map (a => a(2), b => b(2), y => xnor_out(2));
    u_and: and3 port map (a => xnor_out(0), b => xnor_out(1), c => xnor_out(2), y => eq);
end structural;
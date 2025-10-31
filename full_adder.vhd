library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity full_adder is
    port (
        a, b, cin : in  STD_LOGIC;
        sum, cout : out STD_LOGIC
    );
end full_adder;

architecture structural of full_adder is
    component xor2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    component and2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    component or3
        port (a, b, c : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    signal xor1, and1, and2, and3 : STD_LOGIC;
begin
    u_xor1: xor2 port map (a => a, b => b, y => xor1);
    u_xor2: xor2 port map (a => xor1, b => cin, y => sum);
    u_and1: and2 port map (a => a, b => b, y => and1);
    u_and2: and2 port map (a => a, b => cin, y => and2);
    u_and3: and2 port map (a => b, b => cin, y => and3);
    u_or: or3 port map (a => and1, b => and2, c => and3, y => cout);

end structural;

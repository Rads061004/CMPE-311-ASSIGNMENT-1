library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity adder5 is
    port (
        a, b : in  STD_LOGIC_VECTOR(4 downto 0);
        cin  : in  STD_LOGIC;
        sum  : out STD_LOGIC_VECTOR(4 downto 0);
        cout : out STD_LOGIC
    );
end adder5;

architecture structural of adder5 is
    component full_adder
        port (a, b, cin : in STD_LOGIC; sum, cout : out STD_LOGIC);
    end component;
    
    signal c : STD_LOGIC_VECTOR(4 downto 0);
begin
    u_fa0: full_adder port map (a => a(0), b => b(0), cin => cin, sum => sum(0), cout => c(0));
    u_fa1: full_adder port map (a => a(1), b => b(1), cin => c(0), sum => sum(1), cout => c(1));
    u_fa2: full_adder port map (a => a(2), b => b(2), cin => c(1), sum => sum(2), cout => c(2));
    u_fa3: full_adder port map (a => a(3), b => b(3), cin => c(2), sum => sum(3), cout => c(3));
    u_fa4: full_adder port map (a => a(4), b => b(4), cin => c(3), sum => sum(4), cout => cout);
end structural;
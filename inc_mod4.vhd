library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Incrementer modulo 4: cycles through 00->01->10->11->00
entity inc_mod4 is
    port (
        a   : in  STD_LOGIC_VECTOR(1 downto 0);
        inc : out STD_LOGIC_VECTOR(1 downto 0)
    );
end inc_mod4;

architecture structural of inc_mod4 is
    component inv
        port (a : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    component and2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    component xor2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;

    signal a0, a1 : STD_LOGIC;
    signal a0_n   : STD_LOGIC;
    signal inc0, inc1 : STD_LOGIC;
    
begin
    a0 <= a(0);
    a1 <= a(1);
    
    -- inc(0) = NOT a(0)
    u_inv0: inv port map (a => a0, y => inc0);
    
    -- inc(1) = a(1) XOR a(0)
    u_xor1: xor2 port map (a => a1, b => a0, y => inc1);
    
    inc(0) <= inc0;
    inc(1) <= inc1;
    
end structural;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- 2-to-1 Multiplexer
entity mux2to1 is
    port (
        d0, d1 : in  STD_LOGIC;
        sel    : in  STD_LOGIC;
        y      : out STD_LOGIC
    );
end mux2to1;

architecture structural of mux2to1 is
    component and2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    component or2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    component inv
        port (a : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    signal sel_n, and0_out, and1_out : STD_LOGIC;
begin
    u_inv: inv port map (a => sel, y => sel_n);
    u_and0: and2 port map (a => d0, b => sel_n, y => and0_out);
    u_and1: and2 port map (a => d1, b => sel, y => and1_out);
    u_or: or2 port map (a => and0_out, b => and1_out, y => y);
end structural;
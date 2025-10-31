library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity gte5 is
    port (
        a, b : in  STD_LOGIC_VECTOR(4 downto 0);
        gte  : out STD_LOGIC
    );
end gte5;

architecture structural of gte5 is
    component inv
        port (a : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    component and2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    component or2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    component xnor2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    signal eq : STD_LOGIC_VECTOR(4 downto 0);
    signal b_n : STD_LOGIC_VECTOR(4 downto 0);
    signal gt : STD_LOGIC_VECTOR(4 downto 0);
    signal and_temp : STD_LOGIC_VECTOR(3 downto 0);
    signal gte_cascade : STD_LOGIC_VECTOR(4 downto 0);
begin
    gen_eq: for i in 0 to 4 generate
        u_xnor: xnor2 port map (a => a(i), b => b(i), y => eq(i));
        u_inv: inv port map (a => b(i), y => b_n(i));
    end generate;
    
    gen_gt: for i in 0 to 4 generate
        u_and: and2 port map (a => a(i), b => b_n(i), y => gt(i));
    end generate;
    
    gte_cascade(4) <= gt(4);
    
    u_and3: and2 port map (a => eq(3), b => gte_cascade(4), y => and_temp(3));
    u_or3: or2 port map (a => gt(3), b => and_temp(3), y => gte_cascade(3));
    
    u_and2: and2 port map (a => eq(2), b => gte_cascade(3), y => and_temp(2));
    u_or2: or2 port map (a => gt(2), b => and_temp(2), y => gte_cascade(2));
    
    u_and1: and2 port map (a => eq(1), b => gte_cascade(2), y => and_temp(1));
    u_or1: or2 port map (a => gt(1), b => and_temp(1), y => gte_cascade(1));
    
    u_and0: and2 port map (a => eq(0), b => gte_cascade(1), y => and_temp(0));
    u_or0: or2 port map (a => gt(0), b => and_temp(0), y => gte);

end structural;

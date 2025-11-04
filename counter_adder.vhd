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
    
    signal xor1, and1, and2_sig, and3 : STD_LOGIC;
begin
    -- sum = a XOR b XOR cin
    u_xor1: xor2 port map (a => a, b => b, y => xor1);
    u_xor2: xor2 port map (a => xor1, b => cin, y => sum);
    -- carry out logic
    u_and1: and2 port map (a => a, b => b, y => and1);
    u_and2: and2 port map (a => a, b => cin, y => and2_sig);
    u_and3: and2 port map (a => b, b => cin, y => and3);
    u_or: or3 port map (a => and1, b => and2_sig, c => and3, y => cout);
end structural;

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
    -- chain of 5 full adders
    u_fa0: full_adder port map (a => a(0), b => b(0), cin => cin, sum => sum(0), cout => c(0));
    u_fa1: full_adder port map (a => a(1), b => b(1), cin => c(0), sum => sum(1), cout => c(1));
    u_fa2: full_adder port map (a => a(2), b => b(2), cin => c(1), sum => sum(2), cout => c(2));
    u_fa3: full_adder port map (a => a(3), b => b(3), cin => c(2), sum => sum(3), cout => c(3));
    u_fa4: full_adder port map (a => a(4), b => b(4), cin => c(3), sum => sum(4), cout => cout);
end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity inc5 is
    port (
        a   : in  STD_LOGIC_VECTOR(4 downto 0);
        inc : out STD_LOGIC_VECTOR(4 downto 0)
    );
end inc5;

architecture structural of inc5 is
    component adder5
        port (a, b : in STD_LOGIC_VECTOR(4 downto 0); cin : in STD_LOGIC; 
              sum : out STD_LOGIC_VECTOR(4 downto 0); cout : out STD_LOGIC);
    end component;
    
    signal one : STD_LOGIC_VECTOR(4 downto 0);
    signal cout_unused : STD_LOGIC;
    signal cin_gnd : STD_LOGIC;
begin
    -- add 1 to input
    one <= "00001";
    cin_gnd <= '0';
    u_add: adder5 port map (a => a, b => one, cin => cin_gnd, sum => inc, cout => cout_unused);
end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity reg5_rise is
    port (
        clk   : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        en    : in  STD_LOGIC;
        d     : in  STD_LOGIC_VECTOR(4 downto 0);
        q     : out STD_LOGIC_VECTOR(4 downto 0)
    );
end reg5_rise;

architecture structural of reg5_rise is
    component dff_rise
        port (clk : in STD_LOGIC; reset : in STD_LOGIC; d : in STD_LOGIC; q : out STD_LOGIC);
    end component;
    component mux2to1
        port (d0, d1 : in STD_LOGIC; sel : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    signal q_int : STD_LOGIC_VECTOR(4 downto 0);
    signal d_mux : STD_LOGIC_VECTOR(4 downto 0);
begin
    -- enable controls data load on rising edge
    gen_mux_dff: for i in 0 to 4 generate
        u_mux: mux2to1 port map (d0 => q_int(i), d1 => d(i), sel => en, y => d_mux(i));
        u_dff: dff_rise port map (clk => clk, reset => reset, d => d_mux(i), q => q_int(i));
    end generate;
    
    q <= q_int;
end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity reg3_fall is
    port (
        clk   : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        d     : in  STD_LOGIC_VECTOR(2 downto 0);
        q     : out STD_LOGIC_VECTOR(2 downto 0)
    );
end reg3_fall;

architecture structural of reg3_fall is
    component dff_fall
        port (clk : in STD_LOGIC; reset : in STD_LOGIC; d : in STD_LOGIC; q : out STD_LOGIC);
    end component;
begin
    -- each bit stored in a falling-edge DFF
    gen_dff: for i in 0 to 2 generate
        u_dff: dff_fall port map (clk => clk, reset => reset, d => d(i), q => q(i));
    end generate;

end structural;


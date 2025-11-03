library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mux4to1 is
    port (
        d0, d1, d2, d3 : in  STD_LOGIC;
        sel            : in  STD_LOGIC_VECTOR(1 downto 0);
        y              : out STD_LOGIC
    );
end mux4to1;

architecture structural of mux4to1 is
    component mux2to1
        port (d0, d1 : in STD_LOGIC; sel : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    signal mux_low, mux_high : STD_LOGIC;
begin
    u_mux_low: mux2to1 port map (d0 => d0, d1 => d1, sel => sel(0), y => mux_low);
    u_mux_high: mux2to1 port map (d0 => d2, d1 => d3, sel => sel(0), y => mux_high);
    u_mux_final: mux2to1 port map (d0 => mux_low, d1 => mux_high, sel => sel(1), y => y);
end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
 
entity mux8to1 is
    port (
        d : in  STD_LOGIC_VECTOR(7 downto 0);
        sel : in  STD_LOGIC_VECTOR(2 downto 0);
        y   : out STD_LOGIC
    );
end mux8to1;

architecture structural of mux8to1 is
    component mux4to1
        port (d0, d1, d2, d3 : in STD_LOGIC; sel : in STD_LOGIC_VECTOR(1 downto 0); y : out STD_LOGIC);
    end component;
    component mux2to1
        port (d0, d1 : in STD_LOGIC; sel : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    signal mux_low, mux_high : STD_LOGIC;
begin
    u_mux_low: mux4to1 port map (d0 => d(0), d1 => d(1), d2 => d(2), d3 => d(3), 
                                  sel => sel(1 downto 0), y => mux_low);
    u_mux_high: mux4to1 port map (d0 => d(4), d1 => d(5), d2 => d(6), d3 => d(7), 
                                   sel => sel(1 downto 0), y => mux_high);
    u_mux_final: mux2to1 port map (d0 => mux_low, d1 => mux_high, sel => sel(2), y => y);
end structural;

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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mux2to1_8 is
    port (
        d0  : in  STD_LOGIC_VECTOR(7 downto 0);
        d1  : in  STD_LOGIC_VECTOR(7 downto 0);
        sel : in  STD_LOGIC;
        y   : out STD_LOGIC_VECTOR(7 downto 0)
    );
end mux2to1_8;

architecture structural of mux2to1_8 is
    component mux2to1
        port (
            d0  : in  STD_LOGIC;
            d1  : in  STD_LOGIC;
            sel : in  STD_LOGIC;
            y   : out STD_LOGIC
        );
    end component;
begin
    gen_bits: for i in 0 to 7 generate
        u_mux: mux2to1 port map (d0 => d0(i), d1 => d1(i), sel => sel, y => y(i));
    end generate;
end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mux4to1_8 is
    port (
        d0  : in  STD_LOGIC_VECTOR(7 downto 0);
        d1  : in  STD_LOGIC_VECTOR(7 downto 0);
        d2  : in  STD_LOGIC_VECTOR(7 downto 0);
        d3  : in  STD_LOGIC_VECTOR(7 downto 0);
        sel : in  STD_LOGIC_VECTOR(1 downto 0);
        y   : out STD_LOGIC_VECTOR(7 downto 0)
    );
end mux4to1_8;

architecture structural of mux4to1_8 is
    component mux4to1
        port (
            d0, d1, d2, d3 : in  STD_LOGIC;
            sel            : in  STD_LOGIC_VECTOR(1 downto 0);
            y              : out STD_LOGIC
        );
    end component;
begin
    gen_bits: for i in 0 to 7 generate
        u_muxbit: mux4to1 port map (d0 => d0(i), d1 => d1(i), d2 => d2(i), d3 => d3(i), sel => sel, y => y(i));
    end generate;
end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mux4to1_1 is
    port (
        d0  : in  STD_LOGIC;
        d1  : in  STD_LOGIC;
        d2  : in  STD_LOGIC;
        d3  : in  STD_LOGIC;
        sel : in  STD_LOGIC_VECTOR(1 downto 0);
        y   : out STD_LOGIC
    );
end mux4to1_1;

architecture structural of mux4to1_1 is
    component mux4to1
        port (
            d0  : in  STD_LOGIC;
            d1  : in  STD_LOGIC;
            d2  : in  STD_LOGIC;
            d3  : in  STD_LOGIC;
            sel : in  STD_LOGIC_VECTOR(1 downto 0);
            y   : out STD_LOGIC
        );
    end component;
begin
    u_core: mux4to1 port map (d0 => d0, d1 => d1, d2 => d2, d3 => d3, sel => sel, y => y);
end structural;
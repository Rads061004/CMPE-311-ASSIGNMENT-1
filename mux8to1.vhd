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
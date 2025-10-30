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
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
    -- mux4to1 already does 1-bit, so we just wrap to keep naming parallel
    u_core: mux4to1
        port map (
            d0  => d0,
            d1  => d1,
            d2  => d2,
            d3  => d3,
            sel => sel,
            y   => y
        );
end structural;

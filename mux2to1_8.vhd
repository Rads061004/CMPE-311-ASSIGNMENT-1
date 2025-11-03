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
        u_mux: mux2to1
            port map (
                d0  => d0(i),
                d1  => d1(i),
                sel => sel,
                y   => y(i)
            );
    end generate;
end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mux4to1_2 is
    port (
        d0  : in  STD_LOGIC_VECTOR(1 downto 0);
        d1  : in  STD_LOGIC_VECTOR(1 downto 0);
        d2  : in  STD_LOGIC_VECTOR(1 downto 0);
        d3  : in  STD_LOGIC_VECTOR(1 downto 0);
        sel : in  STD_LOGIC_VECTOR(1 downto 0);
        y   : out STD_LOGIC_VECTOR(1 downto 0)
    );
end mux4to1_2;

architecture structural of mux4to1_2 is
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
    gen_bits: for i in 0 to 1 generate
        u_mux_bit: mux4to1
            port map (
                d0  => d0(i),
                d1  => d1(i),
                d2  => d2(i),
                d3  => d3(i),
                sel => sel,
                y   => y(i)
            );
    end generate;
end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity reg5_fall is
    port (
        clk   : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        en    : in  STD_LOGIC;
        d     : in  STD_LOGIC_VECTOR(4 downto 0);
        q     : out STD_LOGIC_VECTOR(4 downto 0)
    );
end reg5_fall;

architecture structural of reg5_fall is
    component dff_fall
        port (
            clk   : in STD_LOGIC;
            reset : in STD_LOGIC;
            d     : in STD_LOGIC;
            q     : out STD_LOGIC
        );
    end component;

    component mux2to1
        port (
            d0  : in STD_LOGIC;
            d1  : in STD_LOGIC;
            sel : in STD_LOGIC;
            y   : out STD_LOGIC
        );
    end component;

    signal q_int : STD_LOGIC_VECTOR(4 downto 0);
    signal d_sel : STD_LOGIC_VECTOR(4 downto 0);
begin
    gen_regbits: for i in 0 to 4 generate
        u_mux_en: mux2to1
            port map (
                d0  => q_int(i),
                d1  => d(i),
                sel => en,
                y   => d_sel(i)
            );

        u_ff: dff_fall
            port map (
                clk   => clk,
                reset => reset,
                d     => d_sel(i),
                q     => q_int(i)
            );
    end generate;

    q <= q_int;
end structural;


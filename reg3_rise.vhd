library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity reg3_rise is
    port (
        clk   : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        d     : in  STD_LOGIC_VECTOR(2 downto 0);
        q     : out STD_LOGIC_VECTOR(2 downto 0)
    );
end reg3_rise;

architecture structural of reg3_rise is
    component dff_rise
        port (
            clk   : in STD_LOGIC;
            reset : in STD_LOGIC;
            d     : in STD_LOGIC;
            q     : out STD_LOGIC
        );
    end component;
begin
    gen_ffbits: for i in 0 to 2 generate
        u_ff_rise: dff_rise
            port map (
                clk   => clk,
                reset => reset,
                d     => d(i),
                q     => q(i)
            );
    end generate;
end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity reg1_rise_en is
    port (
        clk   : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        en    : in  STD_LOGIC;
        d     : in  STD_LOGIC;
        q     : out STD_LOGIC
    );
end reg1_rise_en;

architecture structural of reg1_rise_en is
    component mux2to1
        port (
            d0  : in  STD_LOGIC;
            d1  : in  STD_LOGIC;
            sel : in  STD_LOGIC;
            y   : out STD_LOGIC
        );
    end component;

    component dff_rise
        port (
            clk   : in  STD_LOGIC;
            reset : in  STD_LOGIC;
            d     : in  STD_LOGIC;
            q     : out STD_LOGIC
        );
    end component;

    signal q_fb  : STD_LOGIC;
    signal d_sel : STD_LOGIC;
begin
    u_mux: mux2to1 port map (d0 => q_fb, d1 => d, sel => en, y => d_sel);
    u_dff: dff_rise port map (clk => clk, reset => reset, d => d_sel, q => q_fb);
    q <= q_fb;
end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity reg2_rise_en is
    port (
        clk   : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        en    : in  STD_LOGIC;
        d     : in  STD_LOGIC_VECTOR(1 downto 0);
        q     : out STD_LOGIC_VECTOR(1 downto 0)
    );
end reg2_rise_en;

architecture structural of reg2_rise_en is
    component mux2to1
        port (
            d0  : in  STD_LOGIC;
            d1  : in  STD_LOGIC;
            sel : in  STD_LOGIC;
            y   : out STD_LOGIC
        );
    end component;

    component dff_rise
        port (
            clk   : in  STD_LOGIC;
            reset : in  STD_LOGIC;
            d     : in  STD_LOGIC;
            q     : out STD_LOGIC
        );
    end component;

    signal q_fb  : STD_LOGIC_VECTOR(1 downto 0);
    signal d_sel : STD_LOGIC_VECTOR(1 downto 0);
begin
    gen_bit: for i in 0 to 1 generate
        u_mux: mux2to1 port map (d0 => q_fb(i), d1 => d(i), sel => en, y => d_sel(i));
        u_dff: dff_rise port map (clk => clk, reset => reset, d => d_sel(i), q => q_fb(i));
    end generate;
    q <= q_fb;
end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity reg8_rise_en is
    port (
        clk   : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        en    : in  STD_LOGIC;
        d     : in  STD_LOGIC_VECTOR(7 downto 0);
        q     : out STD_LOGIC_VECTOR(7 downto 0)
    );
end reg8_rise_en;

architecture structural of reg8_rise_en is
    component mux2to1
        port (
            d0  : in  STD_LOGIC;
            d1  : in  STD_LOGIC;
            sel : in  STD_LOGIC;
            y   : out STD_LOGIC
        );
    end component;

    component dff_rise
        port (
            clk   : in  STD_LOGIC;
            reset : in  STD_LOGIC;
            d     : in  STD_LOGIC;
            q     : out STD_LOGIC
        );
    end component;

    signal q_fb  : STD_LOGIC_VECTOR(7 downto 0);
    signal d_sel : STD_LOGIC_VECTOR(7 downto 0);
begin
    gen_bit: for i in 0 to 7 generate
        u_mux: mux2to1 port map (d0 => q_fb(i), d1 => d(i), sel => en, y => d_sel(i));
        u_dff: dff_rise port map (clk => clk, reset => reset, d => d_sel(i), q => q_fb(i));
    end generate;
    q <= q_fb;
end structural;

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
        u_ff_rise: dff_rise port map (clk => clk, reset => reset, d => d(i), q => q(i));
    end generate;
end structural;

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
        u_mux_en: mux2to1 port map (d0 => q_int(i), d1 => d(i), sel => en, y => d_sel(i));
        u_ff: dff_fall port map (clk => clk, reset => reset, d => d_sel(i), q => q_int(i));
    end generate;
    q <= q_int;
end structural;
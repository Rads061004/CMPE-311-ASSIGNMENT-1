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

    signal q_fb  : STD_LOGIC;  -- internal flop output (fed back)
    signal d_sel : STD_LOGIC;  -- mux output into flop
begin
    -- If en='1', load d. If en='0', hold previous q_fb.
    u_mux: mux2to1
        port map (
            d0  => q_fb,   -- hold path
            d1  => d,      -- new data
            sel => en,
            y   => d_sel
        );

    -- Rising-edge DFF with async reset.
    u_dff: dff_rise
        port map (
            clk   => clk,
            reset => reset,
            d     => d_sel,
            q     => q_fb
        );

    q <= q_fb;
end structural;

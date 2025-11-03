library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity req_latch is
    Port (
        clk          : in  STD_LOGIC;
        reset        : in  STD_LOGIC;
        start        : in  STD_LOGIC;
        read_write   : in  STD_LOGIC;   -- '1' = READ , '0' = WRITE
        req_is_read  : out STD_LOGIC
    );
end req_latch;

architecture Structural of req_latch is

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

    signal q_cur   : STD_LOGIC;
    signal d_next  : STD_LOGIC;

begin
    -- d_next = (start ? read_write : q_cur)
    U_MUX_HOLD_LOAD : mux2to1
        port map (
            d0  => q_cur,
            d1  => read_write,
            sel => start,
            y   => d_next
        );

    -- latch on falling edge, async reset clears it
    U_REQ_FF : dff_fall
        port map (
            clk   => clk,
            reset => reset,
            d     => d_next,
            q     => q_cur
        );

    req_is_read <= q_cur;

end Structural;

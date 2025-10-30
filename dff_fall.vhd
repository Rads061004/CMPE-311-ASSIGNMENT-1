library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- D Flip-Flop with falling edge trigger and reset
entity dff_fall is
    port (
        clk   : in  STD_LOGIC;
        reset : in  STD_LOGIC;
        d     : in  STD_LOGIC;
        q     : out STD_LOGIC
    );
end dff_fall;

architecture behavioral of dff_fall is
begin
    process(clk, reset)
    begin
        if reset = '1' then
            q <= '0';
        elsif falling_edge(clk) then
            q <= d;
        end if;
    end process;
end behavioral;
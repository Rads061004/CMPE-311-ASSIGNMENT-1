library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity state_register is
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        next_state : in  STD_LOGIC_VECTOR(2 downto 0);
        state      : out STD_LOGIC_VECTOR(2 downto 0)
    );
end state_register;

architecture Structural of state_register is
    component dff_fall
        port (clk : in STD_LOGIC; reset : in STD_LOGIC; d : in STD_LOGIC; q : out STD_LOGIC);
    end component;
    
    signal state_int : STD_LOGIC_VECTOR(2 downto 0);
begin
    -- 3 flip-flops for each state bit 
    gen_dff: for i in 0 to 2 generate
        u_dff: dff_fall port map (
            clk   => clk, 
            reset => reset, 
            d     => next_state(i), 
            q     => state_int(i)
        );
    end generate;
            
    -- output current state
    state <= state_int;
end Structural;

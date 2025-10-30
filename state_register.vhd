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

architecture behavioral of state_register is
    signal state_int : STD_LOGIC_VECTOR(2 downto 0) := "000";  -- IDLE from t=0
begin
    process(clk, reset)
    begin
        if reset = '1' then
            state_int <= "000";  -- IDLE
        elsif falling_edge(clk) then
            state_int <= next_state;
        end if;
    end process;

    state <= state_int;
end behavioral;

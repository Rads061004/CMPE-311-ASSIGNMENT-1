library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity state_register is
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        next_state : in  STD_LOGIC_VECTOR(2 downto 0);
        state      : out STD_LOGIC_VECTOR(2 downto 0)
    );
end state_register;

architecture RTL of state_register is
    constant S_IDLE : STD_LOGIC_VECTOR(2 downto 0) := "000";
begin
    process(clk)
    begin
        if falling_edge(clk) then
            if reset = '1' then
                state <= S_IDLE;
            else
                state <= next_state;
            end if;
        end if;
    end process;
end RTL;
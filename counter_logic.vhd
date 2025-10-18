library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity counter_logic is
    Port (
        clk     : in  STD_LOGIC;
        reset   : in  STD_LOGIC;
        state   : in  STD_LOGIC_VECTOR(2 downto 0);
        counter : out INTEGER
    );
end counter_logic;

architecture RTL of counter_logic is
    signal prev_state : STD_LOGIC_VECTOR(2 downto 0) := "000";
    signal cnt        : INTEGER := 0;

    constant S_IDLE       : STD_LOGIC_VECTOR(2 downto 0) := "000";
    constant S_READ_HIT   : STD_LOGIC_VECTOR(2 downto 0) := "001";
    constant S_WRITE_HIT  : STD_LOGIC_VECTOR(2 downto 0) := "010";
    constant S_READ_MISS  : STD_LOGIC_VECTOR(2 downto 0) := "011";
    constant S_WRITE_MISS : STD_LOGIC_VECTOR(2 downto 0) := "100";
    constant S_DONE       : STD_LOGIC_VECTOR(2 downto 0) := "101";
begin
    process(clk, reset)
    begin
        if reset = '1' then
            prev_state <= S_IDLE;
            cnt        <= 0;
            counter    <= 0;
        elsif falling_edge(clk) then
            if state /= prev_state then
                cnt <= 0;              -- entering a new state: start at 0
            else
                if (state = S_READ_HIT) or (state = S_WRITE_HIT) or
                   (state = S_READ_MISS) or (state = S_WRITE_MISS) then
                    if cnt < 1000000 then
                        cnt <= cnt + 1;
                    end if;
                else
                    cnt <= 0;          -- IDLE/DONE
                end if;
            end if;

            prev_state <= state;
            counter    <= cnt;
        end if;
    end process;
end RTL;

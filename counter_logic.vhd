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
    -- state encodings
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
            cnt <= 0;
            counter <= 0;
        elsif rising_edge(clk) then
            -- Detect entry to a new state
            if state /= prev_state then
                -- entering a new state: start counter at 0 (we will increment this cycle if needed)
                if state = S_READ_HIT then
                    cnt <= 0;
                elsif state = S_WRITE_HIT then
                    cnt <= 0;
                elsif state = S_READ_MISS then
                    cnt <= 0;
                elsif state = S_WRITE_MISS then
                    cnt <= 0;
                else
                    cnt <= 0;
                end if;
            else
                -- still in same state: if active counting states, increment up to a safe max
                if state = S_READ_HIT then
                    if cnt < 1000000 then -- arbitrary safe limit
                        cnt <= cnt + 1;
                    end if;
                elsif state = S_WRITE_HIT then
                    if cnt < 1000000 then
                        cnt <= cnt + 1;
                    end if;
                elsif state = S_READ_MISS then
                    if cnt < 1000000 then
                        cnt <= cnt + 1;
                    end if;
                elsif state = S_WRITE_MISS then
                    if cnt < 1000000 then
                        cnt <= cnt + 1;
                    end if;
                else
                    cnt <= 0;
                end if;
            end if;

            prev_state <= state;
            counter <= cnt;
        end if;
    end process;
end RTL;

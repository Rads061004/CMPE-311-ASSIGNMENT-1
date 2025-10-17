library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity next_state_logic is
    Port (
        start      : in  STD_LOGIC;
        tag        : in  STD_LOGIC;
        valid      : in  STD_LOGIC;
        read_write : in  STD_LOGIC;
        state      : in  STD_LOGIC_VECTOR(2 downto 0);
        counter    : in  INTEGER;
        next_state : out STD_LOGIC_VECTOR(2 downto 0)
    );
end next_state_logic;

architecture RTL of next_state_logic is
    constant S_IDLE      : STD_LOGIC_VECTOR(2 downto 0) := "000";
    constant S_READ_HIT  : STD_LOGIC_VECTOR(2 downto 0) := "001";
    constant S_WRITE_HIT : STD_LOGIC_VECTOR(2 downto 0) := "010";
    constant S_READ_MISS : STD_LOGIC_VECTOR(2 downto 0) := "011";
    constant S_WRITE_MISS: STD_LOGIC_VECTOR(2 downto 0) := "100";
    constant S_DONE      : STD_LOGIC_VECTOR(2 downto 0) := "101";
begin
    process(start, tag, valid, read_write, state, counter)
    begin
        -- default: hold state
        next_state <= state;

        if state = S_IDLE then
            if start = '1' then
                if (tag = '1' and valid = '1') then
                    if read_write = '1' then
                        next_state <= S_READ_HIT;
                    else
                        next_state <= S_WRITE_HIT;
                    end if;
                else
                    if read_write = '1' then
                        next_state <= S_READ_MISS;
                    else
                        next_state <= S_WRITE_MISS;
                    end if;
                end if;
            else
                next_state <= S_IDLE;
            end if;

        elsif state = S_READ_HIT then
            if counter >= 2 then
                next_state <= S_DONE;
            else
                next_state <= S_READ_HIT;
            end if;

        elsif state = S_WRITE_HIT then
            if counter >= 3 then
                next_state <= S_DONE;
            else
                next_state <= S_WRITE_HIT;
            end if;

        elsif state = S_READ_MISS then
            if counter >= 19 then
                next_state <= S_DONE;
            else
                next_state <= S_READ_MISS;
            end if;

        elsif state = S_WRITE_MISS then
            if counter >= 3 then
                next_state <= S_DONE;
            else
                next_state <= S_WRITE_MISS;
            end if;

        elsif state = S_DONE then
            next_state <= S_IDLE;

        else
            next_state <= S_IDLE;
        end if;
    end process;
end RTL;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity next_state_logic is
    Port (
        start_q      : in  STD_LOGIC;          -- sampled on rising edge
        hit_q        : in  STD_LOGIC;          -- sampled on rising edge
        read_write_q : in  STD_LOGIC;          -- sampled on rising edge (1=read)
        state        : in  STD_LOGIC_VECTOR(2 downto 0);
        counter      : in  INTEGER;
        next_state   : out STD_LOGIC_VECTOR(2 downto 0)
    );
end next_state_logic;

architecture RTL of next_state_logic is
    constant S_IDLE       : STD_LOGIC_VECTOR(2 downto 0) := "000";
    constant S_READ_HIT   : STD_LOGIC_VECTOR(2 downto 0) := "001";
    constant S_WRITE_HIT  : STD_LOGIC_VECTOR(2 downto 0) := "010";
    constant S_READ_MISS  : STD_LOGIC_VECTOR(2 downto 0) := "011";
    constant S_WRITE_MISS : STD_LOGIC_VECTOR(2 downto 0) := "100";
    constant S_DONE       : STD_LOGIC_VECTOR(2 downto 0) := "101";
begin
    process(start_q, hit_q, read_write_q, state, counter)
    begin
        next_state <= state;

        if state = S_IDLE then
            if start_q = '1' then
                if hit_q = '1' then
                    if read_write_q = '1' then
                        next_state <= S_READ_HIT;
                    else
                        next_state <= S_WRITE_HIT;
                    end if;
                else
                    if read_write_q = '1' then
                        next_state <= S_READ_MISS;
                    else
                        next_state <= S_WRITE_MISS;
                    end if;
                end if;
            else
                next_state <= S_IDLE;
            end if;

        -- Transition to DONE when counter >= D-1
        elsif state = S_READ_HIT then             -- D=2  -> threshold 1
            if counter >= 1 then next_state <= S_DONE; else next_state <= S_READ_HIT; end if;

        elsif state = S_WRITE_HIT then            -- D=3  -> threshold 2
            if counter >= 2 then next_state <= S_DONE; else next_state <= S_WRITE_HIT; end if;

        elsif state = S_READ_MISS then            -- D=19 -> threshold 18
            if counter >= 18 then next_state <= S_DONE; else next_state <= S_READ_MISS; end if;

        elsif state = S_WRITE_MISS then           -- D=3  -> threshold 2
            if counter >= 2 then next_state <= S_DONE; else next_state <= S_WRITE_MISS; end if;

        elsif state = S_DONE then
            next_state <= S_IDLE;

        else
            next_state <= S_IDLE;
        end if;
    end process;
end RTL;

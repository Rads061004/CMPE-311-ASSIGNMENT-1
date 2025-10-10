library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cache_fsm is
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        start      : in  STD_LOGIC;
        tag        : in  STD_LOGIC;
        valid      : in  STD_LOGIC;
        read_write : in  STD_LOGIC; 
        busy       : out STD_LOGIC;
        done       : out STD_LOGIC
    );
end cache_fsm;

architecture Behavioral of cache_fsm is

    type state_type is (
        IDLE, READ_HIT, WRITE_HIT, READ_MISS, WRITE_MISS, S_DONE
    );
    signal state, next_state : state_type := IDLE;

    signal counter : integer := 0;
    signal busy_reg : STD_LOGIC := '0';

begin

    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            counter <= 0;
            busy_reg <= '0';
        elsif rising_edge(clk) then
            state <= next_state;

            case state is
                when IDLE =>
                    counter <= 0;
                    busy_reg <= '0';

                when READ_HIT =>
                    if counter < 2 then
                        counter <= counter + 1;
                        if counter < 1 then
                            busy_reg <= '1';
                        else
                            busy_reg <= '0';
                        end if;
                    end if;

                when WRITE_HIT =>
                    if counter < 3 then
                        counter <= counter + 1;
                        if counter < 2 then
                            busy_reg <= '1';
                        else
                            busy_reg <= '0';
                        end if;
                    end if;

                when READ_MISS =>
                    if counter < 19 then
                        counter <= counter + 1;
                        if counter < 18 then
                            busy_reg <= '1';
                        else
                            busy_reg <= '0';
                        end if;
                    end if;

                when WRITE_MISS =>
                    if counter < 3 then
                        counter <= counter + 1;
                        if counter < 2 then
                            busy_reg <= '1';
                        else
                            busy_reg <= '0';
                        end if;
                    end if;

                when S_DONE =>
                    counter <= 0;
                    busy_reg <= '0';
            end case;
        end if;
    end process;

    -- Next-state logic
    process(state, start, tag, valid, read_write, counter)
    begin
        next_state <= state;

        case state is
            when IDLE =>
                if start = '1' then
                    if (tag and valid) = '1' then
                        if read_write = '1' then
                            next_state <= READ_HIT;
                        else
                            next_state <= WRITE_HIT;
                        end if;
                    else
                        if read_write = '1' then
                            next_state <= READ_MISS;
                        else
                            next_state <= WRITE_MISS;
                        end if;
                    end if;
                else
                    next_state <= IDLE;
                end if;

            when READ_HIT =>
                if counter = 2 then
                    next_state <= DONE;
                else
                    next_state <= READ_HIT;
                end if;

            when WRITE_HIT =>
                if counter = 3 then
                    next_state <= S_DONE;
                else
                    next_state <= WRITE_HIT;
                end if;

            when READ_MISS =>
                if counter = 19 then
                    next_state <= S_DONE;
                else
                    next_state <= READ_MISS;
                end if;

            when WRITE_MISS =>
                if counter = 3 S_then
                    next_state <= DONE;
                else
                    next_state <= WRITE_MISS;
                end if;

            when S_DONE =>
                next_state <= IDLE;
        end case;
    end process;

    busy <= busy_reg;
    done <= '1' when state = S_DONE else '0';

end Behavioral;

            
  

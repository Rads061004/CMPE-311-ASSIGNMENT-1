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
    signal start_edge : STD_LOGIC := '0';

begin

    ------------------------------------------------------------------
    -- Start edge detection (posedge)
    ------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            start_edge <= '0';
        elsif rising_edge(clk) then
            start_edge <= start;  -- capture start signal only on posedge
        end if;
    end process;


    ------------------------------------------------------------------
    -- State transition and counter update on posedge
    ------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
            counter <= 0;
        elsif rising_edge(clk) then
            state <= next_state;

            case state is
                when IDLE =>
                    counter <= 0;

                when READ_HIT =>
                    if counter < 2 then
                        counter <= counter + 1;
                    end if;

                when WRITE_HIT =>
                    if counter < 3 then
                        counter <= counter + 1;
                    end if;

                when READ_MISS =>
                    if counter < 19 then
                        counter <= counter + 1;
                    end if;

                when WRITE_MISS =>
                    if counter < 3 then
                        counter <= counter + 1;
                    end if;

                when S_DONE =>
                    counter <= 0;

            end case;
        end if;
    end process;


    ------------------------------------------------------------------
    -- Busy control on negative edge (lags start by half a cycle)
    ------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            busy_reg <= '0';
        elsif falling_edge(clk) then
            case state is
                when READ_HIT =>
                    if counter < 1 then
                        busy_reg <= '1';
                    else
                        busy_reg <= '0';
                    end if;

                when WRITE_HIT =>
                    if counter < 2 then
                        busy_reg <= '1';
                    else
                        busy_reg <= '0';
                    end if;

                when READ_MISS =>
                    if counter < 18 then
                        busy_reg <= '1';
                    else
                        busy_reg <= '0';
                    end if;

                when WRITE_MISS =>
                    if counter < 2 then
                        busy_reg <= '1';
                    else
                        busy_reg <= '0';
                    end if;

                when others =>
                    busy_reg <= '0';
            end case;
        end if;
    end process;


    ------------------------------------------------------------------
    -- Next-state logic (combinational)
    ------------------------------------------------------------------
    process(state, start_edge, tag, valid, read_write, counter)
    begin
        next_state <= state;

        case state is
            when IDLE =>
                if start_edge = '1' then
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
                    next_state <= S_DONE;
                end if;

            when WRITE_HIT =>
                if counter = 3 then
                    next_state <= S_DONE;
                end if;

            when READ_MISS =>
                if counter = 19 then
                    next_state <= S_DONE;
                end if;

            when WRITE_MISS =>
                if counter = 3 then
                    next_state <= S_DONE;
                end if;

            when S_DONE =>
                next_state <= IDLE;
        end case;
    end process;

    ------------------------------------------------------------------
    -- Output assignments
    ------------------------------------------------------------------
    busy <= busy_reg;
    done <= '1' when state = S_DONE else '0';

end Behavioral;
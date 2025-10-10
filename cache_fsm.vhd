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
        read_write : in  STD_LOGIC;  -- 1 = read, 0 = write
        busy       : out STD_LOGIC;
        done       : out STD_LOGIC
    );
end cache_fsm;

architecture Behavioral of cache_fsm is

    type state_type is (IDLE, READ_HIT, WRITE_HIT, READ_MISS, WRITE_MISS, S_DONE);
    signal state, next_state : state_type := IDLE;

    signal counter       : integer := 0;
    signal counter_enable : std_logic := '0';
    signal busy_reg       : std_logic := '0';

    -- internal latch for start since busy goes high at negedge
    signal start_latched : std_logic := '0';

begin

    ----------------------------------------------------------
    -- 1. Latch CPU start at rising edge
    ----------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            start_latched <= '0';
        elsif rising_edge(clk) then
            if start = '1' then
                start_latched <= '1';
            else
                start_latched <= '0';
            end if;
        end if;
    end process;


    ----------------------------------------------------------
    -- 2. FSM state transitions (synchronous with rising edge)
    ----------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            state <= IDLE;
        elsif rising_edge(clk) then
            state <= next_state;
        end if;
    end process;


    ----------------------------------------------------------
    -- 3. Next-State Combinational Logic
    ----------------------------------------------------------
    process(state, start_latched, tag, valid, read_write, counter)
    begin
        next_state <= state;

        case state is
            when IDLE =>
                if start_latched = '1' then
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
                if counter = 3 then
                    next_state <= S_DONE;
                else
                    next_state <= WRITE_MISS;
                end if;

            when S_DONE =>
                next_state <= IDLE;
        end case;
    end process;


    ----------------------------------------------------------
    -- 4. Counter Logic (separate)
    ----------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            counter <= 0;
        elsif rising_edge(clk) then
            case state is
                when READ_HIT | WRITE_HIT | READ_MISS | WRITE_MISS =>
                    if next_state = state then
                        counter <= counter + 1;
                    else
                        counter <= 0;
                    end if;
                when others =>
                    counter <= 0;
            end case;
        end if;
    end process;


    ----------------------------------------------------------
    -- 5. Busy asserted at negative edge after start
    ----------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            busy_reg <= '0';
        elsif falling_edge(clk) then
            case next_state is
                when IDLE =>
                    if start_latched = '1' then
                        busy_reg <= '1';  -- Assert busy on next negedge after start
                    else
                        busy_reg <= '0';
                    end if;

                when READ_HIT =>
                    if counter >= 1 then
                        busy_reg <= '0';
                    else
                        busy_reg <= '1';
                    end if;

                when WRITE_HIT =>
                    if counter >= 2 then
                        busy_reg <= '0';
                    else
                        busy_reg <= '1';
                    end if;

                when READ_MISS =>
                    if counter >= 18 then
                        busy_reg <= '0';
                    else
                        busy_reg <= '1';
                    end if;

                when WRITE_MISS =>
                    if counter >= 2 then
                        busy_reg <= '0';
                    else
                        busy_reg <= '1';
                    end if;

                when others =>
                    busy_reg <= '0';
            end case;
        end if;
    end process;


    ----------------------------------------------------------
    -- 6. Outputs
    ----------------------------------------------------------
    busy <= busy_reg;
    done <= '1' when state = S_DONE else '0';

end Behavioral;
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

    -- Function to check if the state matches
    function is_work(s : STD_LOGIC_VECTOR(2 downto 0)) return boolean is
    begin
        return (s = S_READ_HIT) or (s = S_WRITE_HIT) or
               (s = S_READ_MISS) or (s = S_WRITE_MISS);
    end is_work;
begin
    -- Count on the rising edge so value is stable at the falling edge decisions
    process(clk, reset)
        variable next_cnt : integer;
    begin
        if reset = '1' then
            prev_state <= S_IDLE;
            cnt        <= 0;
            counter    <= 0;
        elsif rising_edge(clk) then
            -- derive next counter value first, then update signals
            if state /= prev_state then
                next_cnt := 0;                        -- reset on entry to any state
            else
                if is_work(state) then
                    next_cnt := cnt + 1;             -- increment while in work state
                else
                    next_cnt := 0;                   -- hold 0 in IDLE/DONE
                end if;
            end if;

            cnt        <= next_cnt;                   
            counter    <= next_cnt;                   
            prev_state <= state;
        end if;
    end process;
end RTL;

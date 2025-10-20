library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity output_logic is
    Port (
        clk         : in  STD_LOGIC;
        state       : in  STD_LOGIC_VECTOR(2 downto 0);
        next_state  : in  STD_LOGIC_VECTOR(2 downto 0); -- look-ahead
        counter     : in  INTEGER;
        busy        : out STD_LOGIC;
        done        : out STD_LOGIC;
        en          : out STD_LOGIC;
        OE_CD       : out STD_LOGIC;
        OE_MA       : out STD_LOGIC
    );
end output_logic;

architecture RTL of output_logic is
    signal busy_reg : STD_LOGIC := '0';

    constant S_IDLE       : STD_LOGIC_VECTOR(2 downto 0) := "000";
    constant S_READ_HIT   : STD_LOGIC_VECTOR(2 downto 0) := "001";
    constant S_WRITE_HIT  : STD_LOGIC_VECTOR(2 downto 0) := "010";
    constant S_READ_MISS  : STD_LOGIC_VECTOR(2 downto 0) := "011";
    constant S_WRITE_MISS : STD_LOGIC_VECTOR(2 downto 0) := "100";
    constant S_DONE       : STD_LOGIC_VECTOR(2 downto 0) := "101";

    -- Function to check if the state matches
    function is_work(s: STD_LOGIC_VECTOR(2 downto 0)) return boolean is
    begin
        return (s = S_READ_HIT) or (s = S_WRITE_HIT) or
               (s = S_READ_MISS) or (s = S_WRITE_MISS);
    end;
begin
    -- Busy timed from next_state
    process(clk)
    begin
        if falling_edge(clk) then
            if is_work(next_state) then
                busy_reg <= '1';  
            elsif (next_state = S_DONE) or (next_state = S_IDLE) then
                busy_reg <= '0';  -- deassert on the transition
            else
                busy_reg <= '0';
            end if;
        end if;
    end process;

    -- Combinational outputs
    process(state, counter)
    begin
        en    <= '0';
        OE_CD <= '0';
        OE_MA <= '0';
        done  <= '0';

        case state is
            when S_READ_HIT =>
                if counter >= 1 then OE_CD <= '1'; end if;

            when S_READ_MISS =>
                if counter = 1 then en <= '1'; OE_MA <= '1'; end if;

            when S_WRITE_MISS =>
                if counter = 1 then en <= '1'; OE_MA <= '1'; end if;

            when S_DONE =>
                done <= '1';

            when others =>
                null;
        end case;
    end process;

    busy <= busy_reg;
end RTL;

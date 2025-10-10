library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity output_logic is
    Port (
        clk        : in  STD_LOGIC;
        state      : in  STD_LOGIC_VECTOR(2 downto 0);
        counter    : in  INTEGER;
        busy       : out STD_LOGIC;
        done       : out STD_LOGIC;
        en         : out STD_LOGIC;
        OE_CD      : out STD_LOGIC;
        OE_MA      : out STD_LOGIC
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
begin

    -- busy asserted/deasserted on falling edge to meet your timing
    process(clk)
    begin
        if falling_edge(clk) then
            case state is
                when S_READ_HIT =>
                    -- busy should be asserted on the negedge one cycle after start,
                    -- and go low after 1 cycle (i.e., when counter >= 1)
                    if counter < 1 then
                        busy_reg <= '1';
                    else
                        busy_reg <= '0';
                    end if;

                when S_WRITE_HIT =>
                    -- busy low after 2 cycles => busy asserted while counter < 2
                    if counter < 2 then
                        busy_reg <= '1';
                    else
                        busy_reg <= '0';
                    end if;

                when S_READ_MISS =>
                    -- busy low after 18 cycles (so asserted while counter < 18)
                    if counter < 18 then
                        busy_reg <= '1';
                    else
                        busy_reg <= '0';
                    end if;

                when S_WRITE_MISS =>
                    -- busy low after 2 cycles (so asserted while counter < 2)
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

    -- combinational outputs (en, OE_CD, OE_MA, done)
    process(state, counter)
    begin
        -- defaults
        en    <= '0';
        OE_CD <= '0';
        OE_MA <= '0';
        done  <= '0';

        case state is
            when S_IDLE =>
                null;

            when S_READ_HIT =>
                -- output enable for cache data only when presenting data (you can refine)
                if counter >= 1 then
                    OE_CD <= '1';
                else
                    OE_CD <= '0';
                end if;

            when S_WRITE_HIT =>
                -- during write hit, you may want to assert OE_CD as write strobe; leave as 0 by default
                null;

            when S_READ_MISS =>
                -- for read miss, en (memory enable) is asserted early in the miss cycle,
                -- here we assert en when counter = 1 to simulate pulse at start of mem access.
                -- Adjust exact cycle indexes as needed to match the waveform/memory timing.
                if counter = 1 then
                    en <= '1';
                    OE_MA <= '1';  -- present address to memory (OE_MA used as strobe)
                else
                    en <= '0';
                    OE_MA <= '0';
                end if;

            when S_WRITE_MISS =>
                -- write miss: no allocate; write-through to memory might be required
                if counter = 1 then
                    en <= '1';
                    OE_MA <= '1';
                else
                    en <= '0';
                    OE_MA <= '0';
                end if;

            when S_DONE =>
                done <= '1';
            when others =>
                null;
        end case;
    end process;

    busy <= busy_reg;

end RTL;

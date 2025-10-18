library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity output_logic is
    Port (
        clk        : in  STD_LOGIC;  -- unused; kept for interface stability
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
    constant S_IDLE       : STD_LOGIC_VECTOR(2 downto 0) := "000";
    constant S_READ_HIT   : STD_LOGIC_VECTOR(2 downto 0) := "001";
    constant S_WRITE_HIT  : STD_LOGIC_VECTOR(2 downto 0) := "010";
    constant S_READ_MISS  : STD_LOGIC_VECTOR(2 downto 0) := "011";
    constant S_WRITE_MISS : STD_LOGIC_VECTOR(2 downto 0) := "100";
    constant S_DONE       : STD_LOGIC_VECTOR(2 downto 0) := "101";
begin
    -- Pure combinational outputs from (state, counter)
    process(state, counter)
        variable budget : integer;  -- BUSY-high length = D-1
    begin
        -- defaults
        en    <= '0';
        OE_CD <= '0';
        OE_MA <= '0';
        done  <= '0';

        -- BUSY high while counter < (D-1)
        case state is
            when S_READ_HIT   => budget := 1;   -- D=2  -> BUSY while counter < 1
            when S_WRITE_HIT  => budget := 2;   -- D=3  -> BUSY while counter < 2
            when S_READ_MISS  => budget := 18;  -- D=19 -> BUSY while counter < 18
            when S_WRITE_MISS => budget := 2;   -- D=3  -> BUSY while counter < 2
            when others       => budget := -1;  -- IDLE/DONE -> BUSY=0
        end case;

        if (budget >= 0) and (counter < budget) then
            busy <= '1';
        else
            busy <= '0';
        end if;

        -- DONE is a one-state pulse
        if state = S_DONE then
            done <= '1';
        end if;

        -- Example side-band strobes (adjust later to your datapath)
        case state is
            when S_READ_HIT =>
                if counter >= 1 then
                    OE_CD <= '1';       -- present data to CPU
                end if;

            when S_READ_MISS =>
                if counter = 1 then
                    en   <= '1';        -- memory enable pulse
                    OE_MA<= '1';
                end if;

            when S_WRITE_MISS =>
                if counter = 1 then
                    en   <= '1';
                    OE_MA<= '1';
                end if;

            when others =>
                null;
        end case;
    end process;
end RTL;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fsm is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        start : in  std_logic;
        busy  : out std_logic
    );
end fsm;

architecture rtl of fsm is
    type state_t is (IDLE, WR_HIT, DONE);
    signal CS, NS : state_t;

    signal counter_en  : std_logic := '0';
    signal delay_count : unsigned(7 downto 0) := (others => '0');
    signal busy_reg    : std_logic := '0';

begin
    busy <= busy_reg;
 
    process(clk)
    begin
        if falling_edge(clk) then
            if counter_en = '1' then
                delay_count <= delay_count + 1;
            else
                delay_count <= (others => '0');
            end if;
        end if;
    end process;
            
    process(clk)
    begin
        if falling_edge(clk) then
            if reset = '1' then
                CS <= IDLE;
            else
                CS <= NS;
            end if;
        end if;
    end process;

    process(CS, start, delay_count)
    begin
        NS <= CS; 

        case CS is

            when IDLE =>
                if start = '1' then
                    NS <= WR_HIT;
                else
                    NS <= IDLE;
                end if;

            when WR_HIT =>
                if delay_count = 1 then
                    NS <= DONE;
                else
                    NS <= WR_HIT;
                end if;

            when DONE =>
                NS <= IDLE;

        end case;
    end process;

    process(clk)
    begin
        if falling_edge(clk) then
            if reset = '1' then
                busy_reg    <= '0';
                counter_en  <= '0';
            else
                case NS is

                    when IDLE =>
                        null;

                    when WR_HIT =>
                        counter_en <= '1';
                        busy_reg   <= '1';

                    when DONE =>
                        counter_en <= '0';
                        busy_reg   <= '0';

                end case;
            end if;
        end if;
    end process;

end rtl;


library ieee;
use ieee.std_logic_1164.all;

entity fsm_tb is
end fsm_tb;

architecture sim of fsm_tb is
    
    component fsm
        port (
            clk   : in  std_logic;
            reset : in  std_logic;
            start : in  std_logic;
            busy  : out std_logic
        );
    end component;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';
    signal start : std_logic := '0';
    signal busy  : std_logic;

begin
    uut: fsm
        port map (
            clk   => clk,
            reset => reset,
            start => start,
            busy  => busy
        );

    clk_process : process
    begin
        clk <= '0';
        wait for 1 ns;
        clk <= '1';
        wait for 1 ns;
    end process;

    stim_proc : process
    begin

        wait until rising_edge(clk);
        reset <= '1';

        wait until rising_edge(clk);
        reset <= '0';

        wait until rising_edge(clk);
        start <= '1';

        wait until rising_edge(clk);
        start <= '0';

        wait for 20 ns;

        assert false report "Simulation Finished" severity failure;
    end process;

end sim;


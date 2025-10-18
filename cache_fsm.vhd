library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_fsm is
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;
        -- CPU controls (driven on posedge by TB/CPU)
        start      : in  std_logic;
        tag        : in  std_logic;
        valid      : in  std_logic;
        read_write : in  std_logic;  -- 1 = read, 0 = write
        -- status
        busy       : out std_logic;
        done       : out std_logic
    );
end cache_fsm;

architecture rtl of cache_fsm is
    type state_t is (IDLE, READ_HIT, WRITE_HIT, READ_MISS, WRITE_MISS, S_DONE);
    signal CS, NS : state_t := IDLE;

    -- optional posedge sampling (kept only for debug/visibility, not used in IDLE decision)
    signal start_q : std_logic := '0';
    signal rw_q    : std_logic := '0';
    signal hit_q   : std_logic := '0';  -- tag and valid

    -- negedge counter (0 on entry; ++ each negedge in work states)
    signal counter_en  : std_logic := '0';
    signal delay_count : unsigned(7 downto 0) := (others => '0');

    -- registered outputs (negedge)
    signal busy_reg : std_logic := '0';
    signal done_reg : std_logic := '0';
begin
    busy <= busy_reg;
    done <= done_reg;

    --------------------------------------------------------------------
    -- Optional: sample for waveform clarity (not used in IDLE decision)
    --------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                start_q <= '0';
                rw_q    <= '0';
                hit_q   <= '0';
            else
                start_q <= start;
                rw_q    <= read_write;
                hit_q   <= (tag and valid);
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Counter (negedge)
    --------------------------------------------------------------------
    process(clk)
    begin
        if falling_edge(clk) then
            if reset = '1' then
                delay_count <= (others => '0');
            else
                if counter_en = '1' then
                    delay_count <= delay_count + 1;
                else
                    delay_count <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- State register (negedge)
    --------------------------------------------------------------------
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

    --------------------------------------------------------------------
    -- Next-state logic
    --  • In IDLE: use RAW inputs (start/read_write/tag/valid) to avoid posedge race
    --  • In work states: use D−1 thresholds on the negedge counter
    --------------------------------------------------------------------
    process(CS, start, read_write, tag, valid, delay_count)
    begin
        NS <= CS;  -- default

        case CS is
            when IDLE =>
                if start = '1' then
                    if (tag = '1' and valid = '1') then
                        if read_write = '1' then
                            NS <= READ_HIT;
                        else
                            NS <= WRITE_HIT;
                        end if;
                    else
                        if read_write = '1' then
                            NS <= READ_MISS;
                        else
                            NS <= WRITE_MISS;
                        end if;
                    end if;
                else
                    NS <= IDLE;
                end if;

            when READ_HIT =>
                if delay_count = 0 then NS <= S_DONE; else NS <= READ_HIT; end if;   -- 1 negedge

            when WRITE_HIT =>
                if delay_count = 1 then NS <= S_DONE; else NS <= WRITE_HIT; end if;  -- 2 negedges

            when READ_MISS =>
                if delay_count = 17 then NS <= S_DONE; else NS <= READ_MISS; end if; -- 18 negedges

            when WRITE_MISS =>
                if delay_count = 1 then NS <= S_DONE; else NS <= WRITE_MISS; end if; -- 2 negedges

            when S_DONE =>
                NS <= IDLE;
        end case;
    end process;

    --------------------------------------------------------------------
    -- Outputs / control (negedge) — drive from **NS** (look-ahead)
    -- This keeps BUSY asserting on the very first falling edge after START.
    --------------------------------------------------------------------
    process(clk)
    begin
        if falling_edge(clk) then
            if reset = '1' then
                busy_reg   <= '0';
                done_reg   <= '0';
                counter_en <= '0';
            else
                done_reg <= '0';  -- pulse only in S_DONE

                case NS is
                    when IDLE =>
                        counter_en <= '0';
                        busy_reg   <= '0';

                    when READ_HIT | WRITE_HIT | READ_MISS | WRITE_MISS =>
                        counter_en <= '1';
                        busy_reg   <= '1';  -- assert on this first negedge

                    when S_DONE =>
                        counter_en <= '0';
                        busy_reg   <= '0';
                        done_reg   <= '1';
                end case;
            end if;
        end if;
    end process;

end rtl;

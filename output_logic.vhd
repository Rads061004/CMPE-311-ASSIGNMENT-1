library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity output_logic is
    Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        state       : in  STD_LOGIC_VECTOR(2 downto 0);
        next_state  : in  STD_LOGIC_VECTOR(2 downto 0);
        counter     : in  STD_LOGIC_VECTOR(4 downto 0);
        busy        : out STD_LOGIC;
        done        : out STD_LOGIC;
        en          : out STD_LOGIC;
        OE_CD       : out STD_LOGIC;
        OE_MA       : out STD_LOGIC
    );
end output_logic;

architecture Structural of output_logic is
    ----------------------------------------------------------------
    -- component declarations
    ----------------------------------------------------------------
    component and2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;

    component or2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;

    component or4
        port (a, b, c, d : in STD_LOGIC; y : out STD_LOGIC);
    end component;

    component eq3
        port (a, b : in STD_LOGIC_VECTOR(2 downto 0); eq : out STD_LOGIC);
    end component;

    component gte_one
        port (a : in STD_LOGIC_VECTOR(4 downto 0); gte : out STD_LOGIC);
    end component;

    component inv
        port (a : in STD_LOGIC; y : out STD_LOGIC);
    end component;

    component and4
        port (a, b, c, d : in STD_LOGIC; y : out STD_LOGIC);
    end component;

    component dff_fall
        port (clk : in STD_LOGIC; reset : in STD_LOGIC; d : in STD_LOGIC; q : out STD_LOGIC);
    end component;

    ----------------------------------------------------------------
    -- internal signals
    ----------------------------------------------------------------

    -- Treat state encodings as signals (VHDL-87 style constants)
    signal S_IDLE        : STD_LOGIC_VECTOR(2 downto 0);
    signal S_READ_HIT    : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_HIT   : STD_LOGIC_VECTOR(2 downto 0);
    signal S_READ_MISS   : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_MISS  : STD_LOGIC_VECTOR(2 downto 0);
    signal S_DONE        : STD_LOGIC_VECTOR(2 downto 0);

    -- decode current state (for output control signals)
    signal is_read_hit    : STD_LOGIC;
    signal is_write_hit   : STD_LOGIC;
    signal is_read_miss   : STD_LOGIC;
    signal is_write_miss  : STD_LOGIC;
    signal is_done        : STD_LOGIC;
    signal is_idle        : STD_LOGIC;

    -- decode NEXT state for busy (CRITICAL!)
    signal next_is_read_hit    : STD_LOGIC;
    signal next_is_write_hit   : STD_LOGIC;
    signal next_is_read_miss   : STD_LOGIC;
    signal next_is_write_miss  : STD_LOGIC;

    -- "work" qualifier for next state
    signal next_is_work    : STD_LOGIC;

    -- registered busy signal
    signal busy_int        : STD_LOGIC;

    -- counter-related signals
    signal cnt_gte_1      : STD_LOGIC;
    signal cnt0           : STD_LOGIC;
    signal cnt1           : STD_LOGIC;
    signal cnt2           : STD_LOGIC;
    signal cnt3           : STD_LOGIC;
    signal cnt4           : STD_LOGIC;
    signal cnt1_n         : STD_LOGIC;
    signal cnt2_n         : STD_LOGIC;
    signal cnt3_n         : STD_LOGIC;
    signal cnt4_n         : STD_LOGIC;
    signal upper_zero     : STD_LOGIC;
    signal cnt_is_1       : STD_LOGIC;

    -- per-state enables for outputs
    signal read_hit_oe_cd     : STD_LOGIC;
    signal read_miss_en       : STD_LOGIC;
    signal write_miss_en      : STD_LOGIC;
    signal read_miss_oe_ma    : STD_LOGIC;
    signal write_miss_oe_ma   : STD_LOGIC;

begin
    ----------------------------------------------------------------
    -- explicit "constants"
    ----------------------------------------------------------------
    S_IDLE        <= "000";
    S_READ_HIT    <= "001";
    S_WRITE_HIT   <= "010";
    S_READ_MISS   <= "011";
    S_WRITE_MISS  <= "100";
    S_DONE        <= "101";

    ----------------------------------------------------------------
    -- decode current state (for output control signals)
    ----------------------------------------------------------------
    u_eq_read_hit: eq3
        port map (
            a  => state,
            b  => S_READ_HIT,
            eq => is_read_hit
        );

    u_eq_write_hit: eq3
        port map (
            a  => state,
            b  => S_WRITE_HIT,
            eq => is_write_hit
        );

    u_eq_read_miss: eq3
        port map (
            a  => state,
            b  => S_READ_MISS,
            eq => is_read_miss
        );

    u_eq_write_miss: eq3
        port map (
            a  => state,
            b  => S_WRITE_MISS,
            eq => is_write_miss
        );

    u_eq_done: eq3
        port map (
            a  => state,
            b  => S_DONE,
            eq => is_done
        );

    u_eq_idle: eq3
        port map (
            a  => state,
            b  => S_IDLE,
            eq => is_idle
        );

    ----------------------------------------------------------------
    -- decode NEXT state to determine if we should be busy
    -- THIS IS THE CRITICAL FIX!
    ----------------------------------------------------------------
    u_eq_next_read_hit: eq3
        port map (
            a  => next_state,
            b  => S_READ_HIT,
            eq => next_is_read_hit
        );

    u_eq_next_write_hit: eq3
        port map (
            a  => next_state,
            b  => S_WRITE_HIT,
            eq => next_is_write_hit
        );

    u_eq_next_read_miss: eq3
        port map (
            a  => next_state,
            b  => S_READ_MISS,
            eq => next_is_read_miss
        );

    u_eq_next_write_miss: eq3
        port map (
            a  => next_state,
            b  => S_WRITE_MISS,
            eq => next_is_write_miss
        );

    -- Combine to check if next state is any work state
    u_or_next_work: or4
        port map (
            a => next_is_read_hit,
            b => next_is_write_hit,
            c => next_is_read_miss,
            d => next_is_write_miss,
            y => next_is_work
        );

    ----------------------------------------------------------------
    -- Register busy on falling edge based on next_state
    -- This matches the behavioral implementation exactly!
    ----------------------------------------------------------------
    u_busy_reg: dff_fall
        port map (
            clk   => clk,
            reset => reset,
            d     => next_is_work,
            q     => busy_int
        );

    busy <= busy_int;

    ----------------------------------------------------------------
    -- done = we're in DONE state (one cycle after work finishes)
    ----------------------------------------------------------------
    done <= is_done;

    ----------------------------------------------------------------
    -- counter >= 1 (used for OE_CD timing in READ_HIT)
    ----------------------------------------------------------------
    u_cnt_gte_1: gte_one
        port map (
            a   => counter,
            gte => cnt_gte_1
        );

    ----------------------------------------------------------------
    -- Build "counter == 1" (used for EN / OE_MA timing in MISS paths)
    -- counter == "00001"
    ----------------------------------------------------------------
    cnt0 <= counter(0);
    cnt1 <= counter(1);
    cnt2 <= counter(2);
    cnt3 <= counter(3);
    cnt4 <= counter(4);

    u_inv1: inv port map (a => cnt1, y => cnt1_n);
    u_inv2: inv port map (a => cnt2, y => cnt2_n);
    u_inv3: inv port map (a => cnt3, y => cnt3_n);
    u_inv4: inv port map (a => cnt4, y => cnt4_n);

    -- upper_zero = (~cnt1)&(~cnt2)&(~cnt3)&(~cnt4)
    u_and_upper: and4
        port map (
            a => cnt1_n,
            b => cnt2_n,
            c => cnt3_n,
            d => cnt4_n,
            y => upper_zero
        );

    -- cnt_is_1 = cnt0 & upper_zero
    u_and_cnt1: and2
        port map (
            a => cnt0,
            b => upper_zero,
            y => cnt_is_1
        );

    ----------------------------------------------------------------
    -- OE_CD: asserted in READ_HIT when counter >= 1
    ----------------------------------------------------------------
    u_and_oe_cd: and2
        port map (
            a => is_read_hit,
            b => cnt_gte_1,
            y => read_hit_oe_cd
        );

    OE_CD <= read_hit_oe_cd;

    ----------------------------------------------------------------
    -- EN and OE_MA:
    -- In READ_MISS or WRITE_MISS, assert EN and OE_MA when counter == 1
    ----------------------------------------------------------------
    u_and_rm_en: and2
        port map (
            a => is_read_miss,
            b => cnt_is_1,
            y => read_miss_en
        );

    u_and_wm_en: and2
        port map (
            a => is_write_miss,
            b => cnt_is_1,
            y => write_miss_en
        );

    u_or_en: or2
        port map (
            a => read_miss_en,
            b => write_miss_en,
            y => en
        );

    u_and_rm_oe: and2
        port map (
            a => is_read_miss,
            b => cnt_is_1,
            y => read_miss_oe_ma
        );

    u_and_wm_oe: and2
        port map (
            a => is_write_miss,
            b => cnt_is_1,
            y => write_miss_oe_ma
        );

    u_or_oe_ma: or2
        port map (
            a => read_miss_oe_ma,
            b => write_miss_oe_ma,
            y => OE_MA
        );

end Structural;
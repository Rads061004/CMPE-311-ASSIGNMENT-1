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
    -- Component Declarations
    ----------------------------------------------------------------
    component dff_rise
        port (clk : in STD_LOGIC; reset : in STD_LOGIC; d : in STD_LOGIC; q : out STD_LOGIC);
    end component;

    component and2  port (a, b : in STD_LOGIC; y : out STD_LOGIC); end component;
    component and4  port (a, b, c, d : in STD_LOGIC; y : out STD_LOGIC); end component;
    component or2   port (a, b : in STD_LOGIC; y : out STD_LOGIC); end component;
    component or4   port (a, b, c, d : in STD_LOGIC; y : out STD_LOGIC); end component;
    component inv   port (a : in STD_LOGIC; y : out STD_LOGIC); end component;
    component eq3   port (a, b : in STD_LOGIC_VECTOR(2 downto 0); eq : out STD_LOGIC); end component;
    component gte_one port (a : in STD_LOGIC_VECTOR(4 downto 0); gte : out STD_LOGIC); end component;

    ----------------------------------------------------------------
    -- Signal Declarations
    ----------------------------------------------------------------
    signal S_IDLE, S_READ_HIT, S_WRITE_HIT, S_READ_MISS, S_WRITE_MISS, S_DONE : STD_LOGIC_VECTOR(2 downto 0);
    signal is_idle, is_read_hit, is_write_hit, is_read_miss, is_write_miss, is_done : STD_LOGIC;
    signal nx_idle, nx_read_hit, nx_write_hit, nx_read_miss, nx_write_miss, nx_done : STD_LOGIC;

    signal work_next, busy_set, busy_clr, busy_clr_n, busy_hold, busy_d, busy_q : STD_LOGIC;
    signal cnt_gte_1, cnt_eq_1 : STD_LOGIC;
    signal cnt0, cnt1, cnt2, cnt3, cnt4, cnt1_n, cnt2_n, cnt3_n, cnt4_n, upper_zero : STD_LOGIC;
    signal read_hit_oe_cd, rm_en, wm_en, rm_oe, wm_oe : STD_LOGIC;

begin
    ----------------------------------------------------------------
    -- State Encoding
    ----------------------------------------------------------------
    S_IDLE       <= "000";
    S_READ_HIT   <= "001";
    S_WRITE_HIT  <= "010";
    S_READ_MISS  <= "011";
    S_WRITE_MISS <= "100";
    S_DONE       <= "101";

    ----------------------------------------------------------------
    -- Decode Current State
    ----------------------------------------------------------------
    u_eq_idle : eq3 port map (a => state, b => S_IDLE, eq => is_idle);
    u_eq_rh   : eq3 port map (a => state, b => S_READ_HIT, eq => is_read_hit);
    u_eq_wh   : eq3 port map (a => state, b => S_WRITE_HIT, eq => is_write_hit);
    u_eq_rm   : eq3 port map (a => state, b => S_READ_MISS, eq => is_read_miss);
    u_eq_wm   : eq3 port map (a => state, b => S_WRITE_MISS, eq => is_write_miss);
    u_eq_done : eq3 port map (a => state, b => S_DONE, eq => is_done);

    ----------------------------------------------------------------
    -- Decode Next State
    ----------------------------------------------------------------
    u_nx_idle : eq3 port map (a => next_state, b => S_IDLE, eq => nx_idle);
    u_nx_rh   : eq3 port map (a => next_state, b => S_READ_HIT, eq => nx_read_hit);
    u_nx_wh   : eq3 port map (a => next_state, b => S_WRITE_HIT, eq => nx_write_hit);
    u_nx_rm   : eq3 port map (a => next_state, b => S_READ_MISS, eq => nx_read_miss);
    u_nx_wm   : eq3 port map (a => next_state, b => S_WRITE_MISS, eq => nx_write_miss);
    u_nx_done : eq3 port map (a => next_state, b => S_DONE, eq => nx_done);

    ----------------------------------------------------------------
    -- Busy Logic (corrected to match desired waveform)
    ----------------------------------------------------------------
    -- Work next = any active working state
    u_work_next : or4 port map (a => nx_read_hit, b => nx_write_hit, c => nx_read_miss, d => nx_write_miss, y => work_next);
    -- Set busy when entering work (from IDLE)
    u_busy_set  : and2 port map (a => is_idle, b => work_next, y => busy_set);
    -- Clear busy when next state is DONE or IDLE
    u_busy_clr  : or2 port map (a => nx_done, b => nx_idle, y => busy_clr);
    u_busy_clr_n: inv port map (a => busy_clr, y => busy_clr_n);
    -- Hold if not clearing
    u_busy_hold : and2 port map (a => busy_q, b => busy_clr_n, y => busy_hold);
    -- Next busy = hold OR set
    u_busy_d    : or2 port map (a => busy_hold, b => busy_set, y => busy_d);

    -- ✅ Rising-edge flip-flop for busy (FSM is falling-edge based)
    u_busy_ff   : dff_rise port map (clk => clk, reset => reset, d => busy_d, q => busy_q);
    busy <= busy_q;

    ----------------------------------------------------------------
    -- Done = high in DONE state
    ----------------------------------------------------------------
    done <= is_done;

    ----------------------------------------------------------------
    -- Counter Helpers
    ----------------------------------------------------------------
    u_gte1 : gte_one port map (a => counter, gte => cnt_gte_1);

    cnt0 <= counter(0); cnt1 <= counter(1); cnt2 <= counter(2); cnt3 <= counter(3); cnt4 <= counter(4);
    u_i1 : inv port map (a => cnt1, y => cnt1_n);
    u_i2 : inv port map (a => cnt2, y => cnt2_n);
    u_i3 : inv port map (a => cnt3, y => cnt3_n);
    u_i4 : inv port map (a => cnt4, y => cnt4_n);
    u_and_up : and4 port map (a => cnt1_n, b => cnt2_n, c => cnt3_n, d => cnt4_n, y => upper_zero);
    u_eq1 : and2 port map (a => cnt0, b => upper_zero, y => cnt_eq_1);

    ----------------------------------------------------------------
    -- OE and EN Logic
    ----------------------------------------------------------------
    u_oe_cd : and2 port map (a => is_read_hit, b => cnt_gte_1, y => read_hit_oe_cd);
    OE_CD <= read_hit_oe_cd;

    u_rm_en : and2 port map (a => is_read_miss,  b => cnt_eq_1, y => rm_en);
    u_wm_en : and2 port map (a => is_write_miss, b => cnt_eq_1, y => wm_en);
    u_en    : or2  port map (a => rm_en, b => wm_en, y => en);

    u_rm_oe : and2 port map (a => is_read_miss,  b => cnt_eq_1, y => rm_oe);
    u_wm_oe : and2 port map (a => is_write_miss, b => cnt_eq_1, y => wm_oe);
    u_oe_ma : or2  port map (a => rm_oe, b => wm_oe, y => OE_MA);

end Structural;





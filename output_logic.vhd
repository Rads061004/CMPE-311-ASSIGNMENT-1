library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity output_logic is
    Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;  -- Added reset input
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
    component dff_fall
        port (clk : in STD_LOGIC; reset : in STD_LOGIC; d : in STD_LOGIC; q : out STD_LOGIC);
    end component;
    
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
    
    -- State constants as signals (VHDL-87 compatibility)
    signal S_IDLE       : STD_LOGIC_VECTOR(2 downto 0);
    signal S_READ_HIT   : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_HIT  : STD_LOGIC_VECTOR(2 downto 0);
    signal S_READ_MISS  : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_MISS : STD_LOGIC_VECTOR(2 downto 0);
    signal S_DONE       : STD_LOGIC_VECTOR(2 downto 0);
    
    signal is_read_hit, is_write_hit, is_read_miss, is_write_miss, is_done, is_idle : STD_LOGIC;
    signal is_next_read_hit, is_next_write_hit, is_next_read_miss, is_next_write_miss : STD_LOGIC;
    signal is_next_done, is_next_idle : STD_LOGIC;
    signal is_work_next : STD_LOGIC;
    signal busy_d, busy_q : STD_LOGIC;
    signal cnt_gte_1 : STD_LOGIC;
    signal read_hit_oe_cd : STD_LOGIC;
    signal read_miss_en, read_miss_oe_ma : STD_LOGIC;
    signal write_miss_en, write_miss_oe_ma : STD_LOGIC;
    signal cnt_is_1 : STD_LOGIC;
    signal cnt0, cnt1, cnt2, cnt3, cnt4 : STD_LOGIC;
    signal upper_zero : STD_LOGIC;
    signal cnt1_n, cnt2_n, cnt3_n, cnt4_n : STD_LOGIC;
    
begin
    
    -- Assign state constant values
    S_IDLE       <= "000";
    S_READ_HIT   <= "001";
    S_WRITE_HIT  <= "010";
    S_READ_MISS  <= "011";
    S_WRITE_MISS <= "100";
    S_DONE       <= "101";
    
    -- Decode current state
    u_eq_read_hit: eq3 port map (a => state, b => S_READ_HIT, eq => is_read_hit);
    u_eq_write_hit: eq3 port map (a => state, b => S_WRITE_HIT, eq => is_write_hit);
    u_eq_read_miss: eq3 port map (a => state, b => S_READ_MISS, eq => is_read_miss);
    u_eq_write_miss: eq3 port map (a => state, b => S_WRITE_MISS, eq => is_write_miss);
    u_eq_done: eq3 port map (a => state, b => S_DONE, eq => is_done);
    u_eq_idle: eq3 port map (a => state, b => S_IDLE, eq => is_idle);
    
    -- Decode next state
    u_eq_next_rh: eq3 port map (a => next_state, b => S_READ_HIT, eq => is_next_read_hit);
    u_eq_next_wh: eq3 port map (a => next_state, b => S_WRITE_HIT, eq => is_next_write_hit);
    u_eq_next_rm: eq3 port map (a => next_state, b => S_READ_MISS, eq => is_next_read_miss);
    u_eq_next_wm: eq3 port map (a => next_state, b => S_WRITE_MISS, eq => is_next_write_miss);
    u_eq_next_done: eq3 port map (a => next_state, b => S_DONE, eq => is_next_done);
    u_eq_next_idle: eq3 port map (a => next_state, b => S_IDLE, eq => is_next_idle);
    
    -- Busy logic: assert if transitioning to work state, deassert if transitioning to DONE or IDLE
    u_or_work_next: or4 port map (
        a => is_next_read_hit,
        b => is_next_write_hit,
        c => is_next_read_miss,
        d => is_next_write_miss,
        y => is_work_next
    );
    
    -- busy_d = is_work_next (set if going to work state)
    busy_d <= is_work_next;
    
    -- Busy register (falling edge)
    u_busy_dff: dff_fall port map (
        clk => clk,
        reset => reset,  -- Connect to actual reset signal!
        d => busy_d,
        q => busy_q
    );
    
    busy <= busy_q;
    
    -- Done output: high when in DONE state
    done <= is_done;
    
    -- Counter >= 1 comparison
    u_cnt_gte_1: gte_one port map (a => counter, gte => cnt_gte_1);
    
    -- Check if counter == 1 (for en and OE_MA timing)
    cnt0 <= counter(0);
    cnt1 <= counter(1);
    cnt2 <= counter(2);
    cnt3 <= counter(3);
    cnt4 <= counter(4);
    
    -- upper_zero = NOT(cnt4 OR cnt3 OR cnt2 OR cnt1)
    u_inv1: inv port map (a => cnt1, y => cnt1_n);
    u_inv2: inv port map (a => cnt2, y => cnt2_n);
    u_inv3: inv port map (a => cnt3, y => cnt3_n);
    u_inv4: inv port map (a => cnt4, y => cnt4_n);
    u_and_upper: and4 port map (a => cnt1_n, b => cnt2_n, c => cnt3_n, d => cnt4_n, y => upper_zero);
    u_and_cnt1: and2 port map (a => cnt0, b => upper_zero, y => cnt_is_1);
    
    -- OE_CD: asserted in READ_HIT when counter >= 1
    u_and_oe_cd: and2 port map (a => is_read_hit, b => cnt_gte_1, y => read_hit_oe_cd);
    OE_CD <= read_hit_oe_cd;
    
    -- EN and OE_MA: asserted in READ_MISS or WRITE_MISS when counter == 1
    u_and_rm_en: and2 port map (a => is_read_miss, b => cnt_is_1, y => read_miss_en);
    u_and_wm_en: and2 port map (a => is_write_miss, b => cnt_is_1, y => write_miss_en);
    u_or_en: or2 port map (a => read_miss_en, b => write_miss_en, y => en);
    
    u_and_rm_oe: and2 port map (a => is_read_miss, b => cnt_is_1, y => read_miss_oe_ma);
    u_and_wm_oe: and2 port map (a => is_write_miss, b => cnt_is_1, y => write_miss_oe_ma);
    u_or_oe_ma: or2 port map (a => read_miss_oe_ma, b => write_miss_oe_ma, y => OE_MA);
    
end Structural;
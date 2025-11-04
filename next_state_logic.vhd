library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity next_state_logic is
    Port (
        start      : in  STD_LOGIC;
        tag        : in  STD_LOGIC;
        valid      : in  STD_LOGIC;
        read_write : in  STD_LOGIC;
        state      : in  STD_LOGIC_VECTOR(2 downto 0);
        counter    : in  STD_LOGIC_VECTOR(4 downto 0);
        next_state : out STD_LOGIC_VECTOR(2 downto 0)
    );
end next_state_logic;

architecture Structural of next_state_logic is
    component and2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;

    component and3
        port (a, b, c : in STD_LOGIC; y : out STD_LOGIC);
    end component;

    component and4
        port (a, b, c, d : in STD_LOGIC; y : out STD_LOGIC);
    end component;

    component or2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;

    component or3
        port (a, b, c : in STD_LOGIC; y : out STD_LOGIC);
    end component;

    component or4
        port (a, b, c, d : in STD_LOGIC; y : out STD_LOGIC);
    end component;

    component inv
        port (a : in STD_LOGIC; y : out STD_LOGIC);
    end component;

    component eq3
        port (a, b : in STD_LOGIC_VECTOR(2 downto 0); eq : out STD_LOGIC);
    end component;

    component gte_zero
        port (a : in STD_LOGIC_VECTOR(4 downto 0); gte : out STD_LOGIC);
    end component;

    component gte_one
        port (a : in STD_LOGIC_VECTOR(4 downto 0); gte : out STD_LOGIC);
    end component;

    component gte_seventeen
        port (a : in STD_LOGIC_VECTOR(4 downto 0); gte : out STD_LOGIC);
    end component;

    component mux8to1
        port (
            d   : in  STD_LOGIC_VECTOR(7 downto 0);
            sel : in  STD_LOGIC_VECTOR(2 downto 0);
            y   : out STD_LOGIC
        );
    end component;

    signal S_IDLE        : STD_LOGIC_VECTOR(2 downto 0);
    signal S_READ_HIT    : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_HIT   : STD_LOGIC_VECTOR(2 downto 0);
    signal S_READ_MISS   : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_MISS  : STD_LOGIC_VECTOR(2 downto 0);
    signal S_DONE        : STD_LOGIC_VECTOR(2 downto 0);

    signal is_idle        : STD_LOGIC;
    signal is_read_hit    : STD_LOGIC;
    signal is_write_hit   : STD_LOGIC;
    signal is_read_miss   : STD_LOGIC;
    signal is_write_miss  : STD_LOGIC;
    signal is_done        : STD_LOGIC;

    signal hit            : STD_LOGIC;
    signal hit_n          : STD_LOGIC;
    signal rw_n           : STD_LOGIC;

    signal start_and_hit        : STD_LOGIC;
    signal start_and_miss       : STD_LOGIC;

    signal start_read_hit_pulse    : STD_LOGIC;
    signal start_write_hit_pulse   : STD_LOGIC;
    signal start_read_miss_pulse   : STD_LOGIC;
    signal start_write_miss_pulse  : STD_LOGIC;

    signal idle_next_b0   : STD_LOGIC;
    signal idle_next_b1   : STD_LOGIC;
    signal idle_next_b2   : STD_LOGIC;

    signal next_from_idle_b0 : STD_LOGIC;
    signal next_from_idle_b1 : STD_LOGIC;
    signal next_from_idle_b2 : STD_LOGIC;

    signal cnt_gte_0      : STD_LOGIC;
    signal cnt_gte_1      : STD_LOGIC;
    signal cnt_gte_17     : STD_LOGIC;

    signal c0, c1, c2, c3, c4        : STD_LOGIC;
    signal c1_n, c2_n, c3_n, c4_n    : STD_LOGIC;
    signal upper_zero                : STD_LOGIC;
    signal cnt_eq_1                  : STD_LOGIC;

    signal read_hit_done      : STD_LOGIC;
    signal write_hit_done     : STD_LOGIC;
    signal read_miss_done     : STD_LOGIC;
    signal write_miss_done    : STD_LOGIC;

    signal read_hit_done_n    : STD_LOGIC;
    signal write_hit_done_n   : STD_LOGIC;
    signal read_miss_done_n   : STD_LOGIC;
    signal write_miss_done_n  : STD_LOGIC;

    signal rh_next_b0     : STD_LOGIC;
    signal rh_next_b1     : STD_LOGIC;
    signal rh_next_b2     : STD_LOGIC;

    signal wh_next_b0     : STD_LOGIC;
    signal wh_next_b1     : STD_LOGIC;
    signal wh_next_b2     : STD_LOGIC;

    signal rm_next_b0     : STD_LOGIC;
    signal rm_next_b1     : STD_LOGIC;
    signal rm_next_b2     : STD_LOGIC;

    signal wm_next_b0     : STD_LOGIC;
    signal wm_next_b1     : STD_LOGIC;
    signal wm_next_b2     : STD_LOGIC;

    signal dn_next_b0     : STD_LOGIC;
    signal dn_next_b1     : STD_LOGIC;
    signal dn_next_b2     : STD_LOGIC;

    signal mux_inputs_b0  : STD_LOGIC_VECTOR(7 downto 0);
    signal mux_inputs_b1  : STD_LOGIC_VECTOR(7 downto 0);
    signal mux_inputs_b2  : STD_LOGIC_VECTOR(7 downto 0);

    signal gnd            : STD_LOGIC;
    signal vdd            : STD_LOGIC;

begin
    gnd <= '0';
    vdd <= '1';

    -- state encoding
    S_IDLE        <= "000";
    S_READ_HIT    <= "001";
    S_WRITE_HIT   <= "010";
    S_READ_MISS   <= "011";
    S_WRITE_MISS  <= "100";
    S_DONE        <= "101";

    -- check current state
    u_eq_idle       : eq3 port map (a => state, b => S_IDLE,        eq => is_idle);
    u_eq_read_hit   : eq3 port map (a => state, b => S_READ_HIT,    eq => is_read_hit);
    u_eq_write_hit  : eq3 port map (a => state, b => S_WRITE_HIT,   eq => is_write_hit);
    u_eq_read_miss  : eq3 port map (a => state, b => S_READ_MISS,   eq => is_read_miss);
    u_eq_write_miss : eq3 port map (a => state, b => S_WRITE_MISS,  eq => is_write_miss);
    u_eq_done       : eq3 port map (a => state, b => S_DONE,        eq => is_done);

    -- hit and miss detection
    u_hit_and : and2 port map (a => tag,  b => valid, y => hit);
    u_hit_inv : inv  port map (a => hit,  y => hit_n);

    u_rw_inv  : inv  port map (a => read_write, y => rw_n);

    -- start control signals
    u_sah : and2 port map (a => start, b => hit,    y => start_and_hit);
    u_sam : and2 port map (a => start, b => hit_n,  y => start_and_miss);

    u_srh_and3 : and3 port map (a => start_and_hit,    b => read_write, c => vdd, y => start_read_hit_pulse);

    u_swh_and3 : and3 port map (a => start_and_hit,    b => rw_n,       c => vdd, y => start_write_hit_pulse);

    u_srm_and3 : and3 port map (a => start_and_miss,   b => read_write, c => vdd, y => start_read_miss_pulse);

    u_swm_and3 : and3 port map (a => start_and_miss,   b => rw_n,       c => vdd, y => start_write_miss_pulse);

    u_idle_b0_or : or2 port map (
        a => start_read_hit_pulse,
        b => start_read_miss_pulse,
        y => idle_next_b0
    );

    u_idle_b1_or : or2 port map (
        a => start_write_hit_pulse,
        b => start_read_miss_pulse,
        y => idle_next_b1
    );

    idle_next_b2 <= start_write_miss_pulse;

    next_from_idle_b0 <= idle_next_b0;
    next_from_idle_b1 <= idle_next_b1;
    next_from_idle_b2 <= idle_next_b2;

    -- counter comparison logic
    u_cnt_ge0  : gte_zero      port map (a => counter, gte => cnt_gte_0);
    u_cnt_ge1  : gte_one       port map (a => counter, gte => cnt_gte_1);
    u_cnt_ge17 : gte_seventeen port map (a => counter, gte => cnt_gte_17);

    c0 <= counter(0);
    c1 <= counter(1);
    c2 <= counter(2);
    c3 <= counter(3);
    c4 <= counter(4);

    u_inv1: inv port map (a => c1, y => c1_n);
    u_inv2: inv port map (a => c2, y => c2_n);
    u_inv3: inv port map (a => c3, y => c3_n);
    u_inv4: inv port map (a => c4, y => c4_n);

    u_and_upper: and4 port map (
        a => c1_n,
        b => c2_n,
        c => c3_n,
        d => c4_n,
        y => upper_zero
    );

    u_and_cnt1: and2 port map (
        a => c0,
        b => upper_zero,
        y => cnt_eq_1
    );

    u_rh_done_and : and2 port map (
        a => is_read_hit,
        b => cnt_gte_0,      
        y => read_hit_done
    );

    u_wh_done_and : and2 port map (
        a => is_write_hit,
        b => cnt_eq_1,      
        y => write_hit_done
    );

    u_rm_done_and : and2 port map (
        a => is_read_miss,
        b => cnt_gte_17,     
        y => read_miss_done
    );

    u_wm_done_and : and2 port map (
        a => is_write_miss,
        b => cnt_eq_1,      
        y => write_miss_done
    );

    u_rh_done_inv : inv port map (a => read_hit_done,    y => read_hit_done_n);
    u_wh_done_inv : inv port map (a => write_hit_done,   y => write_hit_done_n);
    u_rm_done_inv : inv port map (a => read_miss_done,   y => read_miss_done_n);
    u_wm_done_inv : inv port map (a => write_miss_done,  y => write_miss_done_n);

    rh_next_b0 <= vdd;
    rh_next_b1 <= gnd;
    rh_next_b2 <= read_hit_done;

    wh_next_b0 <= write_hit_done;
    wh_next_b1 <= write_hit_done_n;
    wh_next_b2 <= write_hit_done;

    rm_next_b0 <= vdd;
    rm_next_b1 <= read_miss_done_n;
    rm_next_b2 <= read_miss_done;

    wm_next_b0 <= write_miss_done;
    wm_next_b1 <= gnd;
    wm_next_b2 <= vdd;

    dn_next_b0 <= gnd;
    dn_next_b1 <= gnd;
    dn_next_b2 <= gnd;

    mux_inputs_b0(0) <= next_from_idle_b0;
    mux_inputs_b0(1) <= rh_next_b0;
    mux_inputs_b0(2) <= wh_next_b0;
    mux_inputs_b0(3) <= rm_next_b0;
    mux_inputs_b0(4) <= wm_next_b0;
    mux_inputs_b0(5) <= dn_next_b0;
    mux_inputs_b0(6) <= gnd;
    mux_inputs_b0(7) <= gnd;

    -- bit1
    mux_inputs_b1(0) <= next_from_idle_b1;
    mux_inputs_b1(1) <= rh_next_b1;
    mux_inputs_b1(2) <= wh_next_b1;
    mux_inputs_b1(3) <= rm_next_b1;
    mux_inputs_b1(4) <= wm_next_b1;
    mux_inputs_b1(5) <= dn_next_b1;
    mux_inputs_b1(6) <= gnd;
    mux_inputs_b1(7) <= gnd;

    mux_inputs_b2(0) <= next_from_idle_b2;
    mux_inputs_b2(1) <= rh_next_b2;
    mux_inputs_b2(2) <= wh_next_b2;
    mux_inputs_b2(3) <= rm_next_b2;
    mux_inputs_b2(4) <= wm_next_b2;
    mux_inputs_b2(5) <= dn_next_b2;
    mux_inputs_b2(6) <= gnd;
    mux_inputs_b2(7) <= gnd;

    u_mux_b0 : mux8to1
        port map (
            d   => mux_inputs_b0,
            sel => state,
            y   => next_state(0)
        );

    u_mux_b1 : mux8to1
        port map (
            d   => mux_inputs_b1,
            sel => state,
            y   => next_state(1)
        );

    u_mux_b2 : mux8to1
        port map (
            d   => mux_inputs_b2,
            sel => state,
            y   => next_state(2)
        );

end Structural;

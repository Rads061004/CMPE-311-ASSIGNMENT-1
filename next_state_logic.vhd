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
    --------------------------------------------------------------------------
    -- Component declarations (all of these exist elsewhere in your project)
    --------------------------------------------------------------------------
    component and2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;

    component and3
        port (a, b, c : in STD_LOGIC; y : out STD_LOGIC);
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

    --------------------------------------------------------------------------
    -- State encodings as signals (so we can feed eq3)
    --------------------------------------------------------------------------
    signal S_IDLE        : STD_LOGIC_VECTOR(2 downto 0);
    signal S_READ_HIT    : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_HIT   : STD_LOGIC_VECTOR(2 downto 0);
    signal S_READ_MISS   : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_MISS  : STD_LOGIC_VECTOR(2 downto 0);
    signal S_DONE        : STD_LOGIC_VECTOR(2 downto 0);

    --------------------------------------------------------------------------
    -- State decode (what state are we currently in?)
    --------------------------------------------------------------------------
    signal is_idle        : STD_LOGIC;
    signal is_read_hit    : STD_LOGIC;
    signal is_write_hit   : STD_LOGIC;
    signal is_read_miss   : STD_LOGIC;
    signal is_write_miss  : STD_LOGIC;
    signal is_done        : STD_LOGIC;

    --------------------------------------------------------------------------
    -- Hit / miss / read / write classification for IDLE launch
    --------------------------------------------------------------------------
    signal hit            : STD_LOGIC;
    signal hit_n          : STD_LOGIC;
    signal rw_n           : STD_LOGIC;  -- NOT read_write

    signal start_and_hit        : STD_LOGIC;
    signal start_and_miss       : STD_LOGIC;

    signal start_read_hit_pulse    : STD_LOGIC;
    signal start_write_hit_pulse   : STD_LOGIC;
    signal start_read_miss_pulse   : STD_LOGIC;
    signal start_write_miss_pulse  : STD_LOGIC;

    --------------------------------------------------------------------------
    -- Next-state bits when we're *currently in IDLE*
    -- (These build 001 / 010 / 011 / 100 correctly)
    --------------------------------------------------------------------------
    signal idle_next_b0   : STD_LOGIC;
    signal idle_next_b1   : STD_LOGIC;
    signal idle_next_b2   : STD_LOGIC;

    signal next_from_idle_b0 : STD_LOGIC;
    signal next_from_idle_b1 : STD_LOGIC;
    signal next_from_idle_b2 : STD_LOGIC;

    --------------------------------------------------------------------------
    -- Counter-based done detection for work states
    --------------------------------------------------------------------------
    signal cnt_gte_0      : STD_LOGIC;
    signal cnt_gte_1      : STD_LOGIC;
    signal cnt_gte_17     : STD_LOGIC;

    signal read_hit_done      : STD_LOGIC;
    signal write_hit_done     : STD_LOGIC;
    signal read_miss_done     : STD_LOGIC;
    signal write_miss_done    : STD_LOGIC;

    signal read_hit_done_n    : STD_LOGIC;
    signal write_hit_done_n   : STD_LOGIC;
    signal read_miss_done_n   : STD_LOGIC;
    signal write_miss_done_n  : STD_LOGIC;

    --------------------------------------------------------------------------
    -- Next-state bits when we're in each non-IDLE state
    -- Each of these implements:
    --   stay in same state vs go to DONE ("101")
    -- using single-driver logic.
    --------------------------------------------------------------------------
    -- READ_HIT ("001") or DONE ("101")
    signal rh_next_b0     : STD_LOGIC;
    signal rh_next_b1     : STD_LOGIC;
    signal rh_next_b2     : STD_LOGIC;

    -- WRITE_HIT ("010") or DONE ("101")
    signal wh_next_b0     : STD_LOGIC;
    signal wh_next_b1     : STD_LOGIC;
    signal wh_next_b2     : STD_LOGIC;

    -- READ_MISS ("011") or DONE ("101")
    signal rm_next_b0     : STD_LOGIC;
    signal rm_next_b1     : STD_LOGIC;
    signal rm_next_b2     : STD_LOGIC;

    -- WRITE_MISS ("100") or DONE ("101")
    signal wm_next_b0     : STD_LOGIC;
    signal wm_next_b1     : STD_LOGIC;
    signal wm_next_b2     : STD_LOGIC;

    -- DONE ("101") -> IDLE ("000")
    signal dn_next_b0     : STD_LOGIC;
    signal dn_next_b1     : STD_LOGIC;
    signal dn_next_b2     : STD_LOGIC;

    --------------------------------------------------------------------------
    -- Mux inputs per bit for final next_state selection
    -- index 0..5 correspond to encodings:
    -- 0: IDLE         ("000")
    -- 1: READ_HIT     ("001")
    -- 2: WRITE_HIT    ("010")
    -- 3: READ_MISS    ("011")
    -- 4: WRITE_MISS   ("100")
    -- 5: DONE         ("101")
    -- 6,7: unused -> "000"
    --------------------------------------------------------------------------
    signal mux_inputs_b0  : STD_LOGIC_VECTOR(7 downto 0);
    signal mux_inputs_b1  : STD_LOGIC_VECTOR(7 downto 0);
    signal mux_inputs_b2  : STD_LOGIC_VECTOR(7 downto 0);

    signal gnd            : STD_LOGIC;
    signal vdd            : STD_LOGIC;

begin
    --------------------------------------------------------------------------
    -- Constant wires
    --------------------------------------------------------------------------
    gnd <= '0';
    vdd <= '1';

    --------------------------------------------------------------------------
    -- State encodings (must match everywhere else in design)
    --------------------------------------------------------------------------
    S_IDLE        <= "000";
    S_READ_HIT    <= "001";
    S_WRITE_HIT   <= "010";
    S_READ_MISS   <= "011";
    S_WRITE_MISS  <= "100";
    S_DONE        <= "101";

    --------------------------------------------------------------------------
    -- Decode the current state
    --------------------------------------------------------------------------
    u_eq_idle       : eq3 port map (a => state, b => S_IDLE,        eq => is_idle);
    u_eq_read_hit   : eq3 port map (a => state, b => S_READ_HIT,    eq => is_read_hit);
    u_eq_write_hit  : eq3 port map (a => state, b => S_WRITE_HIT,   eq => is_write_hit);
    u_eq_read_miss  : eq3 port map (a => state, b => S_READ_MISS,   eq => is_read_miss);
    u_eq_write_miss : eq3 port map (a => state, b => S_WRITE_MISS,  eq => is_write_miss);
    u_eq_done       : eq3 port map (a => state, b => S_DONE,        eq => is_done);

    --------------------------------------------------------------------------
    -- Classify request at the moment we leave IDLE
    -- hit = tag AND valid
    --------------------------------------------------------------------------
    u_hit_and : and2 port map (a => tag, b => valid, y => hit);
    u_hit_inv : inv  port map (a => hit, y => hit_n);

    u_rw_inv  : inv  port map (a => read_write, y => rw_n);

    -- start_and_hit  = start AND hit
    u_sah : and2 port map (a => start, b => hit,    y => start_and_hit);
    -- start_and_miss = start AND (NOT hit)
    u_sam : and2 port map (a => start, b => hit_n,  y => start_and_miss);

    -- start_read_hit_pulse    = start & hit  & read
    u_srh_and3 : and3 port map (a => start_and_hit, b => read_write, c => vdd, y => start_read_hit_pulse);

    -- start_write_hit_pulse   = start & hit  & write
    u_swh_and3 : and3 port map (a => start_and_hit, b => rw_n,       c => vdd, y => start_write_hit_pulse);

    -- start_read_miss_pulse   = start & miss & read
    u_srm_and3 : and3 port map (a => start_and_miss, b => read_write, c => vdd, y => start_read_miss_pulse);

    -- start_write_miss_pulse  = start & miss & write
    u_swm_and3 : and3 port map (a => start_and_miss, b => rw_n,       c => vdd, y => start_write_miss_pulse);

    --------------------------------------------------------------------------
    -- Correct IDLE -> next state encoding
    --
    -- Encodings:
    --   READ_HIT    "001"
    --   WRITE_HIT   "010"
    --   READ_MISS   "011"
    --   WRITE_MISS  "100"
    --
    -- Bit0 (LSB): 1 for READ_HIT, READ_MISS
    -- Bit1:       1 for WRITE_HIT, READ_MISS
    -- Bit2:       1 for WRITE_MISS
    --------------------------------------------------------------------------
    -- idle_next_b0 = start_read_hit_pulse OR start_read_miss_pulse
    u_idle_b0_or : or2 port map (
        a => start_read_hit_pulse,
        b => start_read_miss_pulse,
        y => idle_next_b0
    );

    -- idle_next_b1 = start_write_hit_pulse OR start_read_miss_pulse
    u_idle_b1_or : or2 port map (
        a => start_write_hit_pulse,
        b => start_read_miss_pulse,
        y => idle_next_b1
    );

    -- idle_next_b2 = start_write_miss_pulse
    idle_next_b2 <= start_write_miss_pulse;

    -- Tie them off as "next_from_idle_*"
    next_from_idle_b0 <= idle_next_b0;
    next_from_idle_b1 <= idle_next_b1;
    next_from_idle_b2 <= idle_next_b2;

    --------------------------------------------------------------------------
    -- Counter thresholds to decide when to leave work states
    --------------------------------------------------------------------------
    u_cnt_ge0  : gte_zero      port map (a => counter, gte => cnt_gte_0);
    u_cnt_ge1  : gte_one       port map (a => counter, gte => cnt_gte_1);
    u_cnt_ge17 : gte_seventeen port map (a => counter, gte => cnt_gte_17);

    -- done conditions for each work state
    u_rh_done_and : and2 port map (a => is_read_hit,   b => cnt_gte_0,  y => read_hit_done);
    u_wh_done_and : and2 port map (a => is_write_hit,  b => cnt_gte_1,  y => write_hit_done);
    u_rm_done_and : and2 port map (a => is_read_miss,  b => cnt_gte_17, y => read_miss_done);
    u_wm_done_and : and2 port map (a => is_write_miss, b => cnt_gte_1,  y => write_miss_done);

    u_rh_done_inv : inv port map (a => read_hit_done,    y => read_hit_done_n);
    u_wh_done_inv : inv port map (a => write_hit_done,   y => write_hit_done_n);
    u_rm_done_inv : inv port map (a => read_miss_done,   y => read_miss_done_n);
    u_wm_done_inv : inv port map (a => write_miss_done,  y => write_miss_done_n);

    --------------------------------------------------------------------------
    -- NEXT STATE WHEN CURRENT STATE = READ_HIT ("001")
    -- stay in READ_HIT until read_hit_done=1, then go DONE ("101")
    --
    -- READ_HIT -> "001"
    -- DONE     -> "101"
    --
    -- b0 = 1 in BOTH cases => always '1'
    -- b1 = 0 in BOTH cases => always '0'
    -- b2 = 0 in READ_HIT, 1 in DONE => = read_hit_done
    --------------------------------------------------------------------------
    rh_next_b0 <= vdd;                -- '1'
    rh_next_b1 <= gnd;                -- '0'
    rh_next_b2 <= read_hit_done;      -- go high when we're finished

    --------------------------------------------------------------------------
    -- NEXT STATE WHEN CURRENT STATE = WRITE_HIT ("010")
    -- stay in WRITE_HIT until write_hit_done=1, then go DONE ("101")
    --
    -- WRITE_HIT -> "010" = b2=0 b1=1 b0=0
    -- DONE      -> "101" = b2=1 b1=0 b0=1
    --
    -- b0 = write_hit_done
    -- b1 = NOT write_hit_done
    -- b2 = write_hit_done
    --------------------------------------------------------------------------
    wh_next_b0 <= write_hit_done;
    wh_next_b1 <= write_hit_done_n;
    wh_next_b2 <= write_hit_done;

    --------------------------------------------------------------------------
    -- NEXT STATE WHEN CURRENT STATE = READ_MISS ("011")
    -- stay in READ_MISS until read_miss_done=1, then go DONE ("101")
    --
    -- READ_MISS -> "011" = b2=0 b1=1 b0=1
    -- DONE      -> "101" = b2=1 b1=0 b0=1
    --
    -- b0 = 1 in BOTH cases => '1'
    -- b1 = NOT read_miss_done
    -- b2 = read_miss_done
    --------------------------------------------------------------------------
    rm_next_b0 <= vdd;                -- '1'
    rm_next_b1 <= read_miss_done_n;
    rm_next_b2 <= read_miss_done;

    --------------------------------------------------------------------------
    -- NEXT STATE WHEN CURRENT STATE = WRITE_MISS ("100")
    -- stay in WRITE_MISS until write_miss_done=1, then go DONE ("101")
    --
    -- WRITE_MISS -> "100" = b2=1 b1=0 b0=0
    -- DONE       -> "101" = b2=1 b1=0 b0=1
    --
    -- b0 = write_miss_done
    -- b1 = 0 always
    -- b2 = 1 always
    --------------------------------------------------------------------------
    wm_next_b0 <= write_miss_done;
    wm_next_b1 <= gnd;
    wm_next_b2 <= vdd;

    --------------------------------------------------------------------------
    -- NEXT STATE WHEN CURRENT STATE = DONE ("101")
    -- DONE always returns to IDLE ("000")
    --------------------------------------------------------------------------
    dn_next_b0 <= gnd;
    dn_next_b1 <= gnd;
    dn_next_b2 <= gnd;

    --------------------------------------------------------------------------
    -- Build mux inputs for each bit of next_state
    -- Order indices by state encoding value:
    --   0 -> IDLE        ("000")
    --   1 -> READ_HIT    ("001")
    --   2 -> WRITE_HIT   ("010")
    --   3 -> READ_MISS   ("011")
    --   4 -> WRITE_MISS  ("100")
    --   5 -> DONE        ("101")
    --   6 -> unused -> "000"
    --   7 -> unused -> "000"
    --
    -- For each current state code (state is sel),
    -- pick the *next state's* bit.
    --------------------------------------------------------------------------

    -- Bit0 (LSB)
    mux_inputs_b0(0) <= next_from_idle_b0;  -- IDLE
    mux_inputs_b0(1) <= rh_next_b0;         -- READ_HIT
    mux_inputs_b0(2) <= wh_next_b0;         -- WRITE_HIT
    mux_inputs_b0(3) <= rm_next_b0;         -- READ_MISS
    mux_inputs_b0(4) <= wm_next_b0;         -- WRITE_MISS
    mux_inputs_b0(5) <= dn_next_b0;         -- DONE
    mux_inputs_b0(6) <= gnd;
    mux_inputs_b0(7) <= gnd;

    -- Bit1
    mux_inputs_b1(0) <= next_from_idle_b1;
    mux_inputs_b1(1) <= rh_next_b1;
    mux_inputs_b1(2) <= wh_next_b1;
    mux_inputs_b1(3) <= rm_next_b1;
    mux_inputs_b1(4) <= wm_next_b1;
    mux_inputs_b1(5) <= dn_next_b1;
    mux_inputs_b1(6) <= gnd;
    mux_inputs_b1(7) <= gnd;

    -- Bit2 (MSB)
    mux_inputs_b2(0) <= next_from_idle_b2;
    mux_inputs_b2(1) <= rh_next_b2;
    mux_inputs_b2(2) <= wh_next_b2;
    mux_inputs_b2(3) <= rm_next_b2;
    mux_inputs_b2(4) <= wm_next_b2;
    mux_inputs_b2(5) <= dn_next_b2;
    mux_inputs_b2(6) <= gnd;
    mux_inputs_b2(7) <= gnd;

    --------------------------------------------------------------------------
    -- Final mux: choose next_state bits based on *current* state
    --------------------------------------------------------------------------
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

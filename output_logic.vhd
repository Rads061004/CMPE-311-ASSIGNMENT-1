library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity output_logic is
    port (
        clk         : in  STD_LOGIC;                      -- kept for interface consistency
        reset       : in  STD_LOGIC;
        state       : in  STD_LOGIC_VECTOR(2 downto 0);   -- current FSM state
        next_state  : in  STD_LOGIC_VECTOR(2 downto 0);   -- next FSM state
        counter     : in  STD_LOGIC_VECTOR(4 downto 0);   -- cycle counter (not re-used here)
        busy        : out STD_LOGIC;
        done        : out STD_LOGIC;
        en          : out STD_LOGIC;                      -- mem_en to backing memory
        OE_CD       : out STD_LOGIC;                      -- drive cpu_data bus?
        OE_MA       : out STD_LOGIC                       -- drive mem addr / mem_en outward?
    );
end output_logic;

architecture Structural of output_logic is

    --------------------------------------------------------------------
    -- Component declarations for gate-level style logic
    --------------------------------------------------------------------
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

    --------------------------------------------------------------------
    -- State encodings (as signals so we can feed them into eq3 blocks)
    --------------------------------------------------------------------
    signal S_IDLE        : STD_LOGIC_VECTOR(2 downto 0);
    signal S_READ_HIT    : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_HIT   : STD_LOGIC_VECTOR(2 downto 0);
    signal S_READ_MISS   : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_MISS  : STD_LOGIC_VECTOR(2 downto 0);
    signal S_DONE        : STD_LOGIC_VECTOR(2 downto 0);

    --------------------------------------------------------------------
    -- State decode (is_current_state_X)
    --------------------------------------------------------------------
    signal st_idle        : STD_LOGIC;
    signal st_read_hit    : STD_LOGIC;
    signal st_write_hit   : STD_LOGIC;
    signal st_read_miss   : STD_LOGIC;
    signal st_write_miss  : STD_LOGIC;
    signal st_done        : STD_LOGIC;

    -- next_state == DONE?
    signal nxt_done       : STD_LOGIC;

    --------------------------------------------------------------------
    -- Busy logic helpers
    --------------------------------------------------------------------
    signal active_any     : STD_LOGIC;  -- we're in any active service state (RH/WH/RM/WM)

    --------------------------------------------------------------------
    -- Memory enable logic helpers
    --------------------------------------------------------------------
    signal miss_state     : STD_LOGIC;  -- we're in READ_MISS or WRITE_MISS

    --------------------------------------------------------------------
    -- OE_CD (drive CPU data bus) helpers
    --------------------------------------------------------------------
    signal st_read_any            : STD_LOGIC;  -- READ_HIT or READ_MISS
    signal finishing_read         : STD_LOGIC;  -- about to finish a READ transaction

begin
    --------------------------------------------------------------------
    -- Encode the constant state values that eq3 will compare against.
    -- (Matches your next_state_logic encoding.)
    --------------------------------------------------------------------
    S_IDLE        <= "000";
    S_READ_HIT    <= "001";
    S_WRITE_HIT   <= "010";
    S_READ_MISS   <= "011";
    S_WRITE_MISS  <= "100";
    S_DONE        <= "101";

    --------------------------------------------------------------------
    -- Decode current state using eq3 comparators
    --------------------------------------------------------------------
    u_eq_idle  : eq3 port map (a => state, b => S_IDLE,        eq => st_idle);
    u_eq_rh    : eq3 port map (a => state, b => S_READ_HIT,    eq => st_read_hit);
    u_eq_wh    : eq3 port map (a => state, b => S_WRITE_HIT,   eq => st_write_hit);
    u_eq_rm    : eq3 port map (a => state, b => S_READ_MISS,   eq => st_read_miss);
    u_eq_wm    : eq3 port map (a => state, b => S_WRITE_MISS,  eq => st_write_miss);
    u_eq_done  : eq3 port map (a => state, b => S_DONE,        eq => st_done);

    -- Look ahead at next_state to see if we're about to enter DONE.
    u_eq_nxt_done : eq3 port map (a => next_state, b => S_DONE, eq => nxt_done);

    --------------------------------------------------------------------
    -- Busy behavior
    --
    -- Spec summary:
    --   busy = '1' during:
    --     READ_HIT, WRITE_HIT, READ_MISS, WRITE_MISS
    --   busy = '0' during:
    --     IDLE, DONE
    --
    -- So "active_any" = OR of those four service states.
    -- Then busy just = active_any.
    --------------------------------------------------------------------
    u_active_any : or4
        port map (
            a => st_read_hit,
            b => st_write_hit,
            c => st_read_miss,
            d => st_write_miss,
            y => active_any
        );

    busy <= active_any;

    --------------------------------------------------------------------
    -- done output
    --
    -- Spec summary:
    --   done = '1' when FSM is in DONE
    --------------------------------------------------------------------
    done <= st_done;

    --------------------------------------------------------------------
    -- Memory enable / address enable:
    --
    -- Backing memory is only touched during MISS states:
    --   READ_MISS or WRITE_MISS
    --
    -- We'll expose that as both:
    --   en    (mem_en up to the chip top / external memory)
    --   OE_MA (permission to drive mem address / enable lines)
    --------------------------------------------------------------------
    u_miss_or : or2
        port map (
            a => st_read_miss,
            b => st_write_miss,
            y => miss_state
        );

    en    <= miss_state;
    OE_MA <= miss_state;

    --------------------------------------------------------------------
    -- OE_CD (drive data back to CPU)
    --
    -- Goal: The CPU sees a valid byte on cpu_data when a READ finishes.
    -- In the project waveforms, this happens right as BUSY drops.
    --
    -- We assert OE_CD only at the *completion* of a READ transaction,
    -- not for writes.
    --
    -- We consider a transaction "finishing a read" if:
    --   - current state is READ_HIT or READ_MISS
    --   - next_state is DONE (nxt_done = '1')
    --
    -- That means: data is ready to go back to CPU, bus should be driven.
    --------------------------------------------------------------------
    u_rh_rm_or : or2
        port map (
            a => st_read_hit,
            b => st_read_miss,
            y => st_read_any
        );

    u_finishing_read : and2
        port map (
            a => st_read_any,
            b => nxt_done,
            y => finishing_read
        );

    OE_CD <= finishing_read;

    --------------------------------------------------------------------
    -- NOTE:
    -- We intentionally did NOT assert OE_CD after writes, because the
    -- CPU was the driver for write operations (cpu_rd_wrn='0'), so the
    -- cache should not fight that bus afterward.
    --
    -- Also note: We did not end up using "counter" directly in this
    -- block. The next_state_logic already encodes when an operation
    -- is about to transition to DONE, so we can rely on that instead
    -- of recomputing timing here.
    --------------------------------------------------------------------

end Structural;

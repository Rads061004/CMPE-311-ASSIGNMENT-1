library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity counter_logic is
    Port (
        clk     : in  STD_LOGIC;
        reset   : in  STD_LOGIC;
        state   : in  STD_LOGIC_VECTOR(2 downto 0);
        counter : out STD_LOGIC_VECTOR(4 downto 0)
    );
end counter_logic;

architecture Structural of counter_logic is

    --------------------------------------------------------------------
    -- Component declarations
    -- These should already exist elsewhere in your project,
    -- we're just declaring them so we can instantiate them.
    --------------------------------------------------------------------

    -- Rising-edge DFF with async reset (1 bit)
    component dff_rise
        port (
            clk   : in STD_LOGIC;
            reset : in STD_LOGIC;
            d     : in STD_LOGIC;
            q     : out STD_LOGIC
        );
    end component;

    -- Falling-edge DFF with async reset (1 bit)
    component dff_fall
        port (
            clk   : in STD_LOGIC;
            reset : in STD_LOGIC;
            d     : in STD_LOGIC;
            q     : out STD_LOGIC
        );
    end component;

    -- 2:1 mux for single bit
    component mux2to1
        port (
            d0  : in STD_LOGIC;
            d1  : in STD_LOGIC;
            sel : in STD_LOGIC;
            y   : out STD_LOGIC
        );
    end component;

    -- Equality comparator for 3-bit vectors
    component eq3
        port (
            a   : in STD_LOGIC_VECTOR(2 downto 0);
            b   : in STD_LOGIC_VECTOR(2 downto 0);
            eq  : out STD_LOGIC
        );
    end component;

    -- 2-input AND
    component and2
        port (
            a : in STD_LOGIC;
            b : in STD_LOGIC;
            y : out STD_LOGIC
        );
    end component;

    -- 4-input OR
    component or4
        port (
            a : in STD_LOGIC;
            b : in STD_LOGIC;
            c : in STD_LOGIC;
            d : in STD_LOGIC;
            y : out STD_LOGIC
        );
    end component;

    -- 5-bit incrementer (a + 1)
    component inc5
        port (
            a   : in  STD_LOGIC_VECTOR(4 downto 0);
            inc : out STD_LOGIC_VECTOR(4 downto 0)
        );
    end component;

    --------------------------------------------------------------------
    -- Small structural sub-blocks we rely on:
    --
    -- reg3_rise  : 3-bit register, rising-edge, async reset
    -- reg5_fall  : 5-bit register, falling-edge, async reset, with enable
    --
    -- These are declared here so we can instantiate them.
    -- You should implement them as discussed:
    --   reg3_rise uses dff_rise internally.
    --   reg5_fall uses dff_fall + mux2to1 for enable.
    --------------------------------------------------------------------

    component reg3_rise
        port (
            clk   : in  STD_LOGIC;
            reset : in  STD_LOGIC;
            d     : in  STD_LOGIC_VECTOR(2 downto 0);
            q     : out STD_LOGIC_VECTOR(2 downto 0)
        );
    end component;

    component reg5_fall
        port (
            clk   : in  STD_LOGIC;
            reset : in  STD_LOGIC;
            en    : in  STD_LOGIC;
            d     : in  STD_LOGIC_VECTOR(4 downto 0);
            q     : out STD_LOGIC_VECTOR(4 downto 0)
        );
    end component;

    --------------------------------------------------------------------
    -- Internal signals
    --------------------------------------------------------------------

    -- Encoded state values (tied as signals for VHDL-87 style)
    signal S_READ_HIT    : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_HIT   : STD_LOGIC_VECTOR(2 downto 0);
    signal S_READ_MISS   : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_MISS  : STD_LOGIC_VECTOR(2 downto 0);

    -- Registered previous state (sampled on rising edge)
    signal prev_state    : STD_LOGIC_VECTOR(2 downto 0);

    -- Are we still in the same state as last cycle?
    signal state_same    : STD_LOGIC;

    -- Decode of "work" states (the ones that should run for N cycles)
    signal is_read_hit    : STD_LOGIC;
    signal is_write_hit   : STD_LOGIC;
    signal is_read_miss   : STD_LOGIC;
    signal is_write_miss  : STD_LOGIC;
    signal is_work_state  : STD_LOGIC;

    -- Control: should we increment the counter this cycle?
    signal should_inc     : STD_LOGIC;

    -- The actual cycle counter
    signal cnt            : STD_LOGIC_VECTOR(4 downto 0);
    signal cnt_inc        : STD_LOGIC_VECTOR(4 downto 0);
    signal cnt_next       : STD_LOGIC_VECTOR(4 downto 0);

    -- Constant wires
    signal zero5          : STD_LOGIC_VECTOR(4 downto 0);
    signal en_high        : STD_LOGIC;

begin
    --------------------------------------------------------------------
    -- Tie off constants / encodings
    --------------------------------------------------------------------
    S_READ_HIT   <= "001";
    S_WRITE_HIT  <= "010";
    S_READ_MISS  <= "011";
    S_WRITE_MISS <= "100";

    zero5   <= "00000";
    en_high <= '1';

    --------------------------------------------------------------------
    -- prev_state register
    --
    -- IMPORTANT:
    --   prev_state tracks state on the RISING edge.
    --
    -- That means at the falling edge where we FIRST enter a new state
    -- (ex: IDLE -> WRITE_HIT), state has already changed, but prev_state
    -- is still the old state. So state_same = 0 on that first falling edge.
    --
    -- That lets us detect "new state just started" and reset the counter.
    --------------------------------------------------------------------
    u_prev_state_reg : reg3_rise
        port map (
            clk   => clk,
            reset => reset,
            d     => state,
            q     => prev_state
        );

    --------------------------------------------------------------------
    -- Compare current FSM state vs prev_state
    -- state_same = '1' means we're still in the same state as last time.
    --------------------------------------------------------------------
    u_state_eq : eq3
        port map (
            a  => state,
            b  => prev_state,
            eq => state_same
        );

    --------------------------------------------------------------------
    -- Decode which "work" state we're in
    -- Only these states count cycles.
    --------------------------------------------------------------------
    u_is_read_hit : eq3
        port map (
            a  => state,
            b  => S_READ_HIT,
            eq => is_read_hit
        );

    u_is_write_hit : eq3
        port map (
            a  => state,
            b  => S_WRITE_HIT,
            eq => is_write_hit
        );

    u_is_read_miss : eq3
        port map (
            a  => state,
            b  => S_READ_MISS,
            eq => is_read_miss
        );

    u_is_write_miss : eq3
        port map (
            a  => state,
            b  => S_WRITE_MISS,
            eq => is_write_miss
        );

    -- is_work_state = READ_HIT or WRITE_HIT or READ_MISS or WRITE_MISS
    u_or_work : or4
        port map (
            a => is_read_hit,
            b => is_write_hit,
            c => is_read_miss,
            d => is_write_miss,
            y => is_work_state
        );

    --------------------------------------------------------------------
    -- should_inc = 1 if:
    --   - we're still in the SAME work state (state_same=1)
    --   - and that state is one of the work states
    --
    -- should_inc = 0 on the VERY FIRST falling edge we enter a work state,
    -- so counter will be forced to 00000 instead of incrementing.
    --------------------------------------------------------------------
    u_inc_en : and2
        port map (
            a => state_same,
            b => is_work_state,
            y => should_inc
        );

    --------------------------------------------------------------------
    -- Incrementer: cnt_inc = cnt + 1
    --------------------------------------------------------------------
    u_inc5 : inc5
        port map (
            a   => cnt,
            inc => cnt_inc
        );

    --------------------------------------------------------------------
    -- Build cnt_next bit-by-bit using mux2to1 cells:
    --
    -- If should_inc=1:
    --      cnt_next = cnt_inc   (keep counting up)
    -- else
    --      cnt_next = "00000"   (new state or not in work -> reset counter)
    --------------------------------------------------------------------
    gen_cnt_mux : for i in 0 to 4 generate
        u_mux_cnt : mux2to1
            port map (
                d0  => zero5(i),
                d1  => cnt_inc(i),
                sel => should_inc,
                y   => cnt_next(i)
            );
    end generate;

    --------------------------------------------------------------------
    -- Counter register
    --
    -- CRITICAL:
    --   This counter must advance on the FALLING edge,
    --   because the FSM state machine, busy, and timing spec
    --   are all defined relative to negative edges.
    --
    -- reg5_fall:
    --   - uses dff_fall internally
    --   - has async reset
    --   - has an enable (we tie en='1' because we already mux cnt_next)
    --------------------------------------------------------------------
    u_cnt_reg : reg5_fall
        port map (
            clk   => clk,
            reset => reset,
            en    => en_high,
            d     => cnt_next,
            q     => cnt
        );

    --------------------------------------------------------------------
    -- Drive output
    --------------------------------------------------------------------
    counter <= cnt;

end Structural;

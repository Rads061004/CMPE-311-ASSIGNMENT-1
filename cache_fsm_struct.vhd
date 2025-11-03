library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity cache_fsm_struct is
    Port (
        clk            : in  STD_LOGIC;
        reset          : in  STD_LOGIC;

        start          : in  STD_LOGIC;    -- CPU request strobe
        tag            : in  STD_LOGIC;    -- tag match boolean for indexed line
        valid          : in  STD_LOGIC;    -- valid bit for indexed line
        read_write     : in  STD_LOGIC;    -- '1' = read, '0' = write

        busy           : out STD_LOGIC;    -- asserted while servicing
        en             : out STD_LOGIC;    -- memory enable (miss traffic)
        fsm_resp_pulse : out STD_LOGIC;    -- "CPU should get read data now"

        -- debug taps
        state_dbg      : out STD_LOGIC_VECTOR(2 downto 0);
        next_state_dbg : out STD_LOGIC_VECTOR(2 downto 0);
        counter_dbg    : out STD_LOGIC_VECTOR(4 downto 0)
    );
end cache_fsm_struct;

architecture Structural of cache_fsm_struct is

    --------------------------------------------------------------------
    -- Sub-block declarations
    --------------------------------------------------------------------
    component next_state_logic
        Port (
            start      : in  STD_LOGIC;
            tag        : in  STD_LOGIC;
            valid      : in  STD_LOGIC;
            read_write : in  STD_LOGIC;
            state      : in  STD_LOGIC_VECTOR(2 downto 0);
            counter    : in  STD_LOGIC_VECTOR(4 downto 0);
            next_state : out STD_LOGIC_VECTOR(2 downto 0)
        );
    end component;

    component state_register
        Port (
            clk        : in  STD_LOGIC;
            reset      : in  STD_LOGIC;
            next_state : in  STD_LOGIC_VECTOR(2 downto 0);
            state      : out STD_LOGIC_VECTOR(2 downto 0)
        );
    end component;

    component counter_logic
        Port (
            clk     : in  STD_LOGIC;
            reset   : in  STD_LOGIC;
            state   : in  STD_LOGIC_VECTOR(2 downto 0);
            counter : out STD_LOGIC_VECTOR(4 downto 0)
        );
    end component;

    component output_logic
        Port (
            clk         : in  STD_LOGIC;
            reset       : in  STD_LOGIC;
            state       : in  STD_LOGIC_VECTOR(2 downto 0);
            next_state  : in  STD_LOGIC_VECTOR(2 downto 0);
            counter     : in  STD_LOGIC_VECTOR(4 downto 0);

            busy        : out STD_LOGIC;
            en          : out STD_LOGIC;
            resp_pulse  : out STD_LOGIC
        );
    end component;

    --------------------------------------------------------------------
    -- Internal nets
    --------------------------------------------------------------------
    signal state_sig      : STD_LOGIC_VECTOR(2 downto 0);
    signal next_state_sig : STD_LOGIC_VECTOR(2 downto 0);
    signal counter_sig    : STD_LOGIC_VECTOR(4 downto 0);

    signal busy_int       : STD_LOGIC;
    signal en_int         : STD_LOGIC;
    signal resp_pulse_int : STD_LOGIC;

begin
    ----------------------------------------------------------------
    -- next_state_logic (pure comb)
    ----------------------------------------------------------------
    U1_next_state_logic : next_state_logic
        port map (
            start      => start,
            tag        => tag,
            valid      => valid,
            read_write => read_write,
            state      => state_sig,
            counter    => counter_sig,
            next_state => next_state_sig
        );

    ----------------------------------------------------------------
    -- state_register (sequential state update)
    ----------------------------------------------------------------
    U2_state_register : state_register
        port map (
            clk        => clk,
            reset      => reset,
            next_state => next_state_sig,
            state      => state_sig
        );

    ----------------------------------------------------------------
    -- counter_logic (tracks how long we've been in service states)
    ----------------------------------------------------------------
    U3_counter_logic : counter_logic
        port map (
            clk     => clk,
            reset   => reset,
            state   => state_sig,
            counter => counter_sig
        );

    ----------------------------------------------------------------
    -- output_logic (decodes outputs from current/next state)
    -- Produces:
    --    busy_int        = "busy"
    --    en_int          = "mem_en / refill enable"
    --    resp_pulse_int  = one-cycle pulse to capture read data
    ----------------------------------------------------------------
    U4_output_logic : output_logic
        port map (
            clk         => clk,
            reset       => reset,
            state       => state_sig,
            next_state  => next_state_sig,
            counter     => counter_sig,
            busy        => busy_int,
            en          => en_int,
            resp_pulse  => resp_pulse_int
        );

    ----------------------------------------------------------------
    -- Hook internal nets to top-level outputs
    ----------------------------------------------------------------
    busy           <= busy_int;
    en             <= en_int;
    fsm_resp_pulse <= resp_pulse_int;

    -- export debug
    state_dbg      <= state_sig;
    next_state_dbg <= next_state_sig;
    counter_dbg    <= counter_sig;

end Structural;

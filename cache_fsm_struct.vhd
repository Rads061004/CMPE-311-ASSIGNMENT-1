library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity cache_fsm_struct is
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        start      : in  STD_LOGIC;
        tag        : in  STD_LOGIC;
        valid      : in  STD_LOGIC;
        read_write : in  STD_LOGIC;  -- 1=read, 0=write
        busy       : out STD_LOGIC;
        done       : out STD_LOGIC;
        en         : out STD_LOGIC;
        OE_CD      : out STD_LOGIC;  -- Output Enable for Cache Data
        OE_MA      : out STD_LOGIC   -- Output Enable for Memory Access
    );
end cache_fsm_struct;

architecture Structural of cache_fsm_struct is
    --------------------------------------------------------------------
    -- Component Declarations
    --------------------------------------------------------------------
    component next_state_logic
        Port (
            start_q      : in  STD_LOGIC;               -- sampled on rising edge
            hit_q        : in  STD_LOGIC;               -- (tag and valid), sampled on rising
            read_write_q : in  STD_LOGIC;               -- sampled on rising (1=read)
            state        : in  STD_LOGIC_VECTOR(2 downto 0);
            counter      : in  INTEGER;
            next_state   : out STD_LOGIC_VECTOR(2 downto 0)
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

    component output_logic
        Port (
            clk        : in  STD_LOGIC;  -- not used; kept for interface stability
            state      : in  STD_LOGIC_VECTOR(2 downto 0);
            counter    : in  INTEGER;
            busy       : out STD_LOGIC;
            done       : out STD_LOGIC;
            en         : out STD_LOGIC;
            OE_CD      : out STD_LOGIC;
            OE_MA      : out STD_LOGIC
        );
    end component;

    component counter_logic
        Port (
            clk     : in  STD_LOGIC;
            reset   : in  STD_LOGIC;
            state   : in  STD_LOGIC_VECTOR(2 downto 0);
            counter : out INTEGER
        );
    end component;

    --------------------------------------------------------------------
    -- Internal Signals
    --------------------------------------------------------------------
    signal state_sig, next_state_sig : STD_LOGIC_VECTOR(2 downto 0);
    signal counter_sig               : INTEGER := 0;

    -- Decision inputs sampled together on the same RISING edge
    signal start_q      : STD_LOGIC := '0';
    signal read_write_q : STD_LOGIC := '0';
    signal hit_q        : STD_LOGIC := '0';   -- tag AND valid, sampled

begin
    --------------------------------------------------------------------
    -- Sample CPU request/control on RISING edge (stable by the next NEGEDGE)
    --------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            start_q      <= '0';
            read_write_q <= '0';
            hit_q        <= '0';
        elsif rising_edge(clk) then
            start_q      <= start;
            read_write_q <= read_write;      -- 1=read, 0=write
            hit_q        <= tag and valid;   -- CVT (hit)
        end if;
    end process;

    --------------------------------------------------------------------
    -- Component Instantiations
    --------------------------------------------------------------------
    U1_next_state_logic : next_state_logic
        Port map (
            start_q      => start_q,
            hit_q        => hit_q,
            read_write_q => read_write_q,
            state        => state_sig,
            counter      => counter_sig,
            next_state   => next_state_sig
        );

    U2_state_register : state_register
        Port map (
            clk        => clk,
            reset      => reset,
            next_state => next_state_sig,
            state      => state_sig
        );

    U3_counter_logic : counter_logic
        Port map (
            clk     => clk,
            reset   => reset,
            state   => state_sig,
            counter => counter_sig
        );

    U4_output_logic : output_logic
        Port map (
            clk     => clk,
            state   => state_sig,
            counter => counter_sig,
            busy    => busy,
            done    => done,
            en      => en,
            OE_CD   => OE_CD,
            OE_MA   => OE_MA
        );

end Structural;

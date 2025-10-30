library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity cache_fsm_struct is
    Port (
        clk        : in  STD_LOGIC;
        reset      : in  STD_LOGIC;
        start      : in  STD_LOGIC;
        tag        : in  STD_LOGIC;
        valid      : in  STD_LOGIC;
        read_write : in  STD_LOGIC;   -- 1=read, 0=write
        busy       : out STD_LOGIC;
        done       : out STD_LOGIC;
        en         : out STD_LOGIC;
        OE_CD      : out STD_LOGIC;
        OE_MA      : out STD_LOGIC
    );
end cache_fsm_struct;

architecture Structural of cache_fsm_struct is
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

    component output_logic 
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
    end component;

    component counter_logic 
        Port (
            clk     : in  STD_LOGIC;
            reset   : in  STD_LOGIC;
            state   : in  STD_LOGIC_VECTOR(2 downto 0);
            counter : out STD_LOGIC_VECTOR(4 downto 0)
        );
    end component;

    -- NOTE: no initializers here (single drivers from submodules)
    signal state_sig      : STD_LOGIC_VECTOR(2 downto 0);
    signal next_state_sig : STD_LOGIC_VECTOR(2 downto 0);
    signal counter_sig    : STD_LOGIC_VECTOR(4 downto 0);

begin
    U1_next_state_logic : next_state_logic
        Port map (
            start      => start,
            tag        => tag,
            valid      => valid,
            read_write => read_write,
            state      => state_sig,
            counter    => counter_sig,
            next_state => next_state_sig
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
            clk        => clk,
            reset      => reset,
            state      => state_sig,
            next_state => next_state_sig,
            counter    => counter_sig,
            busy       => busy,
            done       => done,
            en         => en,
            OE_CD      => OE_CD,
            OE_MA      => OE_MA
        );
end Structural;

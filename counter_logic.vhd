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
    component reg5_rise
        port (clk : in STD_LOGIC; reset : in STD_LOGIC; en : in STD_LOGIC; 
              d : in STD_LOGIC_VECTOR(4 downto 0); q : out STD_LOGIC_VECTOR(4 downto 0));
    end component;
    
    component reg3_fall
        port (clk : in STD_LOGIC; reset : in STD_LOGIC; 
              d : in STD_LOGIC_VECTOR(2 downto 0); q : out STD_LOGIC_VECTOR(2 downto 0));
    end component;
    
    component inc5
        port (a : in STD_LOGIC_VECTOR(4 downto 0); inc : out STD_LOGIC_VECTOR(4 downto 0));
    end component;
    
    component eq3
        port (a, b : in STD_LOGIC_VECTOR(2 downto 0); eq : out STD_LOGIC);
    end component;
    
    component mux2to1
        port (d0, d1 : in STD_LOGIC; sel : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    component or4
        port (a, b, c, d : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    component inv
        port (a : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    component and2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    -- State constants as signals (VHDL-87 compatibility)
    signal S_IDLE       : STD_LOGIC_VECTOR(2 downto 0);
    signal S_READ_HIT   : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_HIT  : STD_LOGIC_VECTOR(2 downto 0);
    signal S_READ_MISS  : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_MISS : STD_LOGIC_VECTOR(2 downto 0);
    signal S_DONE       : STD_LOGIC_VECTOR(2 downto 0);
    
    signal prev_state : STD_LOGIC_VECTOR(2 downto 0);
    signal cnt : STD_LOGIC_VECTOR(4 downto 0);
    signal cnt_inc : STD_LOGIC_VECTOR(4 downto 0);
    signal state_same : STD_LOGIC;
    signal is_work_state : STD_LOGIC;
    signal should_inc : STD_LOGIC;
    signal cnt_next : STD_LOGIC_VECTOR(4 downto 0);
    signal zero : STD_LOGIC_VECTOR(4 downto 0);
    
    signal is_read_hit, is_write_hit, is_read_miss, is_write_miss : STD_LOGIC;
    signal s_read_hit_sig, s_write_hit_sig, s_read_miss_sig, s_write_miss_sig : STD_LOGIC_VECTOR(2 downto 0);
    signal en_high : STD_LOGIC;
    
begin
    zero <= "00000";
    en_high <= '1';
    
    -- Assign state constant values
    S_IDLE       <= "000";
    S_READ_HIT   <= "001";
    S_WRITE_HIT  <= "010";
    S_READ_MISS  <= "011";
    S_WRITE_MISS <= "100";
    S_DONE       <= "101";
    
    s_read_hit_sig <= S_READ_HIT;
    s_write_hit_sig <= S_WRITE_HIT;
    s_read_miss_sig <= S_READ_MISS;
    s_write_miss_sig <= S_WRITE_MISS;
    
    -- Store previous state (on falling edge to match original)
    u_prev_state_reg: reg3_fall port map (
        clk => clk,
        reset => reset,
        d => state,
        q => prev_state
    );
    
    -- Check if state is same (not changed)
    u_state_eq: eq3 port map (
        a => state,
        b => prev_state,
        eq => state_same
    );
    
    -- Decode work states
    u_eq_read_hit: eq3 port map (a => state, b => s_read_hit_sig, eq => is_read_hit);
    u_eq_write_hit: eq3 port map (a => state, b => s_write_hit_sig, eq => is_write_hit);
    u_eq_read_miss: eq3 port map (a => state, b => s_read_miss_sig, eq => is_read_miss);
    u_eq_write_miss: eq3 port map (a => state, b => s_write_miss_sig, eq => is_write_miss);
    
    u_or_work: or4 port map (
        a => is_read_hit,
        b => is_write_hit,
        c => is_read_miss,
        d => is_write_miss,
        y => is_work_state
    );
    
    -- Should increment if state hasn't changed AND is work state
    u_and_inc: and2 port map (a => state_same, b => is_work_state, y => should_inc);
    
    -- Increment counter
    u_inc: inc5 port map (a => cnt, inc => cnt_inc);
    
    -- Mux to select next counter value
    -- If state changed OR not work state: load 0, else load incremented
    gen_mux: for i in 0 to 4 generate
        u_mux: mux2to1 port map (
            d0 => zero(i),
            d1 => cnt_inc(i),
            sel => should_inc,
            y => cnt_next(i)
        );
    end generate;
    
    -- Counter register (rising edge)
    u_cnt_reg: reg5_rise port map (
        clk => clk,
        reset => reset,
        en => en_high,  -- Always enabled, mux controls value
        d => cnt_next,
        q => cnt
    );
    
    counter <= cnt;
end Structural;
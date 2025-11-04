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

    component dff_rise
        port (
            clk   : in STD_LOGIC;
            reset : in STD_LOGIC;
            d     : in STD_LOGIC;
            q     : out STD_LOGIC
        );
    end component;

    component dff_fall
        port (
            clk   : in STD_LOGIC;
            reset : in STD_LOGIC;
            d     : in STD_LOGIC;
            q     : out STD_LOGIC
        );
    end component;

    component mux2to1
        port (
            d0  : in STD_LOGIC;
            d1  : in STD_LOGIC;
            sel : in STD_LOGIC;
            y   : out STD_LOGIC
        );
    end component;

    component eq3
        port (
            a   : in STD_LOGIC_VECTOR(2 downto 0);
            b   : in STD_LOGIC_VECTOR(2 downto 0);
            eq  : out STD_LOGIC
        );
    end component;

    component and2
        port (
            a : in STD_LOGIC;
            b : in STD_LOGIC;
            y : out STD_LOGIC
        );
    end component;

    component or4
        port (
            a : in STD_LOGIC;
            b : in STD_LOGIC;
            c : in STD_LOGIC;
            d : in STD_LOGIC;
            y : out STD_LOGIC
        );
    end component;

    component inc5
        port (
            a   : in  STD_LOGIC_VECTOR(4 downto 0);
            inc : out STD_LOGIC_VECTOR(4 downto 0)
        );
    end component;

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

    signal S_READ_HIT    : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_HIT   : STD_LOGIC_VECTOR(2 downto 0);
    signal S_READ_MISS   : STD_LOGIC_VECTOR(2 downto 0);
    signal S_WRITE_MISS  : STD_LOGIC_VECTOR(2 downto 0);

    signal prev_state    : STD_LOGIC_VECTOR(2 downto 0);

    signal state_same    : STD_LOGIC;

    signal is_read_hit    : STD_LOGIC;
    signal is_write_hit   : STD_LOGIC;
    signal is_read_miss   : STD_LOGIC;
    signal is_write_miss  : STD_LOGIC;
    signal is_work_state  : STD_LOGIC;

    signal should_inc     : STD_LOGIC;

    signal cnt            : STD_LOGIC_VECTOR(4 downto 0);
    signal cnt_inc        : STD_LOGIC_VECTOR(4 downto 0);
    signal cnt_next       : STD_LOGIC_VECTOR(4 downto 0);

    signal zero5          : STD_LOGIC_VECTOR(4 downto 0);
    signal en_high        : STD_LOGIC;

begin
    S_READ_HIT   <= "001";
    S_WRITE_HIT  <= "010";
    S_READ_MISS  <= "011";
    S_WRITE_MISS <= "100";

    zero5   <= "00000";
    en_high <= '1';

    -- store previous state
    u_prev_state_reg : reg3_rise
        port map (
            clk   => clk,
            reset => reset,
            d     => state,
            q     => prev_state
        );

    -- check if state is same as previous
    u_state_eq : eq3
        port map (
            a  => state,
            b  => prev_state,
            eq => state_same
        );

    -- check for each working state
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

    u_or_work : or4
        port map (
            a => is_read_hit,
            b => is_write_hit,
            c => is_read_miss,
            d => is_write_miss,
            y => is_work_state
        );

    u_inc_en : and2
        port map (
            a => state_same,
            b => is_work_state,
            y => should_inc
        );

    u_inc5 : inc5
        port map (
            a   => cnt,
            inc => cnt_inc
        );

    -- check for each working state
    gen_cnt_mux : for i in 0 to 4 generate
        u_mux_cnt : mux2to1
            port map (
                d0  => zero5(i),
                d1  => cnt_inc(i),
                sel => should_inc,
                y   => cnt_next(i)
            );
    end generate;

    u_cnt_reg : reg5_fall
        port map (
            clk   => clk,
            reset => reset,
            en    => en_high,
            d     => cnt_next,
            q     => cnt
        );

    -- output current count
    counter <= cnt;

end Structural;

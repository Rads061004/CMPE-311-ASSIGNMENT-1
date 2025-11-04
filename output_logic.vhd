library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity output_logic is
    port (
        clk         : in  STD_LOGIC;                     
        reset       : in  STD_LOGIC;                    

        state       : in  STD_LOGIC_VECTOR(2 downto 0);   -- current FSM state
        next_state  : in  STD_LOGIC_VECTOR(2 downto 0);   -- next FSM state
        counter     : in  STD_LOGIC_VECTOR(4 downto 0);   

        busy        : out STD_LOGIC;                   
        en          : out STD_LOGIC;                      -- assert mem_en for MISS
        resp_pulse  : out STD_LOGIC                    
    );
end output_logic;

architecture Structural of output_logic is

    component inv
        port (a : in STD_LOGIC; y : out STD_LOGIC);
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

    -- Break out CURRENT state bits
    signal s2, s1, s0      : STD_LOGIC;
    signal ns2, ns1, ns0   : STD_LOGIC;  

    -- Break out NEXT state bits
    signal n2s, n1s, n0s   : STD_LOGIC;
    signal nn2s, nn1s, nn0s: STD_LOGIC;  

    signal st_idle        : STD_LOGIC;  
    signal st_read_hit    : STD_LOGIC;  
    signal st_write_hit   : STD_LOGIC;  
    signal st_read_miss   : STD_LOGIC;  
    signal st_write_miss  : STD_LOGIC;  
    signal st_done        : STD_LOGIC;  

 
    -- Decode for NEXT state 
    signal nxt_done       : STD_LOGIC;

    -- helper groups to generate outputs
    signal any_active     : STD_LOGIC;  
    signal miss_active    : STD_LOGIC;  
    signal st_read_any    : STD_LOGIC;  
    signal finishing_read : STD_LOGIC; 

    -- internal wires for 2-level AND constructions
    signal idle_t1        : STD_LOGIC;
    signal rh_t1          : STD_LOGIC;
    signal wh_t1          : STD_LOGIC;
    signal rm_t1          : STD_LOGIC;
    signal wm_t1          : STD_LOGIC;
    signal dn_t1          : STD_LOGIC;

    signal nxtdn_t1       : STD_LOGIC;

begin
    -- Assign and invert current state bits
    s2 <= state(2);
    s1 <= state(1);
    s0 <= state(0);

    U_INV_S2 : inv port map(a => s2, y => ns2);  
    U_INV_S1 : inv port map(a => s1, y => ns1);  
    U_INV_S0 : inv port map(a => s0, y => ns0);  

    -- Assign and invert next_state bits
    n2s <= next_state(2);
    n1s <= next_state(1);
    n0s <= next_state(0);

    U_INV_NS2 : inv port map(a => n2s, y => nn2s);  
    U_INV_NS1 : inv port map(a => n1s, y => nn1s);  
    U_INV_NS0 : inv port map(a => n0s, y => nn0s);  

    -- st_idle 
    U_IDLE_AND_L1 : and2 port map(a => ns2, b => ns1, y => idle_t1);
    U_IDLE_AND_L2 : and2 port map(a => idle_t1, b => ns0, y => st_idle);

    -- st_read_hit 
    U_RH_AND_L1   : and2 port map(a => ns2, b => ns1, y => rh_t1);
    U_RH_AND_L2   : and2 port map(a => rh_t1, b => s0,  y => st_read_hit);

    -- st_write_hit 
    U_WH_AND_L1   : and2 port map(a => ns2, b => s1,  y => wh_t1);
    U_WH_AND_L2   : and2 port map(a => wh_t1, b => ns0, y => st_write_hit);

    -- st_read_miss 
    U_RM_AND_L1   : and2 port map(a => ns2, b => s1,  y => rm_t1);
    U_RM_AND_L2   : and2 port map(a => rm_t1, b => s0,  y => st_read_miss);

    -- st_write_miss 
    U_WM_AND_L1   : and2 port map(a => s2,  b => ns1, y => wm_t1);
    U_WM_AND_L2   : and2 port map(a => wm_t1, b => ns0, y => st_write_miss);

    -- st_done 
    U_DN_AND_L1   : and2 port map(a => s2,  b => ns1, y => dn_t1);
    U_DN_AND_L2   : and2 port map(a => dn_t1, b => s0,  y => st_done);

    U_NXTDN_AND_L1 : and2 port map(a => n2s,   b => nn1s, y => nxtdn_t1);   
    U_NXTDN_AND_L2 : and2 port map(a => nxtdn_t1, b => n0s,  y => nxt_done);

    U_BUSY_OR4 : or4
        port map (
            a => st_read_hit,
            b => st_write_hit,
            c => st_read_miss,
            d => st_write_miss,
            y => any_active
        );
    busy <= any_active;

    U_EN_OR2 : or2
        port map (
            a => st_read_miss,
            b => st_write_miss,
            y => miss_active
        );
    en <= miss_active;

    U_READANY_OR2 : or2
        port map (
            a => st_read_hit,
            b => st_read_miss,
            y => st_read_any
        );

    U_FINISH_AND2 : and2
        port map (
            a => st_read_any,
            b => nxt_done,
            y => finishing_read
        );

    resp_pulse <= finishing_read;

end Structural;

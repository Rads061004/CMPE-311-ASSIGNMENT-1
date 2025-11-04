library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity cache_block is
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;

        enable     : in  std_logic;

        data_in    : in  std_logic_vector(7 downto 0);  
        data_out   : out std_logic_vector(7 downto 0);  
        byte_sel   : in  std_logic_vector(1 downto 0);  
        rd_wr      : in  std_logic;                     

        mem_in     : in  std_logic_vector(7 downto 0);  
        
        we         : in  std_logic;                     
        set_tag    : in  std_logic;                     
        tag_in     : in  std_logic_vector(1 downto 0);  

        valid_out  : out std_logic;
        tag_out    : out std_logic_vector(1 downto 0);
        hit_miss   : out std_logic;

        -- peek interface for reading any byte combinationally
        peek_sel   : in  std_logic_vector(1 downto 0);
        peek_data  : out std_logic_vector(7 downto 0)
    );
end cache_block;

architecture structural of cache_block is

    component decoder
        port (
            block_addr : in  std_logic_vector(1 downto 0);
            block_sel  : out std_logic_vector(3 downto 0)
        );
    end component;

    component mux2to1_8
        port (
            d0  : in  STD_LOGIC_VECTOR(7 downto 0);
            d1  : in  STD_LOGIC_VECTOR(7 downto 0);
            sel : in  STD_LOGIC;
            y   : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    component mux4to1_8
        port (
            d0  : in  STD_LOGIC_VECTOR(7 downto 0);
            d1  : in  STD_LOGIC_VECTOR(7 downto 0);
            d2  : in  STD_LOGIC_VECTOR(7 downto 0);
            d3  : in  STD_LOGIC_VECTOR(7 downto 0);
            sel : in  STD_LOGIC_VECTOR(1 downto 0);
            y   : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    component reg8_rise_en
        port (
            clk   : in  STD_LOGIC;
            reset : in  STD_LOGIC;
            en    : in  STD_LOGIC;
            d     : in  STD_LOGIC_VECTOR(7 downto 0);
            q     : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    component reg2_rise_en
        port (
            clk   : in  STD_LOGIC;
            reset : in  STD_LOGIC;
            en    : in  STD_LOGIC;
            d     : in  STD_LOGIC_VECTOR(1 downto 0);
            q     : out STD_LOGIC_VECTOR(1 downto 0)
        );
    end component;

    component reg1_rise_en
        port (
            clk   : in  STD_LOGIC;
            reset : in  STD_LOGIC;
            en    : in  STD_LOGIC;
            d     : in  STD_LOGIC;
            q     : out STD_LOGIC
        );
    end component;

    component eq2
        port (
            a  : in  STD_LOGIC_VECTOR(1 downto 0);
            b  : in  STD_LOGIC_VECTOR(1 downto 0);
            eq : out STD_LOGIC
        );
    end component;

    component and2
        port (
            a : in STD_LOGIC;
            b : in STD_LOGIC;
            y : out STD_LOGIC
        );
    end component;

    component and3
        port (
            a : in STD_LOGIC;
            b : in STD_LOGIC;
            c : in STD_LOGIC;
            y : out STD_LOGIC
        );
    end component;

    signal byte_dec    : std_logic_vector(3 downto 0);
    signal write_data  : std_logic_vector(7 downto 0);

    signal byte0_q     : std_logic_vector(7 downto 0);
    signal byte1_q     : std_logic_vector(7 downto 0);
    signal byte2_q     : std_logic_vector(7 downto 0);
    signal byte3_q     : std_logic_vector(7 downto 0);

    signal we_global   : std_logic;
    signal we_b0       : std_logic;
    signal we_b1       : std_logic;
    signal we_b2       : std_logic;
    signal we_b3       : std_logic;

    signal read_data   : std_logic_vector(7 downto 0);
    signal dout_q      : std_logic_vector(7 downto 0);
    signal outreg_en   : std_logic;

    signal tag_q       : std_logic_vector(1 downto 0);
    signal valid_q     : std_logic;
    signal tag_en      : std_logic;

    signal tag_match   : std_logic;
    signal hit_sig     : std_logic;
    signal valid_and_enable : std_logic;

    signal one_sig     : std_logic;

begin
    one_sig <= '1';

    u_byte_decoder: decoder
        port map (
            block_addr => byte_sel,
            block_sel  => byte_dec
        );

    u_write_src_mux: mux2to1_8
        port map (
            d0  => data_in,
            d1  => mem_in,
            sel => rd_wr,
            y   => write_data
        );

    u_we_global: and2
        port map (
            a => enable,
            b => we,
            y => we_global
        );

    u_we_b0: and2 port map ( a => we_global, b => byte_dec(0), y => we_b0 );
    u_we_b1: and2 port map ( a => we_global, b => byte_dec(1), y => we_b1 );
    u_we_b2: and2 port map ( a => we_global, b => byte_dec(2), y => we_b2 );
    u_we_b3: and2 port map ( a => we_global, b => byte_dec(3), y => we_b3 );

    u_byte0: reg8_rise_en
        port map (
            clk   => clk,
            reset => reset,
            en    => we_b0,
            d     => write_data,
            q     => byte0_q
        );

    u_byte1: reg8_rise_en
        port map (
            clk   => clk,
            reset => reset,
            en    => we_b1,
            d     => write_data,
            q     => byte1_q
        );

    u_byte2: reg8_rise_en
        port map (
            clk   => clk,
            reset => reset,
            en    => we_b2,
            d     => write_data,
            q     => byte2_q
        );

    u_byte3: reg8_rise_en
        port map (
            clk   => clk,
            reset => reset,
            en    => we_b3,
            d     => write_data,
            q     => byte3_q
        );

    u_read_mux: mux4to1_8
        port map (
            d0  => byte0_q,
            d1  => byte1_q,
            d2  => byte2_q,
            d3  => byte3_q,
            sel => byte_sel,
            y   => read_data
        );

    u_outreg_en: and2
        port map (
            a => enable,
            b => rd_wr,
            y => outreg_en
        );

    u_dout_reg: reg8_rise_en
        port map (
            clk   => clk,
            reset => reset,
            en    => outreg_en,
            d     => read_data,
            q     => dout_q
        );

    data_out <= dout_q;

    u_tag_en: and2
        port map (
            a => enable,
            b => set_tag,
            y => tag_en
        );

    u_tag_reg: reg2_rise_en
        port map (
            clk   => clk,
            reset => reset,
            en    => tag_en,
            d     => tag_in,
            q     => tag_q
        );

    tag_out <= tag_q;

    u_valid_reg: reg1_rise_en
        port map (
            clk   => clk,
            reset => reset,
            en    => tag_en,
            d     => one_sig,   
            q     => valid_q
        );

    valid_out <= valid_q;

    u_tag_cmp: eq2
        port map (
            a  => tag_q,
            b  => tag_in,
            eq => tag_match
        );

    u_valid_and_enable: and2
        port map (
            a => valid_q,
            b => enable,
            y => valid_and_enable
        );

    u_hit_and: and2
        port map (
            a => tag_match,
            b => valid_and_enable,
            y => hit_sig
        );

    hit_miss <= hit_sig;

    -- Peek mux - structural mux to read any byte based on peek_sel
    u_peek_mux: mux4to1_8
        port map (
            d0  => byte0_q,
            d1  => byte1_q,
            d2  => byte2_q,
            d3  => byte3_q,
            sel => peek_sel,
            y   => peek_data
        );


end structural;

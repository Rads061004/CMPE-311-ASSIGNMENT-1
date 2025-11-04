library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity chip is
  port (
    cpu_add    : in    std_logic_vector(5 downto 0);   
    cpu_data   : inout std_logic_vector(7 downto 0);   
    cpu_rd_wrn : in    std_logic;                      
    start      : in    std_logic;                    
    clk        : in    std_logic;
    reset      : in    std_logic;

    mem_data   : in    std_logic_vector(7 downto 0);   
    Vdd        : in    std_logic;                      
    Gnd        : in    std_logic;                

    busy       : out   std_logic;                  
    mem_en     : out   std_logic;                     
    mem_add    : out   std_logic_vector(5 downto 0)
  );
end chip;

architecture structural of chip is

  signal tag_in    : std_logic_vector(1 downto 0);
  signal idx       : std_logic_vector(1 downto 0);
  signal byte_sel  : std_logic_vector(1 downto 0);

  -- Component declarations
  component decoder
    port (
      block_addr : in  std_logic_vector(1 downto 0);
      block_sel  : out std_logic_vector(3 downto 0)
    );
  end component;

  component cache_block
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
      
      peek_sel   : in  std_logic_vector(1 downto 0);
      peek_data  : out std_logic_vector(7 downto 0)
    );
  end component;

  component mux4to1_8
    port (
      d0  : in  std_logic_vector(7 downto 0);
      d1  : in  std_logic_vector(7 downto 0);
      d2  : in  std_logic_vector(7 downto 0);
      d3  : in  std_logic_vector(7 downto 0);
      sel : in  std_logic_vector(1 downto 0);
      y   : out std_logic_vector(7 downto 0)
    );
  end component;

  component mux4to1_1
    port (
      d0  : in  std_logic;
      d1  : in  std_logic;
      d2  : in  std_logic;
      d3  : in  std_logic;
      sel : in  std_logic_vector(1 downto 0);
      y   : out std_logic
    );
  end component;

  component mux2to1
    port (
      d0  : in  std_logic;
      d1  : in  std_logic;
      sel : in  std_logic;
      y   : out std_logic
    );
  end component;

  component eq2
    port (
      a  : in  std_logic_vector(1 downto 0);
      b  : in  std_logic_vector(1 downto 0);
      eq : out std_logic
    );
  end component;

  component and2
    port (
      a : in std_logic;
      b : in std_logic;
      y : out std_logic
    );
  end component;

  component and3
    port (
      a : in std_logic;
      b : in std_logic;
      c : in std_logic;
      y : out std_logic
    );
  end component;

  component or2
    port (
      a : in std_logic;
      b : in std_logic;
      y : out std_logic
    );
  end component;

  component or4
    port (
      a : in std_logic;
      b : in std_logic;
      c : in std_logic;
      d : in std_logic;
      y : out std_logic
    );
  end component;

  component inv
    port (
      a : in std_logic;
      y : out std_logic
    );
  end component;

  component xor2
    port (
      a : in std_logic;
      b : in std_logic;
      y : out std_logic
    );
  end component;

  component xnor2
    port (
      a : in std_logic;
      b : in std_logic;
      y : out std_logic
    );
  end component;

  component dff_fall
    port (
      clk   : in  std_logic;
      reset : in  std_logic;
      d     : in  std_logic;
      q     : out std_logic
    );
  end component;

  component tbuf8
    port (
      d   : in  std_logic_vector(7 downto 0);
      en  : in  std_logic;
      b   : out std_logic_vector(7 downto 0)
    );
  end component;

  component gte5
    port (
      a   : in  std_logic_vector(4 downto 0);
      b   : in  std_logic_vector(4 downto 0);
      gte : out std_logic
    );
  end component;

  component cache_fsm_struct
    port (
      clk            : in  std_logic;
      reset          : in  std_logic;
      start          : in  std_logic;
      tag            : in  std_logic;   
      valid          : in  std_logic;   
      read_write     : in  std_logic;   

      busy           : out std_logic;   
      en             : out std_logic;   
      fsm_resp_pulse : out std_logic
    );
  end component;
    
  -- Interconnect signals
  signal en_1hot : std_logic_vector(3 downto 0);

  signal d0, d1, d2, d3 : std_logic_vector(7 downto 0);
  signal v0, v1, v2, v3 : std_logic;
  signal t0, t1, t2, t3 : std_logic_vector(1 downto 0);
  signal h0, h1, h2, h3 : std_logic;
  signal pk0, pk1, pk2, pk3 : std_logic_vector(7 downto 0);

  signal data_sel        : std_logic_vector(7 downto 0);
  signal valid_sel       : std_logic;
  signal hit_sel         : std_logic;
  signal peek_sel_data   : std_logic_vector(7 downto 0);
  signal curr_byte_sel   : std_logic_vector(1 downto 0);

  signal fsm_resp_pulse  : std_logic;
  signal fsm_en          : std_logic;
  signal busy_int        : std_logic;

  signal latch_go        : std_logic;
  signal L_is_write      : std_logic;
  signal L_is_read       : std_logic;
  signal L_is_hit        : std_logic;
  signal L_is_write_mux_out : std_logic;
  signal L_is_read_mux_out  : std_logic;
  signal L_is_hit_mux_out   : std_logic;

  signal cpu_do          : std_logic_vector(7 downto 0);
  signal cpu_data_oe     : std_logic;
  signal cpu_data_oe_d   : std_logic;

  signal tag_match_sel   : std_logic;

  -- Tag match helpers
  signal idx_eq_00, idx_eq_01, idx_eq_10, idx_eq_11 : std_logic;
  signal tag_eq_0, tag_eq_1, tag_eq_2, tag_eq_3     : std_logic;
  signal match_0, match_1, match_2, match_3         : std_logic;

  signal idx_const_00 : std_logic_vector(1 downto 0);
  signal idx_const_01 : std_logic_vector(1 downto 0);
  signal idx_const_10 : std_logic_vector(1 downto 0);
  signal idx_const_11 : std_logic_vector(1 downto 0);

  -- Refill logic state 
  signal mem_en_q              : std_logic;
  signal mem_en_q_d            : std_logic;
  signal mem_en_q_n            : std_logic;

  signal refill_active         : std_logic;
  signal refill_active_d       : std_logic;

  signal refill_cnt            : std_logic_vector(4 downto 0);
  signal refill_cnt_d          : std_logic_vector(4 downto 0);

  signal refill_offset_reg     : std_logic_vector(1 downto 0);
  signal refill_offset_d       : std_logic_vector(1 downto 0);

  signal start_refill          : std_logic;

  signal c1, c2, c3, c4, c5    : std_logic;
  signal cnt_inc               : std_logic_vector(4 downto 0);
  signal cnt_after_inc         : std_logic_vector(4 downto 0);
  signal cnt_after_zero        : std_logic_vector(4 downto 0);

  signal eq8, eq10, eq12, eq14 : std_logic;
  signal x8, x10, x12, x14     : std_logic_vector(4 downto 0);
  signal eq8_low3,  eq10_low3,  eq12_low3,  eq14_low3  : std_logic;
  signal eq8_high2, eq10_high2, eq12_high2, eq14_high2 : std_logic;

  signal ge16                    : std_logic;
  signal refill_active_and_ge16  : std_logic;
  signal clr_active_pulse        : std_logic;
  signal active_after_clr        : std_logic;

  signal refill_active_and_eq8   : std_logic;
  signal refill_active_and_eq10  : std_logic;
  signal refill_active_and_eq12  : std_logic;
  signal refill_active_and_eq14  : std_logic;

  signal load00_pulse            : std_logic;
  signal load01_pulse            : std_logic;
  signal load10_pulse            : std_logic;
  signal load11_pulse            : std_logic;

  signal load_en01_11            : std_logic;
  signal load_en10_00            : std_logic;
  signal load_en                 : std_logic;

  signal offset_bit0_load        : std_logic;
  signal offset_bit1_load        : std_logic;

  -- Write / tag pulse logic 
  signal we_top              : std_logic;
  signal set_tag_top         : std_logic;
  signal we_top_d            : std_logic;
  signal set_tag_top_d       : std_logic;

  signal write_hit_pulse     : std_logic;
  signal write_hit_pulse_full: std_logic;
  signal refill_write_pulse  : std_logic;
  signal set_tag_pulse       : std_logic;

  signal eq8_or_eq10         : std_logic;
  signal eq12_or_eq14        : std_logic;
  signal any_eq8_14          : std_logic;

  signal cpu_rd_wrn_n        : std_logic;
  signal gnd_sig             : std_logic;

  signal sig_zero            : std_logic;
  signal sig_one             : std_logic;
  signal vec_zero5           : std_logic_vector(4 downto 0);
  signal vec_sixteen         : std_logic_vector(4 downto 0);

begin

  -- Constant drivers
  gnd_sig     <= '0';
  sig_zero    <= '0';
  sig_one     <= '1';
  vec_zero5   <= "00000";
  vec_sixteen <= "10000";

  tag_in   <= cpu_add(5 downto 4);
  idx      <= cpu_add(3 downto 2);
  byte_sel <= cpu_add(1 downto 0);

  idx_const_00 <= "00";
  idx_const_01 <= "01";
  idx_const_10 <= "10";
  idx_const_11 <= "11";

  u_dec: decoder port map (block_addr => idx, block_sel => en_1hot);

  -- Cache block instances
  u_cb0: cache_block 
    port map (
      clk => clk, 
      reset => reset, 
      enable => en_1hot(0), 
      data_in => cpu_data, 
      data_out => d0, 
      byte_sel => curr_byte_sel, 
      rd_wr => cpu_rd_wrn, 
      mem_in => mem_data, 
      we => we_top, 
      set_tag => set_tag_top, 
      tag_in => tag_in, 
      valid_out => v0, 
      tag_out => t0, 
      hit_miss => h0, 
      peek_sel => byte_sel, 
      peek_data => pk0
    );

  u_cb1: cache_block 
    port map (
      clk => clk, 
      reset => reset, 
      enable => en_1hot(1), 
      data_in => cpu_data, 
      data_out => d1, 
      byte_sel => curr_byte_sel, 
      rd_wr => cpu_rd_wrn, 
      mem_in => mem_data, 
      we => we_top, 
      set_tag => set_tag_top, 
      tag_in => tag_in, 
      valid_out => v1, 
      tag_out => t1, 
      hit_miss => h1, 
      peek_sel => byte_sel, 
      peek_data => pk1
    );

  u_cb2: cache_block 
    port map (
      clk => clk, 
      reset => reset, 
      enable => en_1hot(2), 
      data_in => cpu_data, 
      data_out => d2, 
      byte_sel => curr_byte_sel, 
      rd_wr => cpu_rd_wrn, 
      mem_in => mem_data, 
      we => we_top, 
      set_tag => set_tag_top, 
      tag_in => tag_in, 
      valid_out => v2, 
      tag_out => t2, 
      hit_miss => h2, 
      peek_sel => byte_sel, 
      peek_data => pk2
    );

  u_cb3: cache_block 
    port map (
      clk => clk, 
      reset => reset, 
      enable => en_1hot(3), 
      data_in => cpu_data, 
      data_out => d3, 
      byte_sel => curr_byte_sel, 
      rd_wr => cpu_rd_wrn, 
      mem_in => mem_data, 
      we => we_top, 
      set_tag => set_tag_top, 
      tag_in => tag_in, 
      valid_out => v3, 
      tag_out => t3, 
      hit_miss => h3, 
      peek_sel => byte_sel, 
      peek_data => pk3
    );

  -- curr_byte_sel 
  gen_curr_byte_sel: for i in 0 to 1 generate
    u_mux_curr_byte: mux2to1 port map (d0 => byte_sel(i), d1 => refill_offset_reg(i), sel => refill_active, y => curr_byte_sel(i));
  end generate;

  -- Muxes for data, valid, hit, and peek data
  u_mux_data : mux4to1_8 port map (d0 => d0, d1 => d1, d2 => d2, d3 => d3, sel => idx, y => data_sel);
  u_mux_valid : mux4to1_1 port map (d0 => v0, d1 => v1, d2 => v2, d3 => v3, sel => idx, y => valid_sel);
  u_mux_hit : mux4to1_1 port map (d0 => h0, d1 => h1, d2 => h2, d3 => h3, sel => idx, y => hit_sel);
  u_mux_peek : mux4to1_8 port map (d0 => pk0, d1 => pk1, d2 => pk2, d3 => pk3, sel => idx, y => peek_sel_data);

  -- tag_match_sel logic
  u_idx_eq_00: eq2 port map (a => idx, b => idx_const_00, eq => idx_eq_00);
  u_idx_eq_01: eq2 port map (a => idx, b => idx_const_01, eq => idx_eq_01);
  u_idx_eq_10: eq2 port map (a => idx, b => idx_const_10, eq => idx_eq_10);
  u_idx_eq_11: eq2 port map (a => idx, b => idx_const_11, eq => idx_eq_11);

  u_tag_eq_0: eq2 port map (a => t0, b => tag_in, eq => tag_eq_0);
  u_tag_eq_1: eq2 port map (a => t1, b => tag_in, eq => tag_eq_1);
  u_tag_eq_2: eq2 port map (a => t2, b => tag_in, eq => tag_eq_2);
  u_tag_eq_3: eq2 port map (a => t3, b => tag_in, eq => tag_eq_3);

  u_match_0: and2 port map (a => idx_eq_00, b => tag_eq_0, y => match_0);
  u_match_1: and2 port map (a => idx_eq_01, b => tag_eq_1, y => match_1);
  u_match_2: and2 port map (a => idx_eq_10, b => tag_eq_2, y => match_2);
  u_match_3: and2 port map (a => idx_eq_11, b => tag_eq_3, y => match_3);

  u_tag_match_or: or4 port map (a => match_0, b => match_1, c => match_2, d => match_3, y => tag_match_sel);

  -- FSM
  u_fsm: cache_fsm_struct
    port map (
      clk            => clk,
      reset          => reset,
      start          => start,
      tag            => hit_sel,
      valid          => valid_sel,
      read_write     => cpu_rd_wrn,

      busy           => busy_int,
      en             => fsm_en,
      fsm_resp_pulse => fsm_resp_pulse
    );

  busy <= busy_int;

  -- mem_en and mem_add
  mem_en <= fsm_en;

  mem_add(5) <= cpu_add(5);
  mem_add(4) <= cpu_add(4);
  mem_add(3) <= cpu_add(3);
  mem_add(2) <= cpu_add(2);
  mem_add(1) <= gnd_sig;
  mem_add(0) <= gnd_sig;

  -- cpu_data tri-state back to CPU
  cpu_do <= peek_sel_data;

  u_cpu_data_tbuf: tbuf8 port map (d => cpu_do, en => cpu_data_oe, b => cpu_data);

  -- Latch_go register 
  u_latch_go_dff: dff_fall port map (clk => clk, reset => reset, d => start, q => latch_go);

  u_inv_rd_wrn: inv port map (a => cpu_rd_wrn, y => cpu_rd_wrn_n);

  u_mux_L_is_write: mux2to1 port map (d0 => L_is_write, d1 => cpu_rd_wrn_n, sel => start, y => L_is_write_mux_out);
  u_dff_L_is_write: dff_fall port map (clk => clk, reset => reset, d => L_is_write_mux_out, q => L_is_write);

  u_mux_L_is_read: mux2to1 port map (d0 => L_is_read, d1 => cpu_rd_wrn, sel => start, y => L_is_read_mux_out);
  u_dff_L_is_read: dff_fall port map (clk => clk, reset => reset, d => L_is_read_mux_out, q => L_is_read);

  u_mux_L_is_hit: mux2to1 port map (d0 => L_is_hit, d1 => hit_sel, sel => start, y => L_is_hit_mux_out);
  u_dff_L_is_hit: dff_fall port map (clk => clk, reset => reset, d => L_is_hit_mux_out, q => L_is_hit);

  -- cpu_data_oe register
  u_and_cpu_data_oe: and2 port map (a => fsm_resp_pulse, b => L_is_read, y => cpu_data_oe_d);
  u_dff_cpu_data_oe: dff_fall port map (clk => clk, reset => reset, d => cpu_data_oe_d, q => cpu_data_oe);

  -- STRUCTURAL REFILL CONTROL LOGIC 
  mem_en_q_d <= fsm_en;

  u_inv_mem_en_q: inv port map (a => mem_en_q, y => mem_en_q_n);
  u_start_refill_and: and2 port map (a => mem_en_q_n, b => fsm_en, y => start_refill);
    
  u_inv_cnt0: inv port map (a => refill_cnt(0), y => cnt_inc(0));
  c1 <= refill_cnt(0);

  u_xor_cnt1: xor2 port map (a => refill_cnt(1), b => c1, y => cnt_inc(1));
  u_and_cnt1: and2 port map (a => refill_cnt(1), b => c1, y => c2);

  u_xor_cnt2: xor2 port map (a => refill_cnt(2), b => c2, y => cnt_inc(2));
  u_and_cnt2: and2 port map (a => refill_cnt(2), b => c2, y => c3);

  u_xor_cnt3: xor2 port map (a => refill_cnt(3), b => c3, y => cnt_inc(3));
  u_and_cnt3: and2 port map (a => refill_cnt(3), b => c3, y => c4);

  u_xor_cnt4: xor2 port map (a => refill_cnt(4), b => c4, y => cnt_inc(4));
  u_and_cnt4: and2 port map (a => refill_cnt(4), b => c4, y => c5);

  gen_cnt_next: for i in 0 to 4 generate
    u_cnt_inc_mux: mux2to1 port map (d0 => refill_cnt(i), d1 => cnt_inc(i), sel => refill_active, y => cnt_after_inc(i));
    u_cnt_zero_mux: mux2to1 port map (d0 => cnt_after_inc(i), d1 => sig_zero, sel => start_refill, y => cnt_after_zero(i));
  end generate;

  refill_cnt_d <= cnt_after_zero;

  u_xnor8_b0:  xnor2 port map (a => refill_cnt(0), b => sig_zero, y => x8(0));
  u_xnor8_b1:  xnor2 port map (a => refill_cnt(1), b => sig_zero, y => x8(1));
  u_xnor8_b2:  xnor2 port map (a => refill_cnt(2), b => sig_zero, y => x8(2));
  u_xnor8_b3:  xnor2 port map (a => refill_cnt(3), b => sig_one,  y => x8(3));
  u_xnor8_b4:  xnor2 port map (a => refill_cnt(4), b => sig_zero, y => x8(4));
  u_eq8_low3:  and3  port map (a => x8(0), b => x8(1), c => x8(2), y => eq8_low3);
  u_eq8_high2: and2  port map (a => x8(3), b => x8(4), y => eq8_high2);
  u_eq8_and:   and2  port map (a => eq8_low3, b => eq8_high2, y => eq8);

  u_xnor10_b0: xnor2 port map (a => refill_cnt(0), b => sig_zero, y => x10(0));
  u_xnor10_b1: xnor2 port map (a => refill_cnt(1), b => sig_one,  y => x10(1));
  u_xnor10_b2: xnor2 port map (a => refill_cnt(2), b => sig_zero, y => x10(2));
  u_xnor10_b3: xnor2 port map (a => refill_cnt(3), b => sig_one,  y => x10(3));
  u_xnor10_b4: xnor2 port map (a => refill_cnt(4), b => sig_zero, y => x10(4));
  u_eq10_low3: and3  port map (a => x10(0), b => x10(1), c => x10(2), y => eq10_low3);
  u_eq10_high2:and2  port map (a => x10(3), b => x10(4), y => eq10_high2);
  u_eq10_and:  and2  port map (a => eq10_low3, b => eq10_high2, y => eq10);

  u_xnor12_b0: xnor2 port map (a => refill_cnt(0), b => sig_zero, y => x12(0));
  u_xnor12_b1: xnor2 port map (a => refill_cnt(1), b => sig_zero, y => x12(1));
  u_xnor12_b2: xnor2 port map (a => refill_cnt(2), b => sig_one,  y => x12(2));
  u_xnor12_b3: xnor2 port map (a => refill_cnt(3), b => sig_one,  y => x12(3));
  u_xnor12_b4: xnor2 port map (a => refill_cnt(4), b => sig_zero, y => x12(4));
  u_eq12_low3: and3  port map (a => x12(0), b => x12(1), c => x12(2), y => eq12_low3);
  u_eq12_high2:and2  port map (a => x12(3), b => x12(4), y => eq12_high2);
  u_eq12_and:  and2  port map (a => eq12_low3, b => eq12_high2, y => eq12);

  u_xnor14_b0: xnor2 port map (a => refill_cnt(0), b => sig_zero, y => x14(0));
  u_xnor14_b1: xnor2 port map (a => refill_cnt(1), b => sig_one,  y => x14(1));
  u_xnor14_b2: xnor2 port map (a => refill_cnt(2), b => sig_one,  y => x14(2));
  u_xnor14_b3: xnor2 port map (a => refill_cnt(3), b => sig_one,  y => x14(3));
  u_xnor14_b4: xnor2 port map (a => refill_cnt(4), b => sig_zero, y => x14(4));
  u_eq14_low3: and3  port map (a => x14(0), b => x14(1), c => x14(2), y => eq14_low3);
  u_eq14_high2:and2  port map (a => x14(3), b => x14(4), y => eq14_high2);
  u_eq14_and:  and2  port map (a => eq14_low3, b => eq14_high2, y => eq14);

  -- refill_active clear condition
  u_ge16: gte5 port map (a => refill_cnt, b => vec_sixteen, gte => ge16);
  u_and_active_ge16: and2 port map (a => refill_active, b => ge16, y => refill_active_and_ge16);
  clr_active_pulse <= refill_active_and_ge16;

  -- refill_active_d
  u_active_clr_mux: mux2to1 port map (d0 => refill_active, d1 => sig_zero, sel => clr_active_pulse, y => active_after_clr);
  u_active_set_mux: mux2to1 port map (d0 => active_after_clr, d1 => sig_one, sel => start_refill, y => refill_active_d);

  -- refill_offset_reg 
  u_and_eq8:  and2 port map (a => refill_active, b => eq8,  y => refill_active_and_eq8);
  u_and_eq10: and2 port map (a => refill_active, b => eq10, y => refill_active_and_eq10);
  u_and_eq12: and2 port map (a => refill_active, b => eq12, y => refill_active_and_eq12);
  u_and_eq14: and2 port map (a => refill_active, b => eq14, y => refill_active_and_eq14);

  u_or_load00: or2 port map (a => start_refill, b => refill_active_and_eq8, y => load00_pulse);

  load01_pulse <= refill_active_and_eq10;
  load10_pulse <= refill_active_and_eq12;
  load11_pulse <= refill_active_and_eq14;

  u_or01_11: or2 port map (a => load01_pulse, b => load11_pulse, y => load_en01_11);
  u_or10_00: or2 port map (a => load10_pulse, b => load00_pulse, y => load_en10_00);
  u_or_all_en: or2 port map (a => load_en01_11, b => load_en10_00, y => load_en);

  u_or_bit0: or2 port map (a => load01_pulse, b => load11_pulse, y => offset_bit0_load);
  u_or_bit1: or2 port map (a => load10_pulse, b => load11_pulse, y => offset_bit1_load);

  u_offset_bit0_mux: mux2to1 port map (d0 => refill_offset_reg(0), d1 => offset_bit0_load, sel => load_en, y => refill_offset_d(0));
  u_offset_bit1_mux: mux2to1 port map (d0 => refill_offset_reg(1), d1 => offset_bit1_load, sel => load_en, y => refill_offset_d(1));

  -- DFFs for refill state
  u_dff_mem_en_q: dff_fall port map (clk => clk, reset => reset, d => mem_en_q_d, q => mem_en_q);
  u_dff_refill_active: dff_fall port map (clk => clk, reset => reset, d => refill_active_d, q => refill_active);

  gen_refill_cnt_reg: for i in 0 to 4 generate
    u_dff_refill_cnt: dff_fall port map (clk => clk, reset => reset, d => refill_cnt_d(i), q => refill_cnt(i));
  end generate;

  gen_refill_offset_reg: for i in 0 to 1 generate
    u_dff_refill_offset: dff_fall port map (clk => clk, reset => reset, d => refill_offset_d(i), q => refill_offset_reg(i));
  end generate;

  -- STRUCTURAL WRITE / TAG PULSE LOGIC 
  u_write_hit_and0: and2 port map (a => latch_go, b => L_is_write, y => write_hit_pulse);
  u_write_hit_and1: and2 port map (a => write_hit_pulse, b => L_is_hit, y => write_hit_pulse_full);

  u_or_8_10: or2 port map (a => eq8, b => eq10, y => eq8_or_eq10);
  u_or_12_14: or2 port map (a => eq12, b => eq14, y => eq12_or_eq14);
  u_or_8to14: or2 port map (a => eq8_or_eq10, b => eq12_or_eq14, y => any_eq8_14);

  u_and_refill_write: and2 port map (a => refill_active, b => any_eq8_14, y => refill_write_pulse);

  u_or_we_top: or2 port map (a => write_hit_pulse_full, b => refill_write_pulse, y => we_top_d);

  u_and_set_tag: and2 port map (a => refill_active, b => eq8, y => set_tag_pulse);

  set_tag_top_d <= set_tag_pulse;

  u_dff_we_top: dff_fall port map (clk => clk, reset => reset, d => we_top_d, q => we_top);
  u_dff_set_tag_top: dff_fall port map (clk => clk, reset => reset, d => set_tag_top_d, q => set_tag_top);

end structural;

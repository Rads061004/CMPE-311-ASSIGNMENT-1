library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity chip_extra is
  port (
    cpu_add    : in    STD_LOGIC_VECTOR(5 downto 0);
    cpu_data   : inout STD_LOGIC_VECTOR(7 downto 0);
    cpu_rd_wrn : in    STD_LOGIC;  -- '1' = read, '0' = write
    start      : in    STD_LOGIC;
    clk        : in    STD_LOGIC;
    reset      : in    STD_LOGIC;

    mem_data   : in    STD_LOGIC_VECTOR(7 downto 0);

    busy       : out   STD_LOGIC;
    mem_en     : out   STD_LOGIC;
    mem_add    : out   STD_LOGIC_VECTOR(5 downto 0)
  );
end chip_extra;

architecture Structural of chip_extra is

  --------------------------------------------------------------------
  -- COMPONENT DECLARATIONS
  --------------------------------------------------------------------
  component decoder
    port (
      block_addr : in  STD_LOGIC_VECTOR(1 downto 0);
      block_sel  : out STD_LOGIC_VECTOR(3 downto 0)
    );
  end component;

  component cache_block
    port (
      clk        : in  STD_LOGIC;
      reset      : in  STD_LOGIC;
      enable     : in  STD_LOGIC;

      data_in    : in  STD_LOGIC_VECTOR(7 downto 0);
      data_out   : out STD_LOGIC_VECTOR(7 downto 0);
      byte_sel   : in  STD_LOGIC_VECTOR(1 downto 0);
      rd_wr      : in  STD_LOGIC;

      mem_in     : in  STD_LOGIC_VECTOR(7 downto 0);

      we         : in  STD_LOGIC;
      set_tag    : in  STD_LOGIC;
      tag_in     : in  STD_LOGIC_VECTOR(1 downto 0);

      valid_out  : out STD_LOGIC;
      tag_out    : out STD_LOGIC_VECTOR(1 downto 0);
      hit_miss   : out STD_LOGIC;

      peek_sel   : in  STD_LOGIC_VECTOR(1 downto 0);
      peek_data  : out STD_LOGIC_VECTOR(7 downto 0)
    );
  end component;

  component mux4to1_8
    port (
      d0, d1, d2, d3 : in  STD_LOGIC_VECTOR(7 downto 0);
      sel            : in  STD_LOGIC_VECTOR(1 downto 0);
      y              : out STD_LOGIC_VECTOR(7 downto 0)
    );
  end component;

  component mux4to1_1
    port (
      d0, d1, d2, d3 : in  STD_LOGIC;
      sel            : in  STD_LOGIC_VECTOR(1 downto 0);
      y              : out STD_LOGIC
    );
  end component;

  component mux2to1
    port (
      d0  : in  STD_LOGIC;
      d1  : in  STD_LOGIC;
      sel : in  STD_LOGIC;
      y   : out STD_LOGIC
    );
  end component;

  component and2
    port ( a, b : in STD_LOGIC; y : out STD_LOGIC );
  end component;

  component and3
    port ( a, b, c : in STD_LOGIC; y : out STD_LOGIC );
  end component;

  component or2
    port ( a, b : in STD_LOGIC; y : out STD_LOGIC );
  end component;

  component or4
    port ( a, b, c, d : in STD_LOGIC; y : out STD_LOGIC );
  end component;

  component inv
    port ( a : in STD_LOGIC; y : out STD_LOGIC );
  end component;

  component xor2
    port ( a, b : in STD_LOGIC; y : out STD_LOGIC );
  end component;

  component xnor2
    port ( a, b : in STD_LOGIC; y : out STD_LOGIC );
  end component;

  component dff_fall
    port ( clk, reset, d : in STD_LOGIC; q : out STD_LOGIC );
  end component;

  component tbuf8
    port (
      d  : in  STD_LOGIC_VECTOR(7 downto 0);
      en : in  STD_LOGIC;
      b  : out STD_LOGIC_VECTOR(7 downto 0)
    );
  end component;

  component gte5
    port (
      a   : in  STD_LOGIC_VECTOR(4 downto 0);
      b   : in  STD_LOGIC_VECTOR(4 downto 0);
      gte : out STD_LOGIC
    );
  end component;

  component cache_fsm_struct
    port (
      clk            : in  STD_LOGIC;
      reset          : in  STD_LOGIC;
      start          : in  STD_LOGIC;
      tag            : in  STD_LOGIC;    -- hit boolean
      valid          : in  STD_LOGIC;    -- valid bit
      read_write     : in  STD_LOGIC;    -- '1' = read

      busy           : out STD_LOGIC;
      en             : out STD_LOGIC;    -- mem_en for MISS
      fsm_resp_pulse : out STD_LOGIC
    );
  end component;

  --------------------------------------------------------------------
  -- CONSTANTS / ADDRESS FIELDS
  --------------------------------------------------------------------
  signal tag_in    : STD_LOGIC_VECTOR(1 downto 0);
  signal idx       : STD_LOGIC_VECTOR(1 downto 0);
  signal byte_sel  : STD_LOGIC_VECTOR(1 downto 0);

  signal en_1hot   : STD_LOGIC_VECTOR(3 downto 0);

  signal sig_zero, sig_one : STD_LOGIC;
  signal vec_zero5, vec_sixteen : STD_LOGIC_VECTOR(4 downto 0);

  --------------------------------------------------------------------
  -- BANK 0 ARRAYS
  --------------------------------------------------------------------
  signal d0_0, d1_0, d2_0, d3_0 : STD_LOGIC_VECTOR(7 downto 0);
  signal v0_0, v1_0, v2_0, v3_0 : STD_LOGIC;
  signal h0_0, h1_0, h2_0, h3_0 : STD_LOGIC;
  signal pk0_0, pk1_0, pk2_0, pk3_0 : STD_LOGIC_VECTOR(7 downto 0);

  signal valid_sel_0 : STD_LOGIC;
  signal hit_sel_0   : STD_LOGIC;
  signal peek_data_0 : STD_LOGIC_VECTOR(7 downto 0);

  --------------------------------------------------------------------
  -- BANK 1 ARRAYS
  --------------------------------------------------------------------
  signal d0_1, d1_1, d2_1, d3_1 : STD_LOGIC_VECTOR(7 downto 0);
  signal v0_1, v1_1, v2_1, v3_1 : STD_LOGIC;
  signal h0_1, h1_1, h2_1, h3_1 : STD_LOGIC;
  signal pk0_1, pk1_1, pk2_1, pk3_1 : STD_LOGIC_VECTOR(7 downto 0);

  signal valid_sel_1 : STD_LOGIC;
  signal hit_sel_1   : STD_LOGIC;
  signal peek_data_1 : STD_LOGIC_VECTOR(7 downto 0);

  --------------------------------------------------------------------
  -- LRU / BANK SELECTION + FSM VIEW
  --------------------------------------------------------------------
  signal hit0_and_valid0 : STD_LOGIC;
  signal hit1_and_valid1 : STD_LOGIC;
  signal hit_any         : STD_LOGIC;
  signal no_hit          : STD_LOGIC;
  signal no_hit_lru      : STD_LOGIC;

  signal mru_bank        : STD_LOGIC;  -- here used as "LRU" bit
  signal mru_bank_d      : STD_LOGIC;

  signal used_bank_sel             : STD_LOGIC;  -- bank used for this transaction
  signal used_bank_sel_d           : STD_LOGIC;
  signal used_bank_sel_candidate   : STD_LOGIC;
  signal used_bank_sel_n           : STD_LOGIC;

  signal hit_sel_fsm    : STD_LOGIC;
  signal valid_sel_fsm  : STD_LOGIC;

  -- edge detect for "transaction done"
  signal busy_int    : STD_LOGIC;
  signal busy_q      : STD_LOGIC;
  signal busy_q_d    : STD_LOGIC;
  signal busy_n      : STD_LOGIC;
  signal txn_done    : STD_LOGIC;

  --------------------------------------------------------------------
  -- DATA BACK TO CPU
  --------------------------------------------------------------------
  signal curr_byte_sel  : STD_LOGIC_VECTOR(1 downto 0);
  signal peek_sel_data  : STD_LOGIC_VECTOR(7 downto 0);
  signal cpu_do         : STD_LOGIC_VECTOR(7 downto 0);
  signal cpu_data_oe    : STD_LOGIC;
  signal cpu_data_oe_d  : STD_LOGIC;

  --------------------------------------------------------------------
  -- FSM LATCHED REQUEST INFO
  --------------------------------------------------------------------
  signal fsm_en         : STD_LOGIC;
  signal fsm_resp_pulse : STD_LOGIC;

  signal latch_go             : STD_LOGIC;
  signal L_is_write, L_is_read, L_is_hit : STD_LOGIC;
  signal L_is_write_din, L_is_read_din, L_is_hit_din : STD_LOGIC;

  signal cpu_rd_wrn_n   : STD_LOGIC;

  --------------------------------------------------------------------
  -- REFILL CONTROLLER
  --------------------------------------------------------------------
  signal mem_en_q, mem_en_q_d, mem_en_q_n : STD_LOGIC;

  signal refill_active, refill_active_d : STD_LOGIC;
  signal refill_active_trigger : STD_LOGIC; -- Trigger logic

  signal refill_cnt, refill_cnt_d        : STD_LOGIC_VECTOR(4 downto 0);
  signal refill_offset_reg, refill_offset_d : STD_LOGIC_VECTOR(1 downto 0);

  signal start_refill        : STD_LOGIC;

  signal cnt_inc, cnt_after_inc, cnt_after_zero : STD_LOGIC_VECTOR(4 downto 0);
  signal c1, c2, c3, c4, c5 : STD_LOGIC;

  signal x8, x10, x12, x14 : STD_LOGIC_VECTOR(4 downto 0);
  signal eq8, eq10, eq12, eq14 : STD_LOGIC;
  signal eq8_low3, eq8_high2, eq10_low3, eq10_high2 : STD_LOGIC;
  signal eq12_low3, eq12_high2, eq14_low3, eq14_high2 : STD_LOGIC;

  signal ge16, refill_active_and_ge16, clr_active_pulse : STD_LOGIC;

  signal refill_active_and_eq8,  refill_active_and_eq10  : STD_LOGIC;
  signal refill_active_and_eq12, refill_active_and_eq14  : STD_LOGIC;

  signal load00_pulse, load01_pulse, load10_pulse, load11_pulse : STD_LOGIC;
  signal load_en01_11, load_en10_00, load_en : STD_LOGIC;
  signal offset_bit0_load, offset_bit1_load : STD_LOGIC;

  signal we_top_d, set_tag_top_d : STD_LOGIC;
  signal we_top,   set_tag_top   : STD_LOGIC;

  signal we_top_0, we_top_1 : STD_LOGIC;
  signal set_tag_top_0, set_tag_top_1 : STD_LOGIC;

  signal write_hit_pulse, write_hit_pulse_full : STD_LOGIC;
  signal refill_write_pulse, set_tag_pulse : STD_LOGIC;

  signal eq8_or_eq10, eq12_or_eq14, any_eq8_14 : STD_LOGIC;

  --------------------------------------------------------------------
  -- DEBUG SIGNALS (aliases)
  --------------------------------------------------------------------
  signal dbg_hit0, dbg_hit1        : STD_LOGIC;
  signal dbg_valid0, dbg_valid1    : STD_LOGIC;
  signal dbg_tag_fsm, dbg_valid_fsm: STD_LOGIC;
  signal dbg_bank_sel_now          : STD_LOGIC;
  signal dbg_used_bank_sel         : STD_LOGIC;
  signal dbg_mru_bank              : STD_LOGIC;
  signal dbg_refill_cnt            : STD_LOGIC_VECTOR(4 downto 0);
  signal dbg_refill_active         : STD_LOGIC;

begin
  --------------------------------------------------------------------
  -- CONSTANTS / ADDRESS SLICING
  --------------------------------------------------------------------
  sig_zero    <= '0';
  sig_one     <= '1';
  vec_zero5   <= (others => '0');
  vec_sixteen <= "10000";

  tag_in   <= cpu_add(5 downto 4);
  idx      <= cpu_add(3 downto 2);
  byte_sel <= cpu_add(1 downto 0);

  --------------------------------------------------------------------
  -- INDEX DECODER
  --------------------------------------------------------------------
  U_DEC : decoder
    port map (
      block_addr => idx,
      block_sel  => en_1hot
    );

  --------------------------------------------------------------------
  -- BANK 0 CACHE BLOCKS
  --------------------------------------------------------------------
  U_CB0_0 : cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(0),
      data_in    => cpu_data,
      data_out   => d0_0,
      byte_sel   => curr_byte_sel,
      rd_wr      => cpu_rd_wrn,
      mem_in     => mem_data,
      we         => we_top_0,
      set_tag    => set_tag_top_0,
      tag_in     => tag_in,
      valid_out  => v0_0,
      tag_out    => open,
      hit_miss   => h0_0,
      peek_sel   => byte_sel,
      peek_data  => pk0_0
    );

  U_CB1_0 : cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(1),
      data_in    => cpu_data,
      data_out   => d1_0,
      byte_sel   => curr_byte_sel,
      rd_wr      => cpu_rd_wrn,
      mem_in     => mem_data,
      we         => we_top_0,
      set_tag    => set_tag_top_0,
      tag_in     => tag_in,
      valid_out  => v1_0,
      tag_out    => open,
      hit_miss   => h1_0,
      peek_sel   => byte_sel,
      peek_data  => pk1_0
    );

  U_CB2_0 : cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(2),
      data_in    => cpu_data,
      data_out   => d2_0,
      byte_sel   => curr_byte_sel,
      rd_wr      => cpu_rd_wrn,
      mem_in     => mem_data,
      we         => we_top_0,
      set_tag    => set_tag_top_0,
      tag_in     => tag_in,
      valid_out  => v2_0,
      tag_out    => open,
      hit_miss   => h2_0,
      peek_sel   => byte_sel,
      peek_data  => pk2_0
    );

  U_CB3_0 : cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(3),
      data_in    => cpu_data,
      data_out   => d3_0,
      byte_sel   => curr_byte_sel,
      rd_wr      => cpu_rd_wrn,
      mem_in     => mem_data,
      we         => we_top_0,
      set_tag    => set_tag_top_0,
      tag_in     => tag_in,
      valid_out  => v3_0,
      tag_out    => open,
      hit_miss   => h3_0,
      peek_sel   => byte_sel,
      peek_data  => pk3_0
    );

  U_MUX_VALID_0 : mux4to1_1
    port map (
      d0  => v0_0,
      d1  => v1_0,
      d2  => v2_0,
      d3  => v3_0,
      sel => idx,
      y   => valid_sel_0
    );

  U_MUX_HIT_0 : mux4to1_1
    port map (
      d0  => h0_0,
      d1  => h1_0,
      d2  => h2_0,
      d3  => h3_0,
      sel => idx,
      y   => hit_sel_0
    );

  U_MUX_PEEK_0 : mux4to1_8
    port map (
      d0  => pk0_0,
      d1  => pk1_0,
      d2  => pk2_0,
      d3  => pk3_0,
      sel => idx,
      y   => peek_data_0
    );

  --------------------------------------------------------------------
  -- BANK 1 CACHE BLOCKS
  --------------------------------------------------------------------
  U_CB0_1 : cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(0),
      data_in    => cpu_data,
      data_out   => d0_1,
      byte_sel   => curr_byte_sel,
      rd_wr      => cpu_rd_wrn,
      mem_in     => mem_data,
      we         => we_top_1,
      set_tag    => set_tag_top_1,
      tag_in     => tag_in,
      valid_out  => v0_1,
      tag_out    => open,
      hit_miss   => h0_1,
      peek_sel   => byte_sel,
      peek_data  => pk0_1
    );

  U_CB1_1 : cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(1),
      data_in    => cpu_data,
      data_out   => d1_1,
      byte_sel   => curr_byte_sel,
      rd_wr      => cpu_rd_wrn,
      mem_in     => mem_data,
      we         => we_top_1,
      set_tag    => set_tag_top_1,
      tag_in     => tag_in,
      valid_out  => v1_1,
      tag_out    => open,
      hit_miss   => h1_1,
      peek_sel   => byte_sel,
      peek_data  => pk1_1
    );

  U_CB2_1 : cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(2),
      data_in    => cpu_data,
      data_out   => d2_1,
      byte_sel   => curr_byte_sel,
      rd_wr      => cpu_rd_wrn,
      mem_in     => mem_data,
      we         => we_top_1,
      set_tag    => set_tag_top_1,
      tag_in     => tag_in,
      valid_out  => v2_1,
      tag_out    => open,
      hit_miss   => h2_1,
      peek_sel   => byte_sel,
      peek_data  => pk2_1
    );

  U_CB3_1 : cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(3),
      data_in    => cpu_data,
      data_out   => d3_1,
      byte_sel   => curr_byte_sel,
      rd_wr      => cpu_rd_wrn,
      mem_in     => mem_data,
      we         => we_top_1,
      set_tag    => set_tag_top_1,
      tag_in     => tag_in,
      valid_out  => v3_1,
      tag_out    => open,
      hit_miss   => h3_1,
      peek_sel   => byte_sel,
      peek_data  => pk3_1
    );

  U_MUX_VALID_1 : mux4to1_1
    port map (
      d0  => v0_1,
      d1  => v1_1,
      d2  => v2_1,
      d3  => v3_1,
      sel => idx,
      y   => valid_sel_1
    );

  U_MUX_HIT_1 : mux4to1_1
    port map (
      d0  => h0_1,
      d1  => h1_1,
      d2  => h2_1,
      d3  => h3_1,
      sel => idx,
      y   => hit_sel_1
    );

  U_MUX_PEEK_1 : mux4to1_8
    port map (
      d0  => pk0_1,
      d1  => pk1_1,
      d2  => pk2_1,
      d3  => pk3_1,
      sel => idx,
      y   => peek_data_1
    );

  --------------------------------------------------------------------
  -- HIT / VALID COMBINATION + BANK SELECTION
  --------------------------------------------------------------------
  -- hit in each way only counts if that way is valid
  U_AND_HV0 : and2 port map (a => hit_sel_0, b => valid_sel_0, y => hit0_and_valid0);
  U_AND_HV1 : and2 port map (a => hit_sel_1, b => valid_sel_1, y => hit1_and_valid1);

  U_OR_HIT_ANY : or2 port map (a => hit0_and_valid0, b => hit1_and_valid1, y => hit_any);
  U_INV_HITANY : inv  port map (a => hit_any, y => no_hit);

  -- no_hit_lru = (no_hit AND current LRU bit)
  U_AND_NOHIT_LRU : and2 port map (a => no_hit, b => mru_bank, y => no_hit_lru);

  -- When a new operation starts:
  --   if way1 hits -> choose bank1
  --   else if way0 hits -> choose bank0
  --   else (miss) -> choose LRU bank
  U_OR_USED_CAND : or2
    port map (a => hit1_and_valid1, b => no_hit_lru, y => used_bank_sel_candidate);

  -- latch selected bank at start; otherwise hold previous
  U_MUX_USED_SEL_D : mux2to1
    port map (
      d0  => used_bank_sel,
      d1  => used_bank_sel_candidate,
      sel => start,
      y   => used_bank_sel_d
    );

  U_FF_USED_SEL : dff_fall
    port map (clk => clk, reset => reset, d => used_bank_sel_d, q => used_bank_sel);

  -- FSM's view: hit/valid from the *selected* bank (candidate for this access).
  U_MUX_TAG_FSM : mux2to1
    port map (
      d0  => hit_sel_0,
      d1  => hit_sel_1,
      sel => used_bank_sel_candidate,
      y   => hit_sel_fsm
    );

  U_MUX_VALID_FSM : mux2to1
    port map (
      d0  => valid_sel_0,
      d1  => valid_sel_1,
      sel => used_bank_sel_candidate,
      y   => valid_sel_fsm
    );

  --------------------------------------------------------------------
  -- CPU DATA PATH (bank chosen by used_bank_sel)
  --------------------------------------------------------------------
  gen_peek_data : for i in 0 to 7 generate
    U_MUX_PEEK_SEL : mux2to1
      port map (
        d0  => peek_data_0(i),
        d1  => peek_data_1(i),
        sel => used_bank_sel,
        y   => peek_sel_data(i)
      );
  end generate;

  cpu_do <= peek_sel_data;

  U_TBUF : tbuf8
    port map (d => cpu_do, en => cpu_data_oe, b => cpu_data);

  --------------------------------------------------------------------
  -- FSM
  --------------------------------------------------------------------
  U_FSM : cache_fsm_struct
    port map (
      clk            => clk,
      reset          => reset,
      start          => start,
      tag            => hit_sel_fsm,
      valid          => valid_sel_fsm,
      read_write     => cpu_rd_wrn,  -- '1' = read
      busy           => busy_int,
      en             => fsm_en,
      fsm_resp_pulse => fsm_resp_pulse
    );

  busy   <= busy_int;
  mem_en <= fsm_en;

  mem_add(5 downto 2) <= cpu_add(5 downto 2);
  mem_add(1 downto 0) <= (others => '0');

  --------------------------------------------------------------------
  -- BYTE SELECT (normal vs refill)
  --------------------------------------------------------------------
  gen_curr_byte : for i in 0 to 1 generate
    U_MUX_CURR_BYTE : mux2to1
      port map (
        d0  => byte_sel(i),
        d1  => refill_offset_reg(i),
        sel => refill_active,
        y   => curr_byte_sel(i)
      );
  end generate;

  --------------------------------------------------------------------
  -- REQUEST LATCHING
  --------------------------------------------------------------------
  U_FF_LATCH_GO : dff_fall
    port map (clk => clk, reset => reset, d => start, q => latch_go);

  U_INV_RW : inv
    port map (a => cpu_rd_wrn, y => cpu_rd_wrn_n);

  U_MUX_LWR : mux2to1
    port map (d0 => L_is_write, d1 => cpu_rd_wrn_n, sel => start, y => L_is_write_din);
  U_FF_LWR  : dff_fall
    port map (clk => clk, reset => reset, d => L_is_write_din, q => L_is_write);

  U_MUX_LRD : mux2to1
    port map (d0 => L_is_read, d1 => cpu_rd_wrn, sel => start, y => L_is_read_din);
  U_FF_LRD  : dff_fall
    port map (clk => clk, reset => reset, d => L_is_read_din, q => L_is_read);

  U_MUX_LHIT : mux2to1
    port map (d0 => L_is_hit, d1 => hit_sel_fsm, sel => start, y => L_is_hit_din);
  U_FF_LHIT  : dff_fall
    port map (clk => clk, reset => reset, d => L_is_hit_din, q => L_is_hit);

  U_AND_CPU_OE : and2
    port map (a => fsm_resp_pulse, b => L_is_read, y => cpu_data_oe_d);
  U_FF_CPU_OE : dff_fall
    port map (clk => clk, reset => reset, d => cpu_data_oe_d, q => cpu_data_oe);

  --------------------------------------------------------------------
  -- REFILL CONTROLLER (same as original chip)
  --------------------------------------------------------------------
  mem_en_q_d <= fsm_en;

  U_INV_MEM_EN_Q : inv
    port map (a => mem_en_q, y => mem_en_q_n);

  U_AND_START_REFILL : and2
    port map (a => mem_en_q_n, b => fsm_en, y => start_refill);

  -- incrementer for refill_cnt
  U_INV_CNT0 : inv  port map (a => refill_cnt(0), y => cnt_inc(0));
  c1 <= refill_cnt(0);

  U_XOR_CNT1 : xor2 port map (a => refill_cnt(1), b => c1, y => cnt_inc(1));
  U_AND_CNT1 : and2 port map (a => refill_cnt(1), b => c1, y => c2);

  U_XOR_CNT2 : xor2 port map (a => refill_cnt(2), b => c2, y => cnt_inc(2));
  U_AND_CNT2 : and2 port map (a => refill_cnt(2), b => c2, y => c3);

  U_XOR_CNT3 : xor2 port map (a => refill_cnt(3), b => c3, y => cnt_inc(3));
  U_AND_CNT3 : and2 port map (a => refill_cnt(3), b => c3, y => c4);

  U_XOR_CNT4 : xor2 port map (a => refill_cnt(4), b => c4, y => cnt_inc(4));
  U_AND_CNT4 : and2 port map (a => refill_cnt(4), b => c4, y => c5);

  gen_cnt_logic : for i in 0 to 4 generate
    U_MUX_INC : mux2to1
      port map (
        d0  => refill_cnt(i),
        d1  => cnt_inc(i),
        sel => refill_active,
        y   => cnt_after_inc(i)
      );
    U_MUX_CLR : mux2to1
      port map (
        d0  => cnt_after_inc(i),
        d1  => sig_zero,
        sel => start_refill,
        y   => cnt_after_zero(i)
      );
  end generate;

  refill_cnt_d <= cnt_after_zero;

  -- eq8 comparator (01000)
  U_XNOR8_0  : xnor2 port map (a => refill_cnt(0), b => sig_zero, y => x8(0));
  U_XNOR8_1  : xnor2 port map (a => refill_cnt(1), b => sig_zero, y => x8(1));
  U_XNOR8_2  : xnor2 port map (a => refill_cnt(2), b => sig_zero, y => x8(2));
  U_XNOR8_3  : xnor2 port map (a => refill_cnt(3), b => sig_one,  y => x8(3));
  U_XNOR8_4  : xnor2 port map (a => refill_cnt(4), b => sig_zero, y => x8(4));
  U_AND8_LO  : and3  port map (a => x8(0), b => x8(1), c => x8(2), y => eq8_low3);
  U_AND8_HI  : and2  port map (a => x8(3), b => x8(4), y => eq8_high2);
  U_AND8_ALL : and2  port map (a => eq8_low3, b => eq8_high2, y => eq8);

  -- eq10 comparator (01010)
  U_XNOR10_0 : xnor2 port map (a => refill_cnt(0), b => sig_zero, y => x10(0));
  U_XNOR10_1 : xnor2 port map (a => refill_cnt(1), b => sig_one,  y => x10(1));
  U_XNOR10_2 : xnor2 port map (a => refill_cnt(2), b => sig_zero, y => x10(2));
  U_XNOR10_3 : xnor2 port map (a => refill_cnt(3), b => sig_one,  y => x10(3));
  U_XNOR10_4 : xnor2 port map (a => refill_cnt(4), b => sig_zero, y => x10(4));
  U_AND10_LO : and3  port map (a => x10(0), b => x10(1), c => x10(2), y => eq10_low3);
  U_AND10_HI : and2  port map (a => x10(3), b => x10(4), y => eq10_high2);
  U_AND10_ALL: and2  port map (a => eq10_low3, b => eq10_high2, y => eq10);

  -- eq12 comparator (01100)
  U_XNOR12_0 : xnor2 port map (a => refill_cnt(0), b => sig_zero, y => x12(0));
  U_XNOR12_1 : xnor2 port map (a => refill_cnt(1), b => sig_zero, y => x12(1));
  U_XNOR12_2 : xnor2 port map (a => refill_cnt(2), b => sig_one,  y => x12(2));
  U_XNOR12_3 : xnor2 port map (a => refill_cnt(3), b => sig_one,  y => x12(3));
  U_XNOR12_4 : xnor2 port map (a => refill_cnt(4), b => sig_zero, y => x12(4));
  U_AND12_LO : and3  port map (a => x12(0), b => x12(1), c => x12(2), y => eq12_low3);
  U_AND12_HI : and2  port map (a => x12(3), b => x12(4), y => eq12_high2);
  U_AND12_ALL: and2  port map (a => eq12_low3, b => eq12_high2, y => eq12);

  -- eq14 comparator (01110)
  U_XNOR14_0 : xnor2 port map (a => refill_cnt(0), b => sig_zero, y => x14(0));
  U_XNOR14_1 : xnor2 port map (a => refill_cnt(1), b => sig_one,  y => x14(1));
  U_XNOR14_2 : xnor2 port map (a => refill_cnt(2), b => sig_one,  y => x14(2));
  U_XNOR14_3 : xnor2 port map (a => refill_cnt(3), b => sig_one,  y => x14(3));
  U_XNOR14_4 : xnor2 port map (a => refill_cnt(4), b => sig_zero, y => x14(4));
  U_AND14_LO : and3  port map (a => x14(0), b => x14(1), c => x14(2), y => eq14_low3);
  U_AND14_HI : and2  port map (a => x14(3), b => x14(4), y => eq14_high2);
  U_AND14_ALL: and2  port map (a => eq14_low3, b => eq14_high2, y => eq14);

  U_GE16 : gte5
    port map (a => refill_cnt, b => vec_sixteen, gte => ge16);

  U_AND_ACTIVE_GE16 : and2
    port map (a => refill_active, b => ge16, y => refill_active_and_ge16);

  clr_active_pulse <= refill_active_and_ge16;

  --------------------------------------------------------------------
  -- latch refill_active ON START_REFILL (OR gate)
  --------------------------------------------------------------------
  U_OR_ACTIVE_START : or2
    port map (a => refill_active, b => start_refill, y => refill_active_trigger);

  U_MUX_ACTIVE_CLR : mux2to1
    port map (d0 => refill_active_trigger, d1 => sig_zero,
              sel => clr_active_pulse, y => refill_active_d);

  U_AND_EQ8   : and2 port map (a => refill_active, b => eq8,  y => refill_active_and_eq8);
  U_AND_EQ10  : and2 port map (a => refill_active, b => eq10, y => refill_active_and_eq10);
  U_AND_EQ12  : and2 port map (a => refill_active, b => eq12, y => refill_active_and_eq12);
  U_AND_EQ14  : and2 port map (a => refill_active, b => eq14, y => refill_active_and_eq14);

  U_OR_LOAD00 : or2  port map (a => start_refill,          b => refill_active_and_eq8,  y => load00_pulse);
  load01_pulse <= refill_active_and_eq10;
  load10_pulse <= refill_active_and_eq12;
  load11_pulse <= refill_active_and_eq14;

  U_OR01_11 : or2 port map (a => load01_pulse, b => load11_pulse, y => load_en01_11);
  U_OR10_00 : or2 port map (a => load10_pulse, b => load00_pulse, y => load_en10_00);
  U_OR_ALL  : or2 port map (a => load_en01_11, b => load_en10_00, y => load_en);

  U_OR_OFF0 : or2 port map (a => load01_pulse, b => load11_pulse, y => offset_bit0_load);
  U_OR_OFF1 : or2 port map (a => load10_pulse, b => load11_pulse, y => offset_bit1_load);

  U_MUX_OFF0 : mux2to1
    port map (d0 => refill_offset_reg(0), d1 => offset_bit0_load,
              sel => load_en, y => refill_offset_d(0));
  U_MUX_OFF1 : mux2to1
    port map (d0 => refill_offset_reg(1), d1 => offset_bit1_load,
              sel => load_en, y => refill_offset_d(1));

  U_FF_MEM_EN_Q   : dff_fall port map (clk => clk, reset => reset, d => mem_en_q_d,       q => mem_en_q);
  U_FF_REFILL_ACT : dff_fall port map (clk => clk, reset => reset, d => refill_active_d, q => refill_active);

  gen_refill_cnt_reg : for i in 0 to 4 generate
    U_FF_RCNT : dff_fall
      port map (clk => clk, reset => reset, d => refill_cnt_d(i), q => refill_cnt(i));
  end generate;

  gen_refill_off_reg : for i in 0 to 1 generate
    U_FF_ROFF : dff_fall
      port map (clk => clk, reset => reset, d => refill_offset_d(i), q => refill_offset_reg(i));
  end generate;

  -- write pulses
  U_AND_WR0 : and2 port map (a => latch_go,   b => L_is_write, y => write_hit_pulse);
  U_AND_WR1 : and2 port map (a => write_hit_pulse, b => L_is_hit, y => write_hit_pulse_full);

  U_OR_8_10   : or2 port map (a => eq8,  b => eq10, y => eq8_or_eq10);
  U_OR_12_14  : or2 port map (a => eq12, b => eq14, y => eq12_or_eq14);
  U_OR_ANY814 : or2 port map (a => eq8_or_eq10, b => eq12_or_eq14, y => any_eq8_14);

  U_AND_REFW : and2 port map (a => refill_active, b => any_eq8_14, y => refill_write_pulse);

  U_OR_WE_TOP : or2 port map (a => write_hit_pulse_full, b => refill_write_pulse, y => we_top_d);

  U_AND_SET_TAG : and2 port map (a => refill_active, b => eq8, y => set_tag_pulse);
  set_tag_top_d <= set_tag_pulse;

  -- Register WE and set_tag on falling edge (match original chip behaviour)
  U_DFF_WE_TOP : dff_fall
    port map (clk => clk, reset => reset, d => we_top_d,      q => we_top);

  U_DFF_SET_TAG_TOP : dff_fall
    port map (clk => clk, reset => reset, d => set_tag_top_d, q => set_tag_top);

  -- Gate writes/tags into selected bank
  U_INV_USED_SEL : inv port map (a => used_bank_sel, y => used_bank_sel_n);

  U_WE_BANK0 : and2 port map (a => we_top,      b => used_bank_sel_n, y => we_top_0);
  U_WE_BANK1 : and2 port map (a => we_top,      b => used_bank_sel,   y => we_top_1);
  U_ST_BANK0 : and2 port map (a => set_tag_top, b => used_bank_sel_n, y => set_tag_top_0);
  U_ST_BANK1 : and2 port map (a => set_tag_top, b => used_bank_sel,   y => set_tag_top_1);

  --------------------------------------------------------------------
  -- LRU UPDATE AFTER EACH TRANSACTION (busy falling edge)
  --------------------------------------------------------------------
  busy_q_d <= busy_int;

  U_FF_BUSYQ : dff_fall port map (clk => clk, reset => reset, d => busy_q_d, q => busy_q);
  U_INV_BUSY : inv       port map (a => busy_int, y => busy_n);
  U_AND_TXN  : and2      port map (a => busy_q, b => busy_n, y => txn_done);

  -- new LRU = "other" bank than the one just used
  U_INV_USED_FOR_LRU : inv port map (a => used_bank_sel, y => used_bank_sel_n);

  U_MUX_MRU_D : mux2to1
    port map (
      d0  => mru_bank,          -- hold
      d1  => used_bank_sel_n,   -- update to other bank
      sel => txn_done,
      y   => mru_bank_d
    );

  U_FF_MRU : dff_fall
    port map (clk => clk, reset => reset, d => mru_bank_d, q => mru_bank);

  --------------------------------------------------------------------
  -- DEBUG ALIASES
  --------------------------------------------------------------------
  dbg_hit0          <= hit_sel_0;
  dbg_hit1          <= hit_sel_1;
  dbg_valid0        <= valid_sel_0;
  dbg_valid1        <= valid_sel_1;
  dbg_tag_fsm       <= hit_sel_fsm;
  dbg_valid_fsm     <= valid_sel_fsm;
  dbg_bank_sel_now  <= used_bank_sel;
  dbg_used_bank_sel <= used_bank_sel;
  dbg_mru_bank      <= mru_bank;
  dbg_refill_cnt    <= refill_cnt;
  dbg_refill_active <= refill_active;

end Structural;

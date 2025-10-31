library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity chip is
  port (
    cpu_add    : in    std_logic_vector(5 downto 0);   -- {tag[5:4], idx[3:2], byte[1:0]}
    cpu_data   : inout std_logic_vector(7 downto 0);   -- bidirectional CPU data bus
    cpu_rd_wrn : in    std_logic;                      -- '1' = read, '0' = write
    start      : in    std_logic;                      -- request start
    clk        : in    std_logic;
    reset      : in    std_logic;                      -- async high reset

    mem_data   : in    std_logic_vector(7 downto 0);   -- memory data returning on refill
    Vdd        : in    std_logic;
    Gnd        : in    std_logic;

    busy       : out   std_logic;                      -- from FSM
    mem_en     : out   std_logic;                      -- "request memory" / enable external mem
    mem_add    : out   std_logic_vector(5 downto 0)    -- address to memory (block aligned)
  );
end chip;

architecture structural of chip is

  --------------------------------------------------------------------------
  -- Component declarations
  --------------------------------------------------------------------------

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
      rd_wr      : in  std_logic; -- '1'=read, '0'=write from CPU

      mem_in     : in  std_logic_vector(7 downto 0);

      we         : in  std_logic; -- write strobe into cache array
      set_tag    : in  std_logic; -- tag/set-valid strobe
      tag_in     : in  std_logic_vector(1 downto 0);

      valid_out  : out std_logic;
      tag_out    : out std_logic_vector(1 downto 0);
      hit_miss   : out std_logic  -- '1' if hit, '0' if miss (for this block)
    );
  end component;

  component cache_fsm_struct
    port (
      clk        : in  std_logic;
      reset      : in  std_logic;
      start      : in  std_logic;
      tag        : in  std_logic;           -- "tag matches?"
      valid      : in  std_logic;           -- "line valid?"
      read_write : in  std_logic;           -- cpu_rd_wrn
      busy       : out std_logic;
      done       : out std_logic;
      en         : out std_logic;           -- mem_en (request external memory)
      OE_CD      : out std_logic;           -- drive CPU data bus?
      OE_MA      : out std_logic            -- (not strictly used outside)
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

  -- matches your actual reg5_fall that has an enable
  component reg5_fall
    port (
      clk   : in  std_logic;
      reset : in  std_logic;
      en    : in  std_logic;
      d     : in  std_logic_vector(4 downto 0);
      q     : out std_logic_vector(4 downto 0)
    );
  end component;

  component req_qualifier
    port (
      clk            : in  std_logic;
      reset          : in  std_logic;
      start_in       : in  std_logic;
      is_write_in    : in  std_logic;  -- NOT cpu_rd_wrn
      is_hit_in      : in  std_logic;  -- hit_sel_raw
      latch_go       : out std_logic;
      latched_write  : out std_logic;
      latched_hit    : out std_logic
    );
  end component;

  --------------------------------------------------------------------------
  -- Address field breakouts
  --------------------------------------------------------------------------
  signal tag_in    : std_logic_vector(1 downto 0); -- cpu_add(5 downto 4)
  signal idx       : std_logic_vector(1 downto 0); -- cpu_add(3 downto 2)
  signal byte_sel  : std_logic_vector(1 downto 0); -- cpu_add(1 downto 0)

  --------------------------------------------------------------------------
  -- Decoder -> one-hot enables for each cache block
  --------------------------------------------------------------------------
  signal en_1hot   : std_logic_vector(3 downto 0);

  --------------------------------------------------------------------------
  -- Cache block outputs
  --------------------------------------------------------------------------
  signal d0,d1,d2,d3 : std_logic_vector(7 downto 0);
  signal v0,v1,v2,v3 : std_logic;
  signal t0,t1,t2,t3 : std_logic_vector(1 downto 0);
  signal h0,h1,h2,h3 : std_logic;

  --------------------------------------------------------------------------
  -- Selected data / valid / hit for the addressed index
  --------------------------------------------------------------------------
  signal data_sel    : std_logic_vector(7 downto 0);
  signal valid_sel   : std_logic;
  signal hit_sel_raw : std_logic;

  -- tag match for that index
  signal tag_match_sel : std_logic;

  --------------------------------------------------------------------------
  -- FSM <-> chip signals
  --------------------------------------------------------------------------
  signal fsm_busy   : std_logic;
  signal fsm_done   : std_logic;
  signal fsm_en     : std_logic;  -- memory enable / external mem request
  signal fsm_OEcd   : std_logic;
  signal fsm_OEma   : std_logic;

  --------------------------------------------------------------------------
  -- Qualified request capture (stable "was write", "was hit")
  --------------------------------------------------------------------------
  signal not_cpu_rd_wrn : std_logic;  -- '1' means write
  signal latch_go       : std_logic;
  signal latched_write  : std_logic;
  signal latched_hit    : std_logic;

  -- single clean pulse for write hit
  signal write_hit_pulse : std_logic;

  --------------------------------------------------------------------------
  -- Refill / memory-stream tracking (structural version of old process)
  --------------------------------------------------------------------------
  signal mem_en_q_q      : std_logic;
  signal mem_en_q_d      : std_logic;

  signal rd_q_q          : std_logic;
  signal rd_q_d          : std_logic;

  signal refill_active_q : std_logic;
  signal refill_active_d : std_logic;

  signal refill_cnt_q    : std_logic_vector(4 downto 0);
  signal refill_cnt_d    : std_logic_vector(4 downto 0);

  -- helper signals for refill control
  signal refill_start_cond : std_logic;
  signal cnt_ge_16         : std_logic;

  signal cnt_is_8   : std_logic;
  signal cnt_is_10  : std_logic;
  signal cnt_is_12  : std_logic;
  signal cnt_is_14  : std_logic;

  signal refill_we_pulse      : std_logic;
  signal refill_settag_pulse  : std_logic;

  --------------------------------------------------------------------------
  -- Final global strobes
  --------------------------------------------------------------------------
  signal we_top_global        : std_logic;
  signal set_tag_top_global   : std_logic;

  --------------------------------------------------------------------------
  -- Per-block gated strobes
  --------------------------------------------------------------------------
  signal we_0, we_1, we_2, we_3                     : std_logic;
  signal set_tag_0, set_tag_1, set_tag_2, set_tag_3 : std_logic;

  --------------------------------------------------------------------------
  -- CPU data bus drive side
  --------------------------------------------------------------------------
  signal cpu_do : std_logic_vector(7 downto 0);

  --------------------------------------------------------------------------
  -- VHDL-87 helper: tie-high enable for reg5_fall
  --------------------------------------------------------------------------
  signal en_high : std_logic;

begin
  --------------------------------------------------------------------------
  -- drive the static '1' for enables that can't take a literal in port map
  --------------------------------------------------------------------------
  en_high <= '1';

  ----------------------------------------------------------------------------
  -- Break out the CPU address fields
  ----------------------------------------------------------------------------
  tag_in   <= cpu_add(5 downto 4);
  idx      <= cpu_add(3 downto 2);
  byte_sel <= cpu_add(1 downto 0);

  ----------------------------------------------------------------------------
  -- One-hot decode of index -> which cache_block is active
  ----------------------------------------------------------------------------
  u_dec: decoder
    port map (
      block_addr => idx,
      block_sel  => en_1hot
    );

  ----------------------------------------------------------------------------
  -- 4 cache blocks
  ----------------------------------------------------------------------------
  u_cb0: cache_block
    port map (
      clk       => clk,
      reset     => reset,
      enable    => en_1hot(0),
      data_in   => cpu_data,
      data_out  => d0,
      byte_sel  => byte_sel,
      rd_wr     => cpu_rd_wrn,
      mem_in    => mem_data,
      we        => we_0,
      set_tag   => set_tag_0,
      tag_in    => tag_in,
      valid_out => v0,
      tag_out   => t0,
      hit_miss  => h0
    );

  u_cb1: cache_block
    port map (
      clk       => clk,
      reset     => reset,
      enable    => en_1hot(1),
      data_in   => cpu_data,
      data_out  => d1,
      byte_sel  => byte_sel,
      rd_wr     => cpu_rd_wrn,
      mem_in    => mem_data,
      we        => we_1,
      set_tag   => set_tag_1,
      tag_in    => tag_in,
      valid_out => v1,
      tag_out   => t1,
      hit_miss  => h1
    );

  u_cb2: cache_block
    port map (
      clk       => clk,
      reset     => reset,
      enable    => en_1hot(2),
      data_in   => cpu_data,
      data_out  => d2,
      byte_sel  => byte_sel,
      rd_wr     => cpu_rd_wrn,
      mem_in    => mem_data,
      we        => we_2,
      set_tag   => set_tag_2,
      tag_in    => tag_in,
      valid_out => v2,
      tag_out   => t2,
      hit_miss  => h2
    );

  u_cb3: cache_block
    port map (
      clk       => clk,
      reset     => reset,
      enable    => en_1hot(3),
      data_in   => cpu_data,
      data_out  => d3,
      byte_sel  => byte_sel,
      rd_wr     => cpu_rd_wrn,
      mem_in    => mem_data,
      we        => we_3,
      set_tag   => set_tag_3,
      tag_in    => tag_in,
      valid_out => v3,
      tag_out   => t3,
      hit_miss  => h3
    );

  ----------------------------------------------------------------------------
  -- Mux out the selected block's data / valid / hit based on idx
  ----------------------------------------------------------------------------
  data_sel <= d0 when idx = "00" else
              d1 when idx = "01" else
              d2 when idx = "10" else
              d3;

  valid_sel <= v0 when idx = "00" else
               v1 when idx = "01" else
               v2 when idx = "10" else
               v3;

  hit_sel_raw <= h0 when idx = "00" else
                 h1 when idx = "01" else
                 h2 when idx = "10" else
                 h3;

  ----------------------------------------------------------------------------
  -- Tag match for the addressed line
  ----------------------------------------------------------------------------
  tag_match_sel <= '1' when
      ((idx = "00" and t0 = tag_in) or
       (idx = "01" and t1 = tag_in) or
       (idx = "10" and t2 = tag_in) or
       (idx = "11" and t3 = tag_in))
    else '0';

  ----------------------------------------------------------------------------
  -- FSM that sequences transaction timing / busy / mem_en / OE_CD
  ----------------------------------------------------------------------------
  u_fsm: cache_fsm_struct
    port map (
      clk        => clk,
      reset      => reset,
      start      => start,
      tag        => tag_match_sel,
      valid      => valid_sel,
      read_write => cpu_rd_wrn,
      busy       => fsm_busy,
      done       => fsm_done,
      en         => fsm_en,
      OE_CD      => fsm_OEcd,
      OE_MA      => fsm_OEma
    );

  busy   <= fsm_busy;
  mem_en <= fsm_en;

  -- memory address to external memory: block-aligned
  mem_add <= cpu_add(5 downto 2) & "00";

  ----------------------------------------------------------------------------
  -- Drive CPU data bus back to CPU only when FSM says so
  ----------------------------------------------------------------------------
  cpu_do   <= data_sel;
  cpu_data <= cpu_do when fsm_OEcd = '1' else (others => 'Z');

  ----------------------------------------------------------------------------
  -- Request qualifier block: captures hit / write info cleanly on negedge
  ----------------------------------------------------------------------------
  not_cpu_rd_wrn <= not cpu_rd_wrn;  -- '1' means write

  u_reqq: req_qualifier
    port map (
      clk            => clk,
      reset          => reset,
      start_in       => start,
      is_write_in    => not_cpu_rd_wrn,
      is_hit_in      => hit_sel_raw,
      latch_go       => latch_go,
      latched_write  => latched_write,
      latched_hit    => latched_hit
    );

  ----------------------------------------------------------------------------
  -- Clean one-shot write-hit pulse:
  -- latch_go = "this request launched"
  -- latched_write = "it was a write"
  -- latched_hit = "and it was a hit"
  ----------------------------------------------------------------------------
  write_hit_pulse <= latch_go and latched_write and latched_hit;

  ----------------------------------------------------------------------------
  -- Refill / memory burst tracking
  ----------------------------------------------------------------------------

  -- rd_q_q holds previous cpu_rd_wrn (captured on falling edge)
  rd_q_d <= cpu_rd_wrn;

  u_rdq_ff: dff_fall
    port map (
      clk   => clk,
      reset => reset,
      d     => rd_q_d,
      q     => rd_q_q
    );

  -- mem_en_q_q holds previous fsm_en
  mem_en_q_d <= fsm_en;

  u_menq_ff: dff_fall
    port map (
      clk   => clk,
      reset => reset,
      d     => mem_en_q_d,
      q     => mem_en_q_q
    );

  -- refill_start_cond = (mem_en_q was 0) and (fsm_en is 1) and (rd_q_q is 1/read)
  refill_start_cond <= '1' when (mem_en_q_q = '0' and fsm_en = '1' and rd_q_q = '1') else '0';

  -- count >= 16? just check MSB of 5-bit counter
  cnt_ge_16 <= refill_cnt_q(4);

  -- refill_active next:
  --   if a new refill starts: '1'
  --   elsif we were active and reached >=16: '0'
  --   else hold
  refill_active_d <= '1' when (refill_start_cond = '1') else
                     '0' when (refill_active_q = '1' and cnt_ge_16 = '1') else
                     refill_active_q;

  u_refact_ff: dff_fall
    port map (
      clk   => clk,
      reset => reset,
      d     => refill_active_d,
      q     => refill_active_q
    );

  -- refill counter next:
  --   if starting:       "00000"
  --   elsif active:      count+1
  --   else:              hold
  refill_cnt_d <= (others => '0')                             when (refill_start_cond = '1') else
                  std_logic_vector(unsigned(refill_cnt_q)+1) when (refill_active_q = '1') else
                  refill_cnt_q;

  u_refcnt_ff: reg5_fall
    port map (
      clk   => clk,
      reset => reset,
      en    => en_high,              -- <- was '1' literal before, now legal in VHDL-87
      d     => refill_cnt_d,
      q     => refill_cnt_q
    );

  ----------------------------------------------------------------------------
  -- Refill write strobes into cache on specific beats
  -- beats 8,10,12,14 get written; beat 8 also sets tag/valid
  ----------------------------------------------------------------------------
  cnt_is_8  <= '1' when (refill_cnt_q = "01000") else '0';
  cnt_is_10 <= '1' when (refill_cnt_q = "01010") else '0';
  cnt_is_12 <= '1' when (refill_cnt_q = "01100") else '0';
  cnt_is_14 <= '1' when (refill_cnt_q = "01110") else '0';

  refill_we_pulse <= '1' when (refill_active_q = '1' and
                               (cnt_is_8  = '1' or
                                cnt_is_10 = '1' or
                                cnt_is_12 = '1' or
                                cnt_is_14 = '1'))
                     else '0';

  refill_settag_pulse <= '1' when (refill_active_q = '1' and cnt_is_8 = '1')
                         else '0';

  ----------------------------------------------------------------------------
  -- Final global strobes
  ----------------------------------------------------------------------------
  we_top_global      <= '1' when ((write_hit_pulse = '1') or (refill_we_pulse = '1'))
                        else '0';

  set_tag_top_global <= '1' when (refill_settag_pulse = '1')
                        else '0';

  ----------------------------------------------------------------------------
  -- Per-block gated strobes:
  --   Only the indexed block should ever see WE or SET_TAG
  ----------------------------------------------------------------------------
  we_0      <= we_top_global      and en_1hot(0);
  set_tag_0 <= set_tag_top_global and en_1hot(0);

  we_1      <= we_top_global      and en_1hot(1);
  set_tag_1 <= set_tag_top_global and en_1hot(1);

  we_2      <= we_top_global      and en_1hot(2);
  set_tag_2 <= set_tag_top_global and en_1hot(2);

  we_3      <= we_top_global      and en_1hot(3);
  set_tag_3 <= set_tag_top_global and en_1hot(3);

end structural;

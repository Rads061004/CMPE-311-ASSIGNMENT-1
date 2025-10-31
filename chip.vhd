library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity chip is
  port (
    cpu_add    : in    std_logic_vector(5 downto 0);   -- [5:4]=tag, [3:2]=idx, [1:0]=byte
    cpu_data   : inout std_logic_vector(7 downto 0);   -- bidirectional CPU bus
    cpu_rd_wrn : in    std_logic;                      -- '1' = read, '0' = write
    start      : in    std_logic;                      -- request strobe
    clk        : in    std_logic;
    reset      : in    std_logic;

    mem_data   : in    std_logic_vector(7 downto 0);   -- data from memory
    Vdd        : in    std_logic;                      -- not used in RTL sim, but kept for interface
    Gnd        : in    std_logic;                      -- same

    busy       : out   std_logic;                      -- to CPU
    mem_en     : out   std_logic;                      -- to memory
    mem_add    : out   std_logic_vector(5 downto 0);   -- to memory

    -- Debug ports exported to the TB (will be tied to 0s for now so they are defined)
    fsm_state_dbg      : out std_logic_vector(3 downto 0);
    fsm_next_state_dbg : out std_logic_vector(3 downto 0);
    fsm_counter_dbg    : out std_logic_vector(7 downto 0)
  );
end chip;

architecture structural of chip is

  --------------------------------------------------------------------------
  -- Address field breakout
  --------------------------------------------------------------------------
  signal tag_in    : std_logic_vector(1 downto 0);
  signal idx       : std_logic_vector(1 downto 0);
  signal byte_sel  : std_logic_vector(1 downto 0);

  --------------------------------------------------------------------------
  -- Per-index enable from decoder
  --------------------------------------------------------------------------
  component decoder
    port (
      block_addr : in  std_logic_vector(1 downto 0);
      block_sel  : out std_logic_vector(3 downto 0)
    );
  end component;

  signal en_1hot : std_logic_vector(3 downto 0);

  --------------------------------------------------------------------------
  -- Cache block array
  --------------------------------------------------------------------------
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
      hit_miss   : out std_logic
    );
  end component;

  signal d0, d1, d2, d3 : std_logic_vector(7 downto 0);
  signal v0, v1, v2, v3 : std_logic;
  signal t0, t1, t2, t3 : std_logic_vector(1 downto 0);
  signal h0, h1, h2, h3 : std_logic;

  --------------------------------------------------------------------------
  -- Small muxes
  --------------------------------------------------------------------------
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

  --------------------------------------------------------------------------
  -- FSM
  -- NOTE: cache_fsm_struct *already exists* in your project,
  -- but we are NOT declaring/connecting the debug ports here
  -- (Cadence choked on width mismatch). We'll let Cadence warn
  -- that those debug ports are unused inside the FSM.
  --------------------------------------------------------------------------
  component cache_fsm_struct
    port (
      clk        : in  std_logic;
      reset      : in  std_logic;
      start      : in  std_logic;
      tag        : in  std_logic;   -- we drive "hit_sel" (stable 0/1)
      valid      : in  std_logic;   -- valid bit from selected block
      read_write : in  std_logic;   -- cpu_rd_wrn

      busy       : out std_logic;   -- registered busy to CPU
      done       : out std_logic;
      en         : out std_logic;   -- mem_en
      OE_CD      : out std_logic;   -- output-enable for cpu_data
      OE_MA      : out std_logic    -- (exists in your earlier code)
      -- STATE_DBG, NEXT_STATE_DBG, COUNTER_DBG
      -- are intentionally NOT declared here to avoid
      -- width mismatch errors
    );
  end component;

  signal fsm_done  : std_logic;
  signal fsm_OEcd  : std_logic;
  signal fsm_OEma  : std_logic;
  signal fsm_en    : std_logic;

  --------------------------------------------------------------------------
  -- Write/refill control bookkeeping
  --------------------------------------------------------------------------
  signal we_top        : std_logic := '0';
  signal set_tag_top   : std_logic := '0';

  signal latch_go      : std_logic := '0';
  signal L_is_write    : std_logic := '0';
  signal L_is_hit      : std_logic := '0';

  signal mem_en_q      : std_logic := '0';
  signal refill_cnt    : integer range 0 to 31 := 0;
  signal refill_active : std_logic := '0';

  --------------------------------------------------------------------------
  -- CPU bus drive
  --------------------------------------------------------------------------
  signal cpu_do : std_logic_vector(7 downto 0);

  --------------------------------------------------------------------------
  -- Muxed per-index selects
  --------------------------------------------------------------------------
  signal data_sel   : std_logic_vector(7 downto 0);
  signal valid_sel  : std_logic;
  signal hit_sel    : std_logic;  -- stable per-index hit info

begin
  --------------------------------------------------------------------------
  -- Address splits
  --------------------------------------------------------------------------
  tag_in   <= cpu_add(5 downto 4);
  idx      <= cpu_add(3 downto 2);
  byte_sel <= cpu_add(1 downto 0);

  --------------------------------------------------------------------------
  -- Index decoder
  --------------------------------------------------------------------------
  u_dec: decoder
    port map (
      block_addr => idx,
      block_sel  => en_1hot
    );

  --------------------------------------------------------------------------
  -- Cache blocks (4 lines of direct-mapped cache)
  --------------------------------------------------------------------------
  u_cb0: cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(0),

      data_in    => cpu_data,
      data_out   => d0,
      byte_sel   => byte_sel,
      rd_wr      => cpu_rd_wrn,

      mem_in     => mem_data,

      we         => we_top,
      set_tag    => set_tag_top,
      tag_in     => tag_in,

      valid_out  => v0,
      tag_out    => t0,
      hit_miss   => h0
    );

  u_cb1: cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(1),

      data_in    => cpu_data,
      data_out   => d1,
      byte_sel   => byte_sel,
      rd_wr      => cpu_rd_wrn,

      mem_in     => mem_data,

      we         => we_top,
      set_tag    => set_tag_top,
      tag_in     => tag_in,

      valid_out  => v1,
      tag_out    => t1,
      hit_miss   => h1
    );

  u_cb2: cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(2),

      data_in    => cpu_data,
      data_out   => d2,
      byte_sel   => byte_sel,
      rd_wr      => cpu_rd_wrn,

      mem_in     => mem_data,

      we         => we_top,
      set_tag    => set_tag_top,
      tag_in     => tag_in,

      valid_out  => v2,
      tag_out    => t2,
      hit_miss   => h2
    );

  u_cb3: cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(3),

      data_in    => cpu_data,
      data_out   => d3,
      byte_sel   => byte_sel,
      rd_wr      => cpu_rd_wrn,

      mem_in     => mem_data,

      we         => we_top,
      set_tag    => set_tag_top,
      tag_in     => tag_in,

      valid_out  => v3,
      tag_out    => t3,
      hit_miss   => h3
    );

  --------------------------------------------------------------------------
  -- Per-index muxes for data / valid / hit
  --------------------------------------------------------------------------
  u_mux_data : mux4to1_8
    port map (
      d0  => d0,
      d1  => d1,
      d2  => d2,
      d3  => d3,
      sel => idx,
      y   => data_sel
    );

  u_mux_valid : mux4to1_1
    port map (
      d0  => v0,
      d1  => v1,
      d2  => v2,
      d3  => v3,
      sel => idx,
      y   => valid_sel
    );

  u_mux_hit : mux4to1_1
    port map (
      d0  => h0,
      d1  => h1,
      d2  => h2,
      d3  => h3,
      sel => idx,
      y   => hit_sel      -- "is this a hit on the selected line?"
    );

  --------------------------------------------------------------------------
  -- FSM instance
  -- We feed it stable 0/1 request qualifiers:
  --   tag    <= hit_sel (is it a hit?),
  --   valid  <= valid_sel,
  --   read_write <= cpu_rd_wrn
  --
  -- We are *not* binding STATE_DBG/etc. so we avoid width mismatch.
  --------------------------------------------------------------------------
  u_fsm: cache_fsm_struct
    port map (
      clk        => clk,
      reset      => reset,
      start      => start,
      tag        => hit_sel,
      valid      => valid_sel,
      read_write => cpu_rd_wrn,

      busy       => busy,
      done       => fsm_done,
      en         => fsm_en,
      OE_CD      => fsm_OEcd,
      OE_MA      => fsm_OEma
    );
    -- Any internal FSM debug outputs that exist in the real
    -- cache_fsm_struct will just be unconnected -> Cadence will warn,
    -- but not error.

  --------------------------------------------------------------------------
  -- External memory interface
  --------------------------------------------------------------------------
  mem_en  <= fsm_en;
  mem_add <= cpu_add(5 downto 2) & "00";

  --------------------------------------------------------------------------
  -- Drive CPU bus during read phases (OE controlled by FSM)
  --------------------------------------------------------------------------
  cpu_do   <= data_sel;
  cpu_data <= cpu_do when fsm_OEcd = '1' else (others => 'Z');

  --------------------------------------------------------------------------
  -- Latch request classification for write-hit pulse generation
  --------------------------------------------------------------------------
  process(clk)
  begin
    if falling_edge(clk) then
      if reset = '1' then
        latch_go   <= '0';
        L_is_write <= '0';
        L_is_hit   <= '0';
      else
        latch_go   <= start;
        if start = '1' then
          L_is_write <= not cpu_rd_wrn;
          L_is_hit   <= hit_sel;
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Track refill window from mem_en
  --------------------------------------------------------------------------
  process(clk)
  begin
    if falling_edge(clk) then
      if reset = '1' then
        mem_en_q      <= '0';
        refill_active <= '0';
        refill_cnt    <= 0;
      else
        mem_en_q <= fsm_en;

        if (mem_en_q = '0' and fsm_en = '1') then
          refill_active <= '1';
          refill_cnt    <= 0;
        elsif refill_active = '1' then
          refill_cnt <= refill_cnt + 1;
          if refill_cnt >= 16 then
            refill_active <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Generate write pulses:
  --   (1) write-hit: 1-cycle pulse into the selected block
  --   (2) refill bytes: pulses on specific refill_cnt values
  --------------------------------------------------------------------------
  process(clk)
    variable we_pulse      : std_logic;
    variable set_tag_pulse : std_logic;
  begin
    if falling_edge(clk) then
      if reset = '1' then
        we_top      <= '0';
        set_tag_top <= '0';
      else
        we_pulse      := '0';
        set_tag_pulse := '0';

        -- write-hit pulse (write hit = internal store into cache line)
        if (latch_go = '1') and
           (L_is_write = '1') and
           (L_is_hit   = '1') then
          we_pulse := '1';
        end if;

        -- refill-driven pulses (mem refill writing DE AD BE EF, etc.)
        if refill_active = '1' then
          if (refill_cnt = 8) or (refill_cnt = 10) or
             (refill_cnt = 12) or (refill_cnt = 14) then
            we_pulse := '1';
            if refill_cnt = 8 then
              set_tag_pulse := '1';
            end if;
          end if;
        end if;

        we_top      <= we_pulse;
        set_tag_top <= set_tag_pulse;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Tie off exported debug signals to known values so they are not 'U'
  -- (they're just placeholders for now to avoid width-mismatch fatal errors)
  --------------------------------------------------------------------------
  fsm_state_dbg      <= (others => '0');
  fsm_next_state_dbg <= (others => '0');
  fsm_counter_dbg    <= (others => '0');

end structural;

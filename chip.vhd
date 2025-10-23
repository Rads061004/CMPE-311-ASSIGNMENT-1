library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity chip is
  port (
    cpu_add    : in    std_logic_vector(5 downto 0);  -- [5:4]=tag, [3:2]=index, [1:0]=byte
    cpu_data   : inout std_logic_vector(7 downto 0);
    cpu_rd_wrn : in    std_logic;                     -- 1=read, 0=write
    start      : in    std_logic;
    clk        : in    std_logic;
    reset      : in    std_logic;

    mem_data   : in    std_logic_vector(7 downto 0);
    Vdd        : in    std_logic;  -- unused pads
    Gnd        : in    std_logic,  -- unused pads

    busy       : out   std_logic,
    mem_en     : out   std_logic,
    mem_add    : out   std_logic_vector(5 downto 0)
  );
end chip;

architecture structural of chip is
  --------------------------------------------------------------------------
  -- Address fields
  --------------------------------------------------------------------------
  signal tag_in    : std_logic_vector(1 downto 0);
  signal idx       : std_logic_vector(1 downto 0);
  signal byte_sel  : std_logic_vector(1 downto 0);

  --------------------------------------------------------------------------
  -- Decoder (index -> one-hot enable)
  --------------------------------------------------------------------------
  component decoder
    port ( block_addr : in  std_logic_vector(1 downto 0);
           block_sel  : out std_logic_vector(3 downto 0) );
  end component;

  signal en_1hot   : std_logic_vector(3 downto 0);

  --------------------------------------------------------------------------
  -- Cache line (your cache_block with internal src selection)
  --------------------------------------------------------------------------
  component cache_block
    port (
      clk, reset   : in  std_logic;
      enable       : in  std_logic;

      data_in      : in  std_logic_vector(7 downto 0);
      data_out     : out std_logic_vector(7 downto 0);
      byte_sel     : in  std_logic_vector(1 downto 0);
      rd_wr        : in  std_logic;

      mem_in       : in  std_logic_vector(7 downto 0);

      we           : in  std_logic;
      set_tag      : in  std_logic;
      tag_in       : in  std_logic_vector(1 downto 0);

      valid_out    : out std_logic;
      tag_out      : out std_logic_vector(1 downto 0);
      hit_miss     : out std_logic
    );
  end component;

  -- Per-line signals
  signal d0,d1,d2,d3  : std_logic_vector(7 downto 0);
  signal v0,v1,v2,v3  : std_logic;
  signal t0,t1,t2,t3  : std_logic_vector(1 downto 0);
  signal h0,h1,h2,h3  : std_logic;

  -- Selected line
  signal data_sel     : std_logic_vector(7 downto 0);
  signal valid_sel    : std_logic;
  signal hit_sel      : std_logic;

  --------------------------------------------------------------------------
  -- Existing FSM (unchanged interface you gave me)
  --------------------------------------------------------------------------
  component cache_fsm_struct
    port (
      clk        : in  std_logic;
      reset      : in  std_logic;
      start      : in  std_logic;
      tag        : in  std_logic;      -- we feed tag-compare result here
      valid      : in  std_logic;      -- we feed selected valid here
      read_write : in  std_logic;      -- cpu_rd_wrn
      busy       : out std_logic;
      done       : out std_logic;
      en         : out std_logic;      -- memory enable
      OE_CD      : out std_logic;      -- drive to CPU data bus
      OE_MA      : out std_logic       -- not used outside; optional probe
    );
  end component;

  signal fsm_done  : std_logic;
  signal fsm_OEcd  : std_logic;
  signal fsm_OEma  : std_logic;
  signal fsm_en    : std_logic;

  --------------------------------------------------------------------------
  -- Top-level generation of WE and SET_TAG (no changes to FSM)
  --------------------------------------------------------------------------
  signal we_top        : std_logic := '0';
  signal set_tag_top   : std_logic := '0';

  -- For write-hit pulse
  signal latch_go      : std_logic := '0';
  signal L_is_write    : std_logic := '0';
  signal L_is_hit      : std_logic := '0';

  -- For read-miss refill timing after mem_en assertion
  signal mem_en_q      : std_logic := '0';
  signal refill_cnt    : integer range 0 to 31 := 0;
  signal refill_active : std_logic := '0';

  -- CPU data bus out
  signal cpu_do        : std_logic_vector(7 downto 0) := (others => '0');

begin
  --------------------------------------------------------------------------
  -- Field split & decoder
  --------------------------------------------------------------------------
  tag_in   <= cpu_add(5 downto 4);
  idx      <= cpu_add(3 downto 2);
  byte_sel <= cpu_add(1 downto 0);

  u_dec: decoder port map(block_addr => idx, block_sel => en_1hot);

  --------------------------------------------------------------------------
  -- 4 cache lines
  --------------------------------------------------------------------------
  u_cb0: cache_block
    port map (
      clk => clk, reset => reset,
      enable   => en_1hot(0),
      data_in  => cpu_data, data_out => d0, byte_sel => byte_sel, rd_wr => cpu_rd_wrn,
      mem_in   => mem_data,
      we       => we_top,
      set_tag  => set_tag_top,
      tag_in   => tag_in,
      valid_out=> v0, tag_out => t0, hit_miss => h0
    );

  u_cb1: cache_block
    port map (clk => clk, reset => reset, enable => en_1hot(1),
      data_in => cpu_data, data_out => d1, byte_sel => byte_sel, rd_wr => cpu_rd_wrn,
      mem_in => mem_data, we => we_top, set_tag => set_tag_top, tag_in => tag_in,
      valid_out => v1, tag_out => t1, hit_miss => h1);

  u_cb2: cache_block
    port map (clk => clk, reset => reset, enable => en_1hot(2),
      data_in => cpu_data, data_out => d2, byte_sel => byte_sel, rd_wr => cpu_rd_wrn,
      mem_in => mem_data, we => we_top, set_tag => set_tag_top, tag_in => tag_in,
      valid_out => v2, tag_out => t2, hit_miss => h2);

  u_cb3: cache_block
    port map (clk => clk, reset => reset, enable => en_1hot(3),
      data_in => cpu_data, data_out => d3, byte_sel => byte_sel, rd_wr => cpu_rd_wrn,
      mem_in => mem_data, we => we_top, set_tag => set_tag_top, tag_in => tag_in,
      valid_out => v3, tag_out => t3, hit_miss => h3);

  -- select meta/data by index
  with idx select data_sel  <= d0 when "00", d1 when "01", d2 when "10", d3 when "11", (others=>'0') when others;
  with idx select valid_sel <= v0 when "00", v1 when "01", v2 when "10", v3 when "11", '0' when others;
  with idx select hit_sel   <= h0 when "00", h1 when "01", h2 when "10", h3 when "11", '0' when others;

  --------------------------------------------------------------------------
  -- Existing FSM (we feed it the selected tag/valid)
  --------------------------------------------------------------------------
  u_fsm: cache_fsm_struct
    port map (
      clk        => clk,
      reset      => reset,
      start      => start,
      tag        => (tag_in = (t0 when idx="00" else t1 when idx="01" else t2 when idx="10" else t3)), -- tag compare
      valid      => valid_sel,
      read_write => cpu_rd_wrn,
      busy       => busy,
      done       => fsm_done,
      en         => fsm_en,
      OE_CD      => fsm_OEcd,
      OE_MA      => fsm_OEma
    );

  -- Expose memory handshake externally
  mem_en  <= fsm_en;
  mem_add <= cpu_add(5 downto 2) & "00";  -- last two bits are 00 per board spec

  --------------------------------------------------------------------------
  -- Drive CPU data bus only when FSM says so
  --------------------------------------------------------------------------
  cpu_do   <= data_sel;
  cpu_data <= cpu_do when fsm_OEcd = '1' else (others => 'Z');

  --------------------------------------------------------------------------
  -- Generate latch_go on the first negedge after START (for hit/miss classify)
  --------------------------------------------------------------------------
  process(clk)
  begin
    if falling_edge(clk) then
      if reset = '1' then
        latch_go   <= '0';
        L_is_write <= '0';
        L_is_hit   <= '0';
      else
        latch_go   <= start;            -- one-negedge pulse if start was high
        if start = '1' then
          L_is_write <= not cpu_rd_wrn; -- 1 when write
          L_is_hit   <= hit_sel;        -- sample current selected line
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Read-miss refill timing after mem_en goes high
  -- Pulses at 8,10,12,14 negedges after mem_en assertion; set_tag at 8
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

        -- Start counting one negedge after mem_en rises
        if (mem_en_q = '0' and fsm_en = '1') then
          refill_active <= '1';
          refill_cnt    <= 0;
        elsif refill_active = '1' then
          refill_cnt <= refill_cnt + 1;
          -- stop after last refill point
          if refill_cnt >= 16 then
            refill_active <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------
  -- Top-level WE and SET_TAG (registered on negedge for clean pulses)
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
        -- defaults
        we_pulse      := '0';
        set_tag_pulse := '0';

        -- WRITE-HIT: one-cycle we right after start
        if (latch_go = '1') and (L_is_write = '1') and (L_is_hit = '1') then
          we_pulse := '1';
        end if;

        -- READ-MISS refill: mem bytes at 8/10/12/14; set_tag at the first one
        if refill_active = '1' then
          if (refill_cnt = 8) or (refill_cnt = 10) or (refill_cnt = 12) or (refill_cnt = 14) then
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

end structural;

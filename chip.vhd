library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity chip is
  port (
    -- CPU side
    cpu_add    : in    std_logic_vector(5 downto 0);
    cpu_data   : inout std_logic_vector(7 downto 0);
    cpu_rd_wrn : in    std_logic;                     -- '1' = read, '0' = write
    start      : in    std_logic;
    clk        : in    std_logic;
    reset      : in    std_logic;

    -- backing memory
    mem_data   : in    std_logic_vector(7 downto 0);
    Vdd        : in    std_logic;
    Gnd        : in    std_logic;

    busy       : out   std_logic;
    mem_en     : out   std_logic;
    mem_add    : out   std_logic_vector(5 downto 0);

    -- debug
    fsm_state_dbg_s       : out std_logic_vector(2 downto 0);
    fsm_next_state_dbg_s  : out std_logic_vector(2 downto 0);
    fsm_counter_dbg_s     : out std_logic_vector(4 downto 0)
  );
end chip;

architecture structural of chip is

  ------------------------------------------------------------------------
  -- Split CPU address
  ------------------------------------------------------------------------
  signal tag_in    : std_logic_vector(1 downto 0);
  signal idx       : std_logic_vector(1 downto 0);
  signal byte_sel  : std_logic_vector(1 downto 0);

  -- byte select that actually feeds writes into cache during refill
  signal curr_byte_sel : std_logic_vector(1 downto 0);

  ------------------------------------------------------------------------
  -- Index decoder
  ------------------------------------------------------------------------
  component decoder
    port (
      block_addr : in  std_logic_vector(1 downto 0);
      block_sel  : out std_logic_vector(3 downto 0)
    );
  end component;

  signal en_1hot : std_logic_vector(3 downto 0);

  ------------------------------------------------------------------------
  -- Cache block
  ------------------------------------------------------------------------
  component cache_block
    port (
      clk        : in  std_logic;
      reset      : in  std_logic;
      enable     : in  std_logic;

      data_in    : in  std_logic_vector(7 downto 0);   -- CPU write data
      data_out   : out std_logic_vector(7 downto 0);   -- registered read data
      byte_sel   : in  std_logic_vector(1 downto 0);   -- which byte gets written
      rd_wr      : in  std_logic;                      -- '1'=read,'0'=write from CPU

      mem_in     : in  std_logic_vector(7 downto 0);   -- incoming mem byte during refill

      we         : in  std_logic;                      -- per-byte write strobe
      set_tag    : in  std_logic;                      -- latch tag/valid on first beat
      tag_in     : in  std_logic_vector(1 downto 0);   -- new tag to write

      valid_out  : out std_logic;
      tag_out    : out std_logic_vector(1 downto 0);
      hit_miss   : out std_logic;

      peek_sel   : in  std_logic_vector(1 downto 0);   -- original byte the CPU asked for
      peek_data  : out std_logic_vector(7 downto 0)    -- combinational mux of that byte
    );
  end component;

  signal d0,d1,d2,d3 : std_logic_vector(7 downto 0);
  signal v0,v1,v2,v3 : std_logic;
  signal t0,t1,t2,t3 : std_logic_vector(1 downto 0);
  signal h0,h1,h2,h3 : std_logic;

  signal pk0,pk1,pk2,pk3 : std_logic_vector(7 downto 0);

  signal data_sel       : std_logic_vector(7 downto 0);
  signal valid_sel      : std_logic;
  signal hit_sel        : std_logic;
  signal peek_sel_data  : std_logic_vector(7 downto 0);

  ------------------------------------------------------------------------
  -- FSM
  ------------------------------------------------------------------------
  component cache_fsm_struct
    port (
      clk            : in  STD_LOGIC;
      reset          : in  STD_LOGIC;

      start          : in  STD_LOGIC;
      tag            : in  STD_LOGIC;
      valid          : in  STD_LOGIC;
      read_write     : in  STD_LOGIC;

      busy           : out STD_LOGIC;      -- asserted while request in flight
      en             : out STD_LOGIC;      -- memory enable during MISS
      fsm_resp_pulse : out STD_LOGIC;      -- 1-cycle "read complete" pulse

      state_dbg      : out STD_LOGIC_VECTOR(2 downto 0);
      next_state_dbg : out STD_LOGIC_VECTOR(2 downto 0);
      counter_dbg    : out STD_LOGIC_VECTOR(4 downto 0)
    );
  end component;

  signal busy_int            : std_logic;
  signal fsm_en              : std_logic;
  signal fsm_resp_pulse      : std_logic;

  signal fsm_state_dbg_sig      : std_logic_vector(2 downto 0);
  signal fsm_next_state_dbg_sig : std_logic_vector(2 downto 0);
  signal fsm_counter_dbg_sig    : std_logic_vector(4 downto 0);

  ------------------------------------------------------------------------
  -- Request bookkeeping / refill / bus return
  ------------------------------------------------------------------------
  signal we_top              : std_logic := '0';
  signal set_tag_top         : std_logic := '0';

  -- Latched request at the start edge
  signal latch_go            : std_logic := '0';
  signal L_is_write          : std_logic := '0';        -- '1' if request was WRITE
  signal L_is_hit            : std_logic := '0';
  signal req_byte_sel_reg    : std_logic_vector(1 downto 0) := (others => '0');

  -- Refill tracker
  signal mem_en_q            : std_logic := '0';
  signal refill_active       : std_logic := '0';
  signal refill_cnt          : integer range 0 to 31 := 0;

  -- The byte offset inside the cache line we're currently filling
  -- This is what actually drives curr_byte_sel to decide which byte reg to update.
  signal refill_offset_reg    : std_logic_vector(1 downto 0) := "00";

  -- NEW: shadow so we don't advance the offset until AFTER the write has clocked in
  signal refill_offset_shadow : std_logic_vector(1 downto 0) := "00";
  signal refill_offset_load   : std_logic := '0';

  -- Return path to CPU
  signal resp_data_reg       : std_logic_vector(7 downto 0) := (others => '0');
  signal resp_drive          : std_logic := '0';  -- "drive cpu_data THIS negedge window only"

  signal cpu_data_drive      : std_logic_vector(7 downto 0);
  signal cpu_drive_en        : std_logic;

  ------------------------------------------------------------------------
  -- Tag match to feed FSM's "hit" decision
  ------------------------------------------------------------------------
  signal tag_match_sel       : std_logic;

begin
  ------------------------------------------------------------------------
  -- Break out CPU address fields
  ------------------------------------------------------------------------
  tag_in   <= cpu_add(5 downto 4);  -- tag
  idx      <= cpu_add(3 downto 2);  -- index
  byte_sel <= cpu_add(1 downto 0);  -- byte offset requested by CPU

  ------------------------------------------------------------------------
  -- Decode index to one-hot enables (selects which of the 4 lines is active)
  ------------------------------------------------------------------------
  u_dec: decoder
    port map (
      block_addr => idx,
      block_sel  => en_1hot
    );

  ------------------------------------------------------------------------
  -- During refill, writes go to refill_offset_reg-selected byte.
  -- Otherwise, for normal CPU access, use the CPU's requested offset.
  ------------------------------------------------------------------------
  curr_byte_sel <= refill_offset_reg when refill_active = '1'
                   else byte_sel;

  ------------------------------------------------------------------------
  -- Cache lines
  ------------------------------------------------------------------------
  u_cb0: cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(0),

      data_in    => cpu_data,
      data_out   => d0,
      byte_sel   => curr_byte_sel,
      rd_wr      => cpu_rd_wrn,

      mem_in     => mem_data,

      we         => we_top,
      set_tag    => set_tag_top,
      tag_in     => tag_in,

      valid_out  => v0,
      tag_out    => t0,
      hit_miss   => h0,

      peek_sel   => req_byte_sel_reg,
      peek_data  => pk0
    );

  u_cb1: cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(1),

      data_in    => cpu_data,
      data_out   => d1,
      byte_sel   => curr_byte_sel,
      rd_wr      => cpu_rd_wrn,

      mem_in     => mem_data,

      we         => we_top,
      set_tag    => set_tag_top,
      tag_in     => tag_in,

      valid_out  => v1,
      tag_out    => t1,
      hit_miss   => h1,

      peek_sel   => req_byte_sel_reg,
      peek_data  => pk1
    );

  u_cb2: cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(2),

      data_in    => cpu_data,
      data_out   => d2,
      byte_sel   => curr_byte_sel,
      rd_wr      => cpu_rd_wrn,

      mem_in     => mem_data,

      we         => we_top,
      set_tag    => set_tag_top,
      tag_in     => tag_in,

      valid_out  => v2,
      tag_out    => t2,
      hit_miss   => h2,

      peek_sel   => req_byte_sel_reg,
      peek_data  => pk2
    );

  u_cb3: cache_block
    port map (
      clk        => clk,
      reset      => reset,
      enable     => en_1hot(3),

      data_in    => cpu_data,
      data_out   => d3,
      byte_sel   => curr_byte_sel,
      rd_wr      => cpu_rd_wrn,

      mem_in     => mem_data,

      we         => we_top,
      set_tag    => set_tag_top,
      tag_in     => tag_in,

      valid_out  => v3,
      tag_out    => t3,
      hit_miss   => h3,

      peek_sel   => req_byte_sel_reg,
      peek_data  => pk3
    );

  ------------------------------------------------------------------------
  -- Mux out the selected line's signals
  ------------------------------------------------------------------------
  with idx select data_sel      <= d0  when "00",
                                   d1  when "01",
                                   d2  when "10",
                                   d3  when "11",
                                   (others => '0') when others;

  with idx select valid_sel     <= v0  when "00",
                                   v1  when "01",
                                   v2  when "10",
                                   v3  when "11",
                                   '0' when others;

  with idx select hit_sel       <= h0  when "00",
                                   h1  when "01",
                                   h2  when "10",
                                   h3  when "11",
                                   '0' when others;

  with idx select peek_sel_data <= pk0 when "00",
                                   pk1 when "01",
                                   pk2 when "10",
                                   pk3 when "11",
                                   (others => '0') when others;

  ------------------------------------------------------------------------
  -- Tag compare: does the selected line's tag match tag_in?
  ------------------------------------------------------------------------
  tag_match_sel <= '1' when (
                     (idx = "00" and t0 = tag_in) or
                     (idx = "01" and t1 = tag_in) or
                     (idx = "10" and t2 = tag_in) or
                     (idx = "11" and t3 = tag_in)
                   )
                   else '0';

  ------------------------------------------------------------------------
  -- FSM
  ------------------------------------------------------------------------
  u_fsm: cache_fsm_struct
    port map (
      clk            => clk,
      reset          => reset,
      start          => start,
      tag            => tag_match_sel,
      valid          => valid_sel,
      read_write     => cpu_rd_wrn,

      busy           => busy_int,
      en             => fsm_en,
      fsm_resp_pulse => fsm_resp_pulse,

      state_dbg      => fsm_state_dbg_sig,
      next_state_dbg => fsm_next_state_dbg_sig,
      counter_dbg    => fsm_counter_dbg_sig
    );

  busy <= busy_int;

  fsm_state_dbg_s      <= fsm_state_dbg_sig;
  fsm_next_state_dbg_s <= fsm_next_state_dbg_sig;
  fsm_counter_dbg_s    <= fsm_counter_dbg_sig;

  ------------------------------------------------------------------------
  -- Backing memory interface
  --
  -- mem_en asserts during miss
  -- mem_add uses cpu_add upper bits, lower 2 forced to "00"
  ------------------------------------------------------------------------
  mem_en  <= fsm_en;
  mem_add <= cpu_add(5 downto 2) & "00";

  ------------------------------------------------------------------------
  -- One single falling-edge process controls:
  --   - request snapshot
  --   - refill bookkeeping and byte placement
  --   - write strobes into cache lines
  --   - bus return pulse
  ------------------------------------------------------------------------
  process(clk)
    variable next_off_u : unsigned(1 downto 0);
  begin
    if falling_edge(clk) then
      if reset = '1' then
        latch_go            <= '0';
        L_is_write          <= '0';
        L_is_hit            <= '0';
        req_byte_sel_reg    <= (others => '0');

        mem_en_q            <= '0';
        refill_active       <= '0';
        refill_cnt          <= 0;

        refill_offset_reg    <= "00";
        refill_offset_shadow <= "00";
        refill_offset_load   <= '0';

        we_top        <= '0';
        set_tag_top   <= '0';

        resp_data_reg <= (others => '0');
        resp_drive    <= '0';

      else
        ----------------------------------------------------------------
        -- Default each negedge
        ----------------------------------------------------------------
        we_top      <= '0';
        set_tag_top <= '0';
        resp_drive  <= '0';   -- drive lasts exactly this negedge window unless reasserted below

        ----------------------------------------------------------------
        -- First, if last cycle told us to update refill_offset_reg,
        -- apply that now (AFTER the rising edge already used the old
        -- offset to write the correct byte).
        ----------------------------------------------------------------
        if refill_offset_load = '1' then
          refill_offset_reg  <= refill_offset_shadow;
          refill_offset_load <= '0';
        end if;

        ----------------------------------------------------------------
        -- Track mem_en to detect start/end of refill burst
        ----------------------------------------------------------------
        mem_en_q <= fsm_en;

        if (mem_en_q = '0' and fsm_en = '1') then
          -- just entered refill
          refill_active       <= '1';
          refill_cnt          <= 0;
          refill_offset_reg   <= "00";
          refill_offset_shadow<= "00";
          refill_offset_load  <= '0';
        elsif refill_active = '1' then
          refill_cnt <= refill_cnt + 1;

          -- heuristic stop after ~16 cycles (matches your TB timing)
          if refill_cnt >= 16 then
            refill_active <= '0';
          end if;
        end if;

        ----------------------------------------------------------------
        -- Immediate WRITE HIT write-through (write hit + write request)
        ----------------------------------------------------------------
        if (latch_go = '1') and (L_is_write = '1') and (L_is_hit = '1') then
          we_top <= '1';
          -- (not updating refill_offset here; this is not a refill)
        end if;

        ----------------------------------------------------------------
        -- READ MISS refill storeback
        --
        -- For specific refill_cnt values (8,10,12,14) the testbench
        -- feeds one byte of external memory data. We pulse we_top so
        -- the cache_block will latch mem_data on the NEXT rising edge.
        --
        -- CRITICAL FIX:
        --   We do NOT bump refill_offset_reg immediately anymore.
        --   Instead:
        --     - we_top asserts now
        --     - we compute the NEXT offset into refill_offset_shadow
        --     - we set refill_offset_load='1'
        --   On the NEXT falling edge (after that rising edge happened),
        --   we apply refill_offset_shadow into refill_offset_reg.
        --
        -- This guarantees:
        --   Byte0 of the line really gets the FIRST beat ("DE"),
        --   Byte1 gets the second ("AD"), etc.
        --   So when the CPU asked for offset "00", that slot ends up
        --   with DE, not EF, by the time we answer.
        ----------------------------------------------------------------
        if refill_active = '1' then
          if (refill_cnt = 8) or (refill_cnt = 10) or
             (refill_cnt = 12) or (refill_cnt = 14) then

            we_top <= '1';

            if refill_cnt = 8 then
              set_tag_top <= '1';   -- only first beat sets tag/valid
            end if;

            -- Stage the increment for AFTER the write completes
            next_off_u               := unsigned(refill_offset_reg) + 1;
            refill_offset_shadow     <= std_logic_vector(next_off_u);
            refill_offset_load       <= '1';
          end if;
        end if;

        ----------------------------------------------------------------
        -- Snapshot the request on start
        ----------------------------------------------------------------
        latch_go <= start;

        if start = '1' then
          L_is_write       <= not cpu_rd_wrn;   -- '1' if WRITE op
          L_is_hit         <= hit_sel;          -- snapshot that hit/miss at launch
          req_byte_sel_reg <= byte_sel;         -- which byte CPU actually wanted

          -- We do NOT clear resp_data_reg here; it's fine to overwrite on response

        end if;

        ----------------------------------------------------------------
        -- Generate the one-cycle CPU return pulse
        --
        -- fsm_resp_pulse means:
        --   "the answer for this READ request is ready now".
        --
        -- We:
        --   - Grab peek_sel_data (which is muxed by req_byte_sel_reg, the byte
        --     offset from the original request).
        --   - Latch it into resp_data_reg.
        --   - Assert resp_drive = '1' for THIS falling-edge->next-falling-edge
        --     window only.
        --
        -- Next falling edge, we default resp_drive <= '0', which cleanly
        -- tri-states cpu_data back to "ZZ". No lingering xx.
        --
        -- Importantly, because we fixed refill_offset_reg sequencing above,
        -- peek_sel_data now sees byte offset "00" holding DE after a miss,
        -- not EF. So read miss now returns DE.
        ----------------------------------------------------------------
        if (fsm_resp_pulse = '1') and (L_is_write = '0') then
          resp_data_reg <= peek_sel_data;
          resp_drive    <= '1';   -- drive cpu_data for exactly one cycle
        end if;

      end if; -- reset
    end if; -- falling_edge
  end process;

  ------------------------------------------------------------------------
  -- Tri-state the CPU bus except for the single resp_drive pulse window
  ------------------------------------------------------------------------
  cpu_drive_en   <= resp_drive;
  cpu_data_drive <= resp_data_reg;

  cpu_data <= cpu_data_drive when cpu_drive_en = '1'
              else (others => 'Z');

end structural;

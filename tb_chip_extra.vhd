library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_chip_extra is
end tb_chip_extra;

architecture tb of tb_chip_extra is
  component chip_extra
    port (
      cpu_add    : in    std_logic_vector(5 downto 0);
      cpu_data   : inout std_logic_vector(7 downto 0);
      cpu_rd_wrn : in    std_logic;
      start      : in    std_logic;
      clk        : in    std_logic;
      reset      : in    std_logic;

      mem_data   : in    std_logic_vector(7 downto 0);

      busy       : out   std_logic;
      mem_en     : out   std_logic;
      mem_add    : out   std_logic_vector(5 downto 0)
    );
  end component;

  -- Clock/reset
  signal clk   : std_logic := '0';
  signal reset : std_logic := '1';

  -- CPU interface
  signal cpu_add    : std_logic_vector(5 downto 0) := (others => '0');
  signal cpu_rd_wrn : std_logic := '1';
  signal start      : std_logic := '0';
  signal cpu_data   : std_logic_vector(7 downto 0);
  signal cpu_d_drv  : std_logic_vector(7 downto 0) := (others => '0');
  signal cpu_d_oe   : std_logic := '0';

  -- Memory-side
  signal mem_data   : std_logic_vector(7 downto 0) := (others => '0');
  signal mem_en     : std_logic;
  signal mem_add    : std_logic_vector(5 downto 0);
  signal busy       : std_logic;

  -- Helpers for burst model
  signal mem_en_q      : std_logic := '0';
  signal rd_q          : std_logic := '1';
  signal refill_active : std_logic := '0';
  signal neg_cnt       : integer range 0 to 31 := 0;
  signal refill_case   : integer := 0;

  function U8(i : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(i, 8));
  end;

  function MAKE_ADDR(tag, idx, byt : std_logic_vector(1 downto 0)) return std_logic_vector is
  begin
    return tag & idx & byt;
  end;

  constant B00 : std_logic_vector(1 downto 0) := "00";
  constant B01 : std_logic_vector(1 downto 0) := "01";
  constant B10 : std_logic_vector(1 downto 0) := "10";

  -- Tags/indices
  constant TAG_A : std_logic_vector(1 downto 0) := "11"; -- A
  constant TAG_B : std_logic_vector(1 downto 0) := "01"; -- B
  constant TAG_C : std_logic_vector(1 downto 0) := "10"; -- C
  constant IDX_I : std_logic_vector(1 downto 0) := "10"; -- same index for conflict

begin
  --------------------------------------------------------------------
  -- Clock 10 ns period
  --------------------------------------------------------------------
  clk <= not clk after 5 ns;

  --------------------------------------------------------------------
  -- Tri-state CPU data
  --------------------------------------------------------------------
  cpu_data <= cpu_d_drv when cpu_d_oe = '1' else (others => 'Z');

  --------------------------------------------------------------------
  -- DUT
  --------------------------------------------------------------------
  dut: chip_extra
    port map (
      cpu_add    => cpu_add,
      cpu_data   => cpu_data,
      cpu_rd_wrn => cpu_rd_wrn,
      start      => start,
      clk        => clk,
      reset      => reset,
      mem_data   => mem_data,
      busy       => busy,
      mem_en     => mem_en,
      mem_add    => mem_add
    );

  --------------------------------------------------------------------
  -- Memory model: burst DE/AD/BE/EF at negedge counts 8/10/12/14
  -- after mem_en rises for a READ miss
  --------------------------------------------------------------------
  mem_model : process(clk)
  begin
    if (clk'event and clk='0') then
      mem_en_q <= mem_en;
      rd_q     <= cpu_rd_wrn;

      if (mem_en_q = '0' and mem_en = '1' and rd_q = '1') then
        refill_active <= '1';
        neg_cnt       <= 0;
      elsif refill_active = '1' then
        neg_cnt <= neg_cnt + 1;

        if refill_case = 1 then
          if    neg_cnt = 8  then mem_data <= U8(16#DE#);
          elsif neg_cnt = 10 then mem_data <= U8(16#AD#);
          elsif neg_cnt = 12 then mem_data <= U8(16#BE#);
          elsif neg_cnt = 14 then mem_data <= U8(16#EF#);
          end if;
        end if;

        if neg_cnt >= 16 then
          refill_active <= '0';
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Reset
  --------------------------------------------------------------------
  reset_gen : process
  begin
    wait until clk'event and clk='0';
    wait until clk'event and clk='0';
    reset <= '0';
    wait;
  end process;

  --------------------------------------------------------------------
  -- Watchdog
  --------------------------------------------------------------------
  watchdog : process
  begin
    wait for 5 ms;
    assert false report "Watchdog timeout - TB stuck" severity failure;
  end process;

  --------------------------------------------------------------------
  -- Stimulus: two full sets of (RM, WH, RH, WM)
  --------------------------------------------------------------------
  stim : process
  begin
    wait until reset = '0';
    wait until clk'event and clk='0';

    refill_case <= 1;

    -- make sure DUT is idle
    if busy = '1' then wait until busy = '0'; end if;

    ----------------------------------------------------------------
    -- ====== SET 1: TAG_A / TAG_C ======
    -- (1) READ MISS  : TAG_A @ IDX_I, byte 00
    ----------------------------------------------------------------
    wait until clk'event and clk='1';
    cpu_add    <= MAKE_ADDR(TAG_A, IDX_I, B00);
    cpu_rd_wrn <= '1';
    cpu_d_oe   <= '0';
    start      <= '1';
    wait until clk'event and clk='1';
    start      <= '0';
    if busy = '0' then wait until busy = '1'; end if;
    wait until busy = '0';
    wait until clk'event and clk='1';

    ----------------------------------------------------------------
    -- (2) WRITE HIT  : TAG_A @ IDX_I, byte 01, data A5
    ----------------------------------------------------------------
    if busy = '1' then wait until busy = '0'; end if;
    wait until clk'event and clk='1';
    cpu_add    <= MAKE_ADDR(TAG_A, IDX_I, B01);
    cpu_rd_wrn <= '0';
    cpu_d_drv  <= U8(16#A5#);
    cpu_d_oe   <= '1';
    start      <= '1';
    wait until clk'event and clk='1';
    start      <= '0';
    if busy = '0' then wait until busy = '1'; end if;
    wait until busy = '0';
    cpu_d_oe   <= '0';
    wait until clk'event and clk='1';

    ----------------------------------------------------------------
    -- (3) READ HIT   : TAG_A @ IDX_I, byte 01 (expect A5)
    ----------------------------------------------------------------
    if busy = '1' then wait until busy = '0'; end if;
    wait until clk'event and clk='1';
    cpu_add    <= MAKE_ADDR(TAG_A, IDX_I, B01);
    cpu_rd_wrn <= '1';
    cpu_d_oe   <= '0';
    start      <= '1';
    wait until clk'event and clk='1';
    start      <= '0';
    if busy = '0' then wait until busy = '1'; end if;
    wait until busy = '0';
    wait until clk'event and clk='1';

    ----------------------------------------------------------------
    -- (4) WRITE MISS : TAG_C @ IDX_I, byte 10, data 7E
    --      causes refill into LRU way with TAG_C
    ----------------------------------------------------------------
    if busy = '1' then wait until busy = '0'; end if;
    wait until clk'event and clk='1';
    cpu_add    <= MAKE_ADDR(TAG_C, IDX_I, B10);
    cpu_rd_wrn <= '0';
    cpu_d_drv  <= U8(16#7E#);
    cpu_d_oe   <= '1';
    start      <= '1';
    wait until clk'event and clk='1';
    start      <= '0';
    if busy = '0' then wait until busy = '1'; end if;
    wait until busy = '0';
    cpu_d_oe   <= '0';
    wait until clk'event and clk='1';

    ----------------------------------------------------------------
    -- ====== SET 2: TAG_B / TAG_C ======
    -- (5) READ MISS  : TAG_B @ IDX_I, byte 00
    --      B is a new tag at same index -> second miss
    ----------------------------------------------------------------
    if busy = '1' then wait until busy = '0'; end if;
    wait until clk'event and clk='1';
    cpu_add    <= MAKE_ADDR(TAG_B, IDX_I, B00);
    cpu_rd_wrn <= '1';
    cpu_d_oe   <= '0';
    start      <= '1';
    wait until clk'event and clk='1';
    start      <= '0';
    if busy = '0' then wait until busy = '1'; end if;
    wait until busy = '0';
    wait until clk'event and clk='1';

    ----------------------------------------------------------------
    -- (6) WRITE HIT  : TAG_B @ IDX_I, byte 01, data A5
    ----------------------------------------------------------------
    if busy = '1' then wait until busy = '0'; end if;
    wait until clk'event and clk='1';
    cpu_add    <= MAKE_ADDR(TAG_B, IDX_I, B01);
    cpu_rd_wrn <= '0';
    cpu_d_drv  <= U8(16#A5#);
    cpu_d_oe   <= '1';
    start      <= '1';
    wait until clk'event and clk='1';
    start      <= '0';
    if busy = '0' then wait until busy = '1'; end if;
    wait until busy = '0';
    cpu_d_oe   <= '0';
    wait until clk'event and clk='1';

    ----------------------------------------------------------------
    -- (7) READ HIT   : TAG_B @ IDX_I, byte 01
    ----------------------------------------------------------------
    if busy = '1' then wait until busy = '0'; end if;
    wait until clk'event and clk='1';
    cpu_add    <= MAKE_ADDR(TAG_B, IDX_I, B01);
    cpu_rd_wrn <= '1';
    cpu_d_oe   <= '0';
    start      <= '1';
    wait until clk'event and clk='1';
    start      <= '0';
    if busy = '0' then wait until busy = '1'; end if;
    wait until busy = '0';
    wait until clk'event and clk='1';

    ----------------------------------------------------------------
    -- (8) WRITE MISS : TAG_C @ IDX_I, byte 10, data 7E
    --      another write miss to same index, exercising LRU again
    ----------------------------------------------------------------
    if busy = '1' then wait until busy = '0'; end if;
    wait until clk'event and clk='1';
    cpu_add    <= MAKE_ADDR(TAG_C, IDX_I, B10);
    cpu_rd_wrn <= '0';
    cpu_d_drv  <= U8(16#7E#);
    cpu_d_oe   <= '1';
    start      <= '1';
    wait until clk'event and clk='1';
    start      <= '0';
    if busy = '0' then wait until busy = '1'; end if;
    wait until busy = '0';
    cpu_d_oe   <= '0';

    ----------------------------------------------------------------
    -- Let things settle a bit
    ----------------------------------------------------------------
    for i in 0 to 20 loop
      wait until clk'event and clk='1';
    end loop;

    assert false report "Simulation finished." severity failure;
  end process;

end tb;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity chip_tb is
end chip_tb;

architecture tb of chip_tb is

  ----------------------------------------------------------------
  -- DUT component
  ----------------------------------------------------------------
  component chip
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
  end component;

  ----------------------------------------------------------------
  -- Testbench signals
  ----------------------------------------------------------------
  signal clk   : std_logic := '0';
  signal reset : std_logic := '0';

  signal cpu_add    : std_logic_vector(5 downto 0) := (others => '0');
  signal cpu_rd_wrn : std_logic := '1';  -- '1' = read, '0' = write
  signal start      : std_logic := '0';

  -- bidirectional CPU data bus modeling
  signal cpu_data    : std_logic_vector(7 downto 0);
  signal cpu_d_drv   : std_logic_vector(7 downto 0) := (others => '0');
  signal cpu_d_oe    : std_logic := '0';

  -- memory-side signals
  signal mem_data    : std_logic_vector(7 downto 0) := (others => '0');
  signal mem_en      : std_logic;
  signal mem_add     : std_logic_vector(5 downto 0);
  signal busy        : std_logic;

  -- supplies
  signal Vdd         : std_logic := '1';
  signal Gnd         : std_logic := '0';

  -- memory timing model helper regs
  signal mem_en_q      : std_logic := '0';
  signal rd_q          : std_logic := '1';
  signal refill_active : std_logic := '0';
  signal neg_cnt       : integer range 0 to 31 := 0;
  signal refill_case   : integer := 0;

  ----------------------------------------------------------------
  -- Small helpers (same as before)
  ----------------------------------------------------------------
  function U8(i : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(i, 8));
  end;

  -- Convenience address constructor: {tag, idx, byte}
  function A(tag, idx, byt : std_logic_vector(1 downto 0))
           return std_logic_vector is
  begin
    -- cpu_add is 6 bits: [5:4] tag, [3:2] idx, [1:0] byte
    return tag & idx & byt;
  end;

begin
  ----------------------------------------------------------------
  -- Instantiate DUT
  ----------------------------------------------------------------
  dut: chip
    port map (
      cpu_add    => cpu_add,
      cpu_data   => cpu_data,
      cpu_rd_wrn => cpu_rd_wrn,
      start      => start,
      clk        => clk,
      reset      => reset,

      mem_data   => mem_data,
      Vdd        => Vdd,
      Gnd        => Gnd,

      busy       => busy,
      mem_en     => mem_en,
      mem_add    => mem_add
    );

  ----------------------------------------------------------------
  -- 100 MHz-ish clock (10 ns period)
  ----------------------------------------------------------------
  clk <= not clk after 5 ns;

  ----------------------------------------------------------------
  -- CPU driving the bidirectional bus during writes
  ----------------------------------------------------------------
  cpu_data <= cpu_d_drv when cpu_d_oe = '1' else (others => 'Z');

  ----------------------------------------------------------------
  -- Very simple memory model:
  --   - watches mem_en rising edge during a READ
  --   - after that, on each falling edge, counts neg edges
  --   - on count 8/10/12/14, returns bytes DE/AD/BE/EF (for refill_case=1)
  ----------------------------------------------------------------
  mem_model : process(clk)
  begin
    if falling_edge(clk) then
      mem_en_q <= mem_en;
      rd_q     <= cpu_rd_wrn;

      -- detect new memory read transaction
      if (mem_en_q = '0' and mem_en = '1' and rd_q = '1') then
        refill_active <= '1';
        neg_cnt       <= 0;
      elsif refill_active = '1' then
        neg_cnt <= neg_cnt + 1;

        if refill_case = 1 then
          case neg_cnt is
            when 8  => mem_data <= U8(16#DE#);
            when 10 => mem_data <= U8(16#AD#);
            when 12 => mem_data <= U8(16#BE#);
            when 14 => mem_data <= U8(16#EF#);
            when others => null;
          end case;
        end if;

        if neg_cnt >= 16 then
          refill_active <= '0';
        end if;
      end if;
    end if;
  end process;

  ----------------------------------------------------------------
  -- Watchdog: kill sim if it hangs
  ----------------------------------------------------------------
  watchdog : process
  begin
    wait for 5 ms;
    assert false report "Watchdog timeout - TB stuck" severity failure;
  end process;

  ----------------------------------------------------------------
  -- Main stimulus
  --
  -- ORDER (new):
  --   1. write hit    (actually first write request; cache cold so it might behave like miss,
  --                    but this exercises the write-hit path first)
  --   2. read hit     (same line/byte we just wrote)
  --   3. write miss   (different tag, same index)
  --   4. read miss    (causes refill from memory model)
  ----------------------------------------------------------------
  stim : process
    -- constants for address fields
    constant TAG_HIT  : std_logic_vector(1 downto 0) := "11";  -- tag that we'll keep reusing
    constant IDX_HIT  : std_logic_vector(1 downto 0) := "10";  -- index we'll hammer
    constant B00      : std_logic_vector(1 downto 0) := "00";
    constant B01      : std_logic_vector(1 downto 0) := "01";
    constant B10      : std_logic_vector(1 downto 0) := "10";

    ----------------------------------------------------------------
    -- wait_cycles(N): wait N rising edges of clk
    ----------------------------------------------------------------
    procedure wait_cycles(n : in integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end;

    ----------------------------------------------------------------
    -- wait_busy_rise(max_cycles):
    --   wait until busy='1' or assert fail
    ----------------------------------------------------------------
    procedure wait_busy_rise(max_cycles : in integer) is
      variable seen : boolean := false;
    begin
      for i in 0 to max_cycles loop
        if busy = '1' then
          seen := true;
          exit;
        end if;
        wait until rising_edge(clk);
      end loop;
      assert seen report "Timeout waiting for busy=1" severity failure;
    end;

    ----------------------------------------------------------------
    -- wait_busy_fall(max_cycles):
    --   wait until busy='0' or assert fail
    ----------------------------------------------------------------
    procedure wait_busy_fall(max_cycles : in integer) is
      variable seen : boolean := false;
    begin
      for i in 0 to max_cycles loop
        if busy = '0' then
          seen := true;
          exit;
        end if;
        wait until rising_edge(clk);
      end loop;
      assert seen report "Timeout waiting for busy=0" severity failure;
    end;

    ----------------------------------------------------------------
    -- req(tag, idx, byt, rd, wdat):
    --   drives a CPU request transaction
    --   rd='1' => read, rd='0' => write with wdat on cpu_data
    --   handshake:
    --     - wait for busy=0
    --     - assert addr/rd_wr/data (for write), pulse start
    --     - wait for busy to go 1 then back to 0
    ----------------------------------------------------------------
    procedure req(
      tag  : in std_logic_vector(1 downto 0);
      idx  : in std_logic_vector(1 downto 0);
      byt  : in std_logic_vector(1 downto 0);
      rd   : in std_logic;  -- '1'=read, '0'=write
      wdat : in std_logic_vector(7 downto 0)) is
    begin
      -- make sure previous op is done
      if busy = '1' then
        wait until busy = '0';
      end if;

      -- line up with falling edge (CPU drives addr/data on posedge,
      -- but our design latches on negedge internally)
      wait until falling_edge(clk);

      cpu_add    <= tag & idx & byt;
      cpu_rd_wrn <= rd;

      if rd = '0' then
        cpu_d_drv <= wdat;
        cpu_d_oe  <= '1';   -- drive bus for write
      else
        cpu_d_oe  <= '0';   -- release bus for read
      end if;

      -- pulse start across posedge/negedge boundary
      start <= '1';
      wait until rising_edge(clk);
      wait until falling_edge(clk);
      start <= '0';

      -- wait for busy handshake
      wait_busy_rise(1000);
      wait_busy_fall(50000);

      -- release bus after write
      cpu_d_oe <= '0';
    end;
  begin
    ------------------------------------------------------------
    -- Global reset sequence
    ------------------------------------------------------------
    reset    <= '1';
    cpu_d_oe <= '0';
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    reset <= '0';
    wait until falling_edge(clk);

    ------------------------------------------------------------
    -- 1) "WRITE HIT" path first
    --    (write to TAG_HIT / IDX_HIT / B01, data A5)
    --    This is the first real transaction after reset.
    ------------------------------------------------------------
    req(TAG_HIT, IDX_HIT, B01, '0', U8(16#A5#));

    ------------------------------------------------------------
    -- 2) READ HIT
    --    read back same byte (TAG_HIT / IDX_HIT / B01)
    ------------------------------------------------------------
    req(TAG_HIT, IDX_HIT, B01, '1', (others => '0'));

    ------------------------------------------------------------
    -- 3) WRITE MISS
    --    different tag ("01"), same index, byte B10,
    --    data 0x7E
    ------------------------------------------------------------
    req("01", IDX_HIT, B10, '0', U8(16#7E#));

    ------------------------------------------------------------
    -- 4) READ MISS
    --    now exercise the refill behavior.
    --    This is where memory model steps in.
    --    We'll set refill_case = 1 to drive DE AD BE EF.
    --
    --    Use TAG_HIT / IDX_HIT / B00 with rd='1'
    ------------------------------------------------------------
    refill_case <= 1;
    req(TAG_HIT, IDX_HIT, B00, '1', (others => '0'));

    ------------------------------------------------------------
    -- let it run a little then end sim
    ------------------------------------------------------------
    wait_cycles(20);
    assert false report "Simulation finished." severity failure;
  end process;

end tb;

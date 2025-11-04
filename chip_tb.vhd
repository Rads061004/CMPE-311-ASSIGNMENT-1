library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity chip_tb is
end chip_tb;

architecture tb of chip_tb is

  -- DUT component
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
      mem_add    : out   std_logic_vector(5 downto 0);

      fsm_state_dbg_s       : out std_logic_vector(2 downto 0);
      fsm_next_state_dbg_s  : out std_logic_vector(2 downto 0);
      fsm_counter_dbg_s     : out std_logic_vector(4 downto 0)
    );
  end component;

  -- Signals
  signal clk   : std_logic := '0';
  signal reset : std_logic := '1';

  signal cpu_add    : std_logic_vector(5 downto 0) := (others => '0');
  signal cpu_rd_wrn : std_logic := '1';  -- '1' = read
  signal start      : std_logic := '0';

  signal cpu_data   : std_logic_vector(7 downto 0);
  signal cpu_d_drv  : std_logic_vector(7 downto 0) := (others => '0');
  signal cpu_d_oe   : std_logic := '0';

  signal mem_data   : std_logic_vector(7 downto 0) := (others => '0');
  signal mem_en     : std_logic;
  signal mem_add    : std_logic_vector(5 downto 0);
  signal busy       : std_logic;

  signal Vdd        : std_logic := '1';
  signal Gnd        : std_logic := '0';

  signal mem_en_q      : std_logic := '0';
  signal rd_q          : std_logic := '1';
  signal refill_active : std_logic := '0';
  signal neg_cnt       : integer range 0 to 31 := 0;
  signal refill_case   : integer := 0;

  -- debug
  signal fsm_state_dbg_s_tb      : std_logic_vector(2 downto 0);
  signal fsm_next_state_dbg_s_tb : std_logic_vector(2 downto 0);
  signal fsm_counter_dbg_s_tb    : std_logic_vector(4 downto 0);

  function U8(i : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(i, 8));
  end U8;

  function MAKE_ADDR(
    tag  : std_logic_vector(1 downto 0);
    idx  : std_logic_vector(1 downto 0);
    byt  : std_logic_vector(1 downto 0)
  ) return std_logic_vector is
  begin
    return tag & idx & byt;
  end MAKE_ADDR;

begin
  -- DUT
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
      mem_add    => mem_add,

      fsm_state_dbg_s       => fsm_state_dbg_s_tb,
      fsm_next_state_dbg_s  => fsm_next_state_dbg_s_tb,
      fsm_counter_dbg_s     => fsm_counter_dbg_s_tb
    );

  -- 10ns period clock
  clk <= not clk after 5 ns;

  -- CPU drives bus only when writing
  cpu_data <= cpu_d_drv when cpu_d_oe = '1' else (others => 'Z');

  -- Memory model / refill data generator
  mem_model : process(clk)
  begin
    if (clk'event and clk='0') then  -- falling edge
      mem_en_q <= mem_en;
      rd_q     <= cpu_rd_wrn;

      -- detect start of new refill (mem_en rising while doing READ)
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

  -- Reset generator
  reset_gen : process
  begin
    -- already '1'
    wait until clk'event and clk='0';
    wait until clk'event and clk='0';
    reset <= '0';
    wait;
  end process;

  watchdog : process
  begin
    wait for 5 ms;
    assert false report "Watchdog timeout - TB stuck" severity failure;
  end process;

  -- Stimulus sequence
  stim : process
    -- constants for addresses
    constant TAG_HIT  : std_logic_vector(1 downto 0) := "11"; 
    constant IDX_HIT  : std_logic_vector(1 downto 0) := "10";
    constant B00      : std_logic_vector(1 downto 0) := "00";
    constant B01      : std_logic_vector(1 downto 0) := "01";
    constant B10      : std_logic_vector(1 downto 0) := "10";
  begin
                                                 
    -- Wait for reset low
    wait until reset = '0';
    -- give one more falling edge to settle
    wait until clk'event and clk='0';

    refill_case <= 1;  

    -- wait for DUT not busy
    if busy = '1' then
      wait until busy = '0';
    end if;

    -- align to POSedge, drive request
    wait until clk'event and clk='1';
    cpu_add    <= MAKE_ADDR(TAG_HIT, IDX_HIT, B00);
    cpu_rd_wrn <= '1';             -- READ
    cpu_d_drv  <= (others => '0'); -- don't-care for read
    cpu_d_oe   <= '0';             -- release bus
    start      <= '1';             -- start pulse

    wait until clk'event and clk='1';
    start      <= '0';

    if busy = '0' then
      wait until busy = '1';
    end if;
                                                 
    wait until busy = '0';

    wait until clk'event and clk='1';

    -- wait for not-busy just in case
    if busy = '1' then
      wait until busy = '0';
    end if;

    wait until clk'event and clk='1';
    cpu_add    <= MAKE_ADDR(TAG_HIT, IDX_HIT, B01);
    cpu_rd_wrn <= '0';             -- WRITE
    cpu_d_drv  <= U8(16#A5#);      -- data to write
    cpu_d_oe   <= '1';             -- drive the bus
    start      <= '1';

    -- drop start on next posedge
    wait until clk'event and clk='1';
    start      <= '0';

    -- wait for busy high
    if busy = '0' then
      wait until busy = '1';
    end if;
    -- wait for busy low (write finished)
    wait until busy = '0';

    cpu_d_oe   <= '0';

    wait until clk'event and clk='1';

    if busy = '1' then
      wait until busy = '0';
    end if;

    wait until clk'event and clk='1';
    cpu_add    <= MAKE_ADDR(TAG_HIT, IDX_HIT, B01);
    cpu_rd_wrn <= '1';             -- READ
    cpu_d_oe   <= '0';
    start      <= '1';

    wait until clk'event and clk='1';
    start      <= '0';

    if busy = '0' then
      wait until busy = '1';
    end if;
    wait until busy = '0';

    -- CPU samples at following posedge
    wait until clk'event and clk='1';

    if busy = '1' then
      wait until busy = '0';
    end if;

    wait until clk'event and clk='1';
    cpu_add    <= MAKE_ADDR("01", IDX_HIT, B10); 
    cpu_rd_wrn <= '0';             -- WRITE
    cpu_d_drv  <= U8(16#7E#);
    cpu_d_oe   <= '1';
    start      <= '1';

    wait until clk'event and clk='1';
    start      <= '0';

    if busy = '0' then
      wait until busy = '1';
    end if;
    wait until busy = '0';

    cpu_d_oe   <= '0';

    for i in 0 to 20 loop
      wait until clk'event and clk='1';
    end loop;

    assert false report "Simulation finished." severity failure;
  end process;

end tb;


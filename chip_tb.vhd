library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity chip_tb is
end chip_tb;

architecture tb of chip_tb is
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

  signal clk   : std_logic := '0';
  signal reset : std_logic := '0';

  signal cpu_add    : std_logic_vector(5 downto 0) := (others => '0');
  signal cpu_rd_wrn : std_logic := '1';
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

  function U8(i : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(i, 8));
  end;

  function A(tag, idx, byt : std_logic_vector(1 downto 0))
           return std_logic_vector is
  begin
    return tag & idx & byt;
  end;

begin
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

  clk <= not clk after 5 ns;

  cpu_data <= cpu_d_drv when cpu_d_oe = '1' else (others => 'Z');

  mem_model : process(clk)
  begin
    if falling_edge(clk) then
      mem_en_q <= mem_en;
      rd_q     <= cpu_rd_wrn;

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

  watchdog : process
  begin
    wait for 5 ms;
    assert false report "Watchdog timeout - TB stuck" severity failure;
  end process;

  stim : process
    constant TAG_HIT  : std_logic_vector(1 downto 0) := "11";
    constant IDX_HIT  : std_logic_vector(1 downto 0) := "10";
    constant B00      : std_logic_vector(1 downto 0) := "00";
    constant B01      : std_logic_vector(1 downto 0) := "01";
    constant B10      : std_logic_vector(1 downto 0) := "10";

    procedure wait_cycles(n : in integer) is
    begin
      for i in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end;

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

    procedure req(
      tag  : in std_logic_vector(1 downto 0);
      idx  : in std_logic_vector(1 downto 0);
      byt  : in std_logic_vector(1 downto 0);
      rd   : in std_logic;  -- '1'=read, '0'=write
      wdat : in std_logic_vector(7 downto 0)) is
    begin
      if busy = '1' then
        wait until busy = '0';
      end if;

      wait until falling_edge(clk);
      cpu_add    <= tag & idx & byt;
      cpu_rd_wrn <= rd;

      if rd = '0' then
        cpu_d_drv <= wdat;
        cpu_d_oe  <= '1';
      else
        cpu_d_oe  <= '0';
      end if;

      start <= '1';
      wait until rising_edge(clk);
      wait until falling_edge(clk);
      start <= '0';

      wait_busy_rise(1000);
      wait_busy_fall(50000);

      cpu_d_oe <= '0';
    end;
                                      
  begin                               
    reset    <= '1';
    cpu_d_oe <= '0';
    wait until falling_edge(clk);
    wait until falling_edge(clk);
    reset <= '0';
    wait until falling_edge(clk);
                                      
    refill_case <= 1;
    req(TAG_HIT, IDX_HIT, B00, '1', (others => '0'));

    req(TAG_HIT, IDX_HIT, B01, '0', U8(16#A5#));

    req(TAG_HIT, IDX_HIT, B01, '1', (others => '0'));

    req("01", IDX_HIT, B10, '0', U8(16#7E#));

    wait_cycles(20);
    assert false report "Simulation finished." severity failure;
  end process;

end tb;


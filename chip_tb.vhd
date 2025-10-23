library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity chip_tb is
end chip_tb;

architecture test of chip_tb is
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

  -- TB signals
  signal clk        : std_logic := '0';
  signal reset      : std_logic := '0';

  signal cpu_add    : std_logic_vector(5 downto 0) := (others => '0');
  signal cpu_rd_wrn : std_logic := '1';
  signal start      : std_logic := '0';

  signal cpu_data   : std_logic_vector(7 downto 0);
  signal cpu_d_drv  : std_logic_vector(7 downto 0) := (others => '0');
  signal cpu_d_oe   : std_logic := '0';

  signal mem_data   : std_logic_vector(7 downto 0) := (others => '0');

  signal busy       : std_logic;
  signal mem_en     : std_logic;
  signal mem_add    : std_logic_vector(5 downto 0);

  signal Vdd        : std_logic := '1';
  signal Gnd        : std_logic := '0';

  -- helpers
  function U8(i : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(i, 8));
  end;

  signal mem_en_q      : std_logic := '0';
  signal refill_active : std_logic := '0';
  signal neg_cnt       : integer range 0 to 31 := 0;

begin
  -- DUT
  c1 : chip
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

  -- 10 ns clock
  clk <= not clk after 5 ns;

  -- CPU data bus drive
  cpu_data <= cpu_d_drv when cpu_d_oe = '1' else (others => 'Z');

  -- Memory timing model: bytes at negedges #8,10,12,14 after mem_en rises
  mem_model : process(clk)
  begin
    if falling_edge(clk) then
      mem_en_q <= mem_en;

      if (mem_en_q = '0' and mem_en = '1') then
        refill_active <= '1';
        neg_cnt <= 0;
      elsif refill_active = '1' then
        neg_cnt <= neg_cnt + 1;

        case neg_cnt is
          when 8  => mem_data <= U8(16#11#);
          when 10 => mem_data <= U8(16#22#);
          when 12 => mem_data <= U8(16#33#);
          when 14 => mem_data <= U8(16#44#);
          when others => null;
        end case;

        if neg_cnt >= 16 then
          refill_active <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Stimulus
  stim : process
  begin
    -- Reset
    reset    <= '1';
    cpu_d_oe <= '0';
    wait until rising_edge(clk);
    reset    <= '0';
    wait until rising_edge(clk);

    -- 1) READ (MISS -> refill): tag=10 idx=01 byte=00
    cpu_add    <= "10" & "01" & "00";
    cpu_rd_wrn <= '1';
    start      <= '1';
    wait until rising_edge(clk);
    start      <= '0';
    cpu_d_oe   <= '0';
    wait for 300 ns;

    -- 2) READ (HIT): same line byte=10
    cpu_add    <= "10" & "01" & "10";
    cpu_rd_wrn <= '1';
    start      <= '1';
    wait until rising_edge(clk);
    start      <= '0';
    cpu_d_oe   <= '0';
    wait for 60 ns;

    -- 3) WRITE (HIT): same line byte=01, data=0xA5
    cpu_add    <= "10" & "01" & "01";
    cpu_rd_wrn <= '0';
    cpu_d_drv  <= U8(16#A5#);
    cpu_d_oe   <= '1';
    start      <= '1';
    wait until rising_edge(clk);
    start      <= '0';
    wait for 40 ns;
    cpu_d_oe   <= '0';

    -- 4) WRITE (MISS, no-allocate): other tag=01 idx=01 byte=01 data=0x7E
    cpu_add    <= "01" & "01" & "01";
    cpu_rd_wrn <= '0';
    cpu_d_drv  <= U8(16#7E#);
    cpu_d_oe   <= '1';
    start      <= '1';
    wait until rising_edge(clk);
    start      <= '0';
    wait for 40 ns;
    cpu_d_oe   <= '0';

    -- 5) READ back previous line byte=01 (should be 0xA5)
    cpu_add    <= "10" & "01" & "01";
    cpu_rd_wrn <= '1';
    start      <= '1';
    wait until rising_edge(clk);
    start      <= '0';
    cpu_d_oe   <= '0';
    wait for 80 ns;

    -- End
    wait for 200 ns;
    assert false report "Simulation finished." severity failure;
  end process;

end test;

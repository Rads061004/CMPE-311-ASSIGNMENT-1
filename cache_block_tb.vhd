library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_block_tb is
end cache_block_tb;

architecture sim of cache_block_tb is

  component cache_block
    port (
      clk, reset   : in  std_logic;
      enable       : in  std_logic;

      -- CPU side
      data_in      : in  std_logic_vector(7 downto 0);
      data_out     : out std_logic_vector(7 downto 0);
      byte_sel     : in  std_logic_vector(1 downto 0);
      rd_wr        : in  std_logic;  -- 1 = read, 0 = write

      -- Memory side
      mem_in       : in  std_logic_vector(7 downto 0);
      src_is_mem   : in  std_logic;  -- 1 = take from memory
      we           : in  std_logic;  -- write enable

      -- Tag and valid control
      tag_in       : in  std_logic_vector(1 downto 0);
      set_tag      : in  std_logic;
      valid_out    : out std_logic;
      tag_out      : out std_logic_vector(1 downto 0);

      -- Combinational hit/miss
      hit_miss     : out std_logic
    );
  end component;

  -- DUT signals
  signal clk        : std_logic := '0';
  signal reset      : std_logic := '0';
  signal enable     : std_logic := '0';

  signal data_in    : std_logic_vector(7 downto 0) := (others => '0');
  signal data_out   : std_logic_vector(7 downto 0);
  signal byte_sel   : std_logic_vector(1 downto 0) := "00";
  signal rd_wr      : std_logic := '0';

  signal mem_in     : std_logic_vector(7 downto 0) := (others => '0');
  signal src_is_mem : std_logic := '0';
  signal we         : std_logic := '0';

  signal tag_in     : std_logic_vector(1 downto 0) := (others => '0');
  signal set_tag    : std_logic := '0';
  signal tag_out    : std_logic_vector(1 downto 0);
  signal valid_out  : std_logic;

  signal hit_miss   : std_logic;

  -- helper: 8-bit literal from integer
  function U8(val : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(val, 8));
  end;

begin
  -- DUT instantiation
  dut: cache_block
    port map (
      clk      => clk,
      reset    => reset,
      enable   => enable,
      data_in  => data_in,
      data_out => data_out,
      byte_sel => byte_sel,
      rd_wr    => rd_wr,
      mem_in   => mem_in,
      src_is_mem => src_is_mem,
      we       => we,
      tag_in   => tag_in,
      set_tag  => set_tag,
      valid_out=> valid_out,
      tag_out  => tag_out,
      hit_miss => hit_miss
    );

  -- 10 ns period clock
  clk <= not clk after 5 ns;

  -- Stimulus
  stim_proc : process
  begin
    -- Reset
    reset <= '1';
    wait until rising_edge(clk);
    reset <= '0';

    -- Enable this cache line
    enable <= '1';

    ----------------------------------------------------------------
    -- Refill from "memory": tag=10, bytes = 11,22,33,44
    ----------------------------------------------------------------
    tag_in   <= "10";
    set_tag  <= '1';
    we       <= '1';
    src_is_mem <= '1';

    mem_in   <= U8(16#11#); byte_sel <= "00"; wait until rising_edge(clk);
    mem_in   <= U8(16#22#); byte_sel <= "01"; wait until rising_edge(clk);
    mem_in   <= U8(16#33#); byte_sel <= "10"; wait until rising_edge(clk);
    mem_in   <= U8(16#44#); byte_sel <= "11"; wait until rising_edge(clk);

    -- stop writing/tagging
    set_tag    <= '0';
    we         <= '0';
    src_is_mem <= '0';

    ----------------------------------------------------------------
    -- Show hit_miss behaviour:
    --   mismatch tag -> hit_miss='0', then match tag -> '1'
    ----------------------------------------------------------------
    tag_in <= "01";  -- wrong tag => miss
    wait for 10 ns;

    tag_in <= "10";  -- matching tag & valid & enable => hit
    wait for 10 ns;

    ----------------------------------------------------------------
    -- Read one byte (should be 0x33 at offset "10")
    ----------------------------------------------------------------
    rd_wr    <= '1';
    byte_sel <= "10";
    wait until rising_edge(clk);

    ----------------------------------------------------------------
    -- Write hit: overwrite offset "01" with 0xA5 and read back
    ----------------------------------------------------------------
    rd_wr   <= '0';
    data_in <= U8(16#A5#);
    byte_sel <= "01";
    we      <= '1';
    wait until rising_edge(clk);
    we      <= '0';

    rd_wr    <= '1';
    byte_sel <= "01";
    wait until rising_edge(clk);

    -- Finish
    wait for 50 ns;
    assert false report "Simulation finished." severity failure;
  end process;

end sim;

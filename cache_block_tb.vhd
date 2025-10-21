library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_block_tb is
end cache_block_tb;

architecture sim of cache_block_tb is
  component cache_block
    port (
      clk, reset     : in  std_logic;

      CA             : in  std_logic_vector(5 downto 0);
      CD_in          : in  std_logic_vector(7 downto 0);
      CD_out         : out std_logic_vector(7 downto 0);
      OE_CD          : in  std_logic;
      RD_WR          : in  std_logic;
      START          : in  std_logic;

      MD_in          : in  std_logic_vector(7 downto 0);
      MA_out         : out std_logic_vector(7 downto 0);

      latch_req      : in  std_logic;
      cache_we       : in  std_logic;
      src_is_mem     : in  std_logic;
      byte_sel       : in  std_logic_vector(1 downto 0);
      set_tag_valid  : in  std_logic;
      invalidate_all : in  std_logic;

      hit            : out std_logic
    );
  end component;

  -- DUT signals
  signal clk           : std_logic := '0';
  signal reset         : std_logic := '0';

  signal CA            : std_logic_vector(5 downto 0) := (others => '0');
  signal CD_in         : std_logic_vector(7 downto 0) := (others => '0');
  signal CD_out        : std_logic_vector(7 downto 0);
  signal OE_CD         : std_logic := '0';
  signal RD_WR         : std_logic := '0';
  signal START         : std_logic := '0';

  signal MD_in         : std_logic_vector(7 downto 0) := (others => '0');
  signal MA_out        : std_logic_vector(7 downto 0);

  signal latch_req     : std_logic := '0';
  signal cache_we      : std_logic := '0';
  signal src_is_mem    : std_logic := '0';
  signal byte_sel      : std_logic_vector(1 downto 0) := "00";
  signal set_tag_valid : std_logic := '0';
  signal invalidate_all: std_logic := '0';

  signal hit           : std_logic;

  -- tiny helper for 8-bit bytes (VHDL-93 safe)
  function U8(hexval : integer) return std_logic_vector is
  begin
    return std_logic_vector(to_unsigned(hexval, 8));
  end;

begin
  -- DUT
  dut: cache_block
    port map (
      clk, reset,
      CA, CD_in, CD_out, OE_CD, RD_WR, START,
      MD_in, MA_out,
      latch_req, cache_we, src_is_mem, byte_sel, set_tag_valid, invalidate_all,
      hit
    );

  -- 2 ns clock
  clk <= not clk after 1 ns;

  -- Stimulus (no local subprograms with bodies, no asserts)
  stim_proc : process
  begin
    -- Reset + invalidate
    wait until rising_edge(clk);
    reset <= '1';
    wait until rising_edge(clk);
    reset <= '0';

    invalidate_all <= '1';
    wait until falling_edge(clk);
    invalidate_all <= '0';

    -- ============ READ-MISS FILL: tag=10, idx=01 ============
    CA    <= "10" & "01" & "00";  -- tag=10, index=01, byte=00
    RD_WR <= '1';                 -- read
    CD_in <= (others => '0');
    START <= '1';
    latch_req <= '1';
    wait until falling_edge(clk);
    latch_req <= '0';
    START <= '0';

    -- Fill 4 bytes from "memory": 0x11, 0x22, 0x33, 0x44
    src_is_mem    <= '1';
    MD_in         <= U8(16#11#);
    byte_sel      <= "00";
    set_tag_valid <= '1';
    cache_we      <= '1';
    wait until falling_edge(clk);
    cache_we      <= '0';
    set_tag_valid <= '0';
    src_is_mem    <= '0';

    src_is_mem    <= '1';
    MD_in         <= U8(16#22#);
    byte_sel      <= "01";
    cache_we      <= '1';
    wait until falling_edge(clk);
    cache_we      <= '0';
    src_is_mem    <= '0';

    src_is_mem    <= '1';
    MD_in         <= U8(16#33#);
    byte_sel      <= "10";
    cache_we      <= '1';
    wait until falling_edge(clk);
    cache_we      <= '0';
    src_is_mem    <= '0';

    src_is_mem    <= '1';
    MD_in         <= U8(16#44#);
    byte_sel      <= "11";
    cache_we      <= '1';
    wait until falling_edge(clk);
    cache_we      <= '0';
    src_is_mem    <= '0';

    -- READ-HIT: read byte_sel=10 (observe 0x33 on CD_out)
    byte_sel <= "10";
    OE_CD    <= '1';
    wait until falling_edge(clk);
    OE_CD    <= '0';
    wait for 2 ns;

    -- ============ WRITE-HIT: overwrite byte 01 with 0xA5 ============
    CA    <= "10" & "01" & "01";  -- same line, byte=01
    RD_WR <= '0';                 -- write
    CD_in <= U8(16#A5#);
    START <= '1';
    latch_req <= '1';
    wait until falling_edge(clk);
    latch_req <= '0';
    START <= '0';

    src_is_mem <= '0';
    byte_sel   <= "01";
    cache_we   <= '1';
    wait until falling_edge(clk);
    cache_we   <= '0';

    -- Read back byte 01 (should observe 0xA5)
    byte_sel <= "01";
    OE_CD    <= '1';
    wait until falling_edge(clk);
    OE_CD    <= '0';
    wait for 2 ns;

    -- ============ WRITE-MISS (no-allocate): different tag, same index ============
    CA    <= "01" & "01" & "01";  -- different tag -> miss
    RD_WR <= '0';
    CD_in <= U8(16#7E#);
    START <= '1';
    latch_req <= '1';
    wait until falling_edge(clk);
    latch_req <= '0';
    START <= '0';

    -- No cache_we pulse here (no-allocate). Observe hit='0' on waves.
    wait for 4 ns;

    -- Verify original line unchanged: read back tag=10/index=01/byte=01 (should still be 0xA5)
    CA    <= "10" & "01" & "01";
    RD_WR <= '1';
    START <= '1';
    latch_req <= '1';
    wait until falling_edge(clk);
    latch_req <= '0';
    START <= '0';

    byte_sel <= "01";
    OE_CD    <= '1';
    wait until falling_edge(clk);
    OE_CD    <= '0';

    -- Leave some time to inspect waveforms, then stop sim
    wait for 20 ns;
    wait;
  end process stim_proc;

end sim;

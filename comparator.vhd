-- comparator.vhd
--
-- Structural unsigned >= comparators for 5-bit counters
-- Used by next_state_logic and output_logic

library ieee;
use ieee.std_logic_1164.all;

entity gte5 is
  port (
    a   : in  STD_LOGIC_VECTOR(4 downto 0);
    b   : in  STD_LOGIC_VECTOR(4 downto 0);
    gte : out STD_LOGIC
  );
end gte5;

architecture structural of gte5 is

  component inv
    port (a : in STD_LOGIC; y : out STD_LOGIC);
  end component;

  component and2
    port (a, b : in STD_LOGIC; y : out STD_LOGIC);
  end component;

  component and4
    port (a, b, c, d : in STD_LOGIC; y : out STD_LOGIC);
  end component;

  component and5
    port (a, b, c, d, e : in STD_LOGIC; y : out STD_LOGIC);
  end component;

  component or2
    port (a, b : in STD_LOGIC; y : out STD_LOGIC);
  end component;

  component xnor2
    port (a, b : in STD_LOGIC; y : out STD_LOGIC);
  end component;

  -- bitwise equality flags eq_bit(i) and "a > b at this bit" flags gt_bit(i)
  signal eq_bit    : STD_LOGIC_VECTOR(4 downto 0);
  signal b_n       : STD_LOGIC_VECTOR(4 downto 0);
  signal gt_bit    : STD_LOGIC_VECTOR(4 downto 0);

  -- running "all higher bits matched so far"
  signal eqpref4, eqpref3, eqpref2, eqpref1, eqpref0 : STD_LOGIC;

  -- partial (eqpref * gt_bit) at each stage
  signal gt_term3, gt_term2, gt_term1, gt_term0      : STD_LOGIC;

  -- running "we are already greater so far" going down the bits
  signal gt_sofar4, gt_sofar3, gt_sofar2, gt_sofar1, gt_sofar0 : STD_LOGIC;

  -- final OR
  signal gte_int : STD_LOGIC;

begin
  ------------------------------------------------------------------
  -- eq_bit(i) = XNOR(a(i), b(i))
  -- b_n(i)    = NOT b(i)
  -- gt_bit(i) = a(i) AND (NOT b(i))
  ------------------------------------------------------------------
  gen_bits : for i in 0 to 4 generate
    u_xnor : xnor2
      port map (a => a(i), b => b(i), y => eq_bit(i));

    u_inv  : inv
      port map (a => b(i), y => b_n(i));

    u_gt   : and2
      port map (a => a(i), b => b_n(i), y => gt_bit(i));
  end generate;

  ------------------------------------------------------------------
  -- Build equal_prefix and greater_so_far from MSB (bit4) down.
  --
  -- Bit 4 (MSB):
  --   eqpref4   = eq_bit(4)
  --   gt_sofar4 = gt_bit(4)
  ------------------------------------------------------------------
  eqpref4   <= eq_bit(4);
  gt_sofar4 <= gt_bit(4);

  ------------------------------------------------------------------
  -- Bit 3:
  --   eqpref3   = eqpref4 AND eq_bit(3)
  --   gt_term3  = eqpref4 AND gt_bit(3)
  --   gt_sofar3 = gt_sofar4 OR gt_term3
  ------------------------------------------------------------------
  u_eqpref3_and : and2
    port map (a => eqpref4, b => eq_bit(3), y => eqpref3);

  u_gtterm3_and : and2
    port map (a => eqpref4, b => gt_bit(3), y => gt_term3);

  u_gtsofar3_or : or2
    port map (a => gt_sofar4, b => gt_term3, y => gt_sofar3);

  ------------------------------------------------------------------
  -- Bit 2:
  --   eqpref2   = eqpref3 AND eq_bit(2)
  --   gt_term2  = eqpref3 AND gt_bit(2)
  --   gt_sofar2 = gt_sofar3 OR gt_term2
  ------------------------------------------------------------------
  u_eqpref2_and : and2
    port map (a => eqpref3, b => eq_bit(2), y => eqpref2);

  u_gtterm2_and : and2
    port map (a => eqpref3, b => gt_bit(2), y => gt_term2);

  u_gtsofar2_or : or2
    port map (a => gt_sofar3, b => gt_term2, y => gt_sofar2);

  ------------------------------------------------------------------
  -- Bit 1:
  --   eqpref1   = eqpref2 AND eq_bit(1)
  --   gt_term1  = eqpref2 AND gt_bit(1)
  --   gt_sofar1 = gt_sofar2 OR gt_term1
  ------------------------------------------------------------------
  u_eqpref1_and : and2
    port map (a => eqpref2, b => eq_bit(1), y => eqpref1);

  u_gtterm1_and : and2
    port map (a => eqpref2, b => gt_bit(1), y => gt_term1);

  u_gtsofar1_or : or2
    port map (a => gt_sofar2, b => gt_term1, y => gt_sofar1);

  ------------------------------------------------------------------
  -- Bit 0 (LSB):
  --   eqpref0   = eqpref1 AND eq_bit(0)   -- full equality a == b
  --   gt_term0  = eqpref1 AND gt_bit(0)
  --   gt_sofar0 = gt_sofar1 OR gt_term0   -- final "a > b"
  ------------------------------------------------------------------
  u_eqpref0_and : and2
    port map (a => eqpref1, b => eq_bit(0), y => eqpref0);

  u_gtterm0_and : and2
    port map (a => eqpref1, b => gt_bit(0), y => gt_term0);

  u_gtsofar0_or : or2
    port map (a => gt_sofar1, b => gt_term0, y => gt_sofar0);

  ------------------------------------------------------------------
  -- a >= b  =  (a > b) OR (a == b)
  --         =  gt_sofar0 OR eqpref0
  ------------------------------------------------------------------
  u_final_or : or2
    port map (a => gt_sofar0, b => eqpref0, y => gte_int);

  gte <= gte_int;

end structural;

library ieee;
use ieee.std_logic_1164.all;

----------------------------------------------------------------------
-- counter >= 0   (always true)
----------------------------------------------------------------------

entity gte_zero is
  port (
    a   : in  STD_LOGIC_VECTOR(4 downto 0);
    gte : out STD_LOGIC
  );
end gte_zero;

architecture structural_gte_zero of gte_zero is
begin
  gte <= '1';
end structural_gte_zero;

library ieee;
use ieee.std_logic_1164.all;

----------------------------------------------------------------------
-- counter >= 1
----------------------------------------------------------------------

entity gte_one is
  port (
    a   : in  STD_LOGIC_VECTOR(4 downto 0);
    gte : out STD_LOGIC
  );
end gte_one;

architecture structural_gte_one of gte_one is
  component gte5
    port (
      a   : in  STD_LOGIC_VECTOR(4 downto 0);
      b   : in  STD_LOGIC_VECTOR(4 downto 0);
      gte : out STD_LOGIC
    );
  end component;

  signal one : STD_LOGIC_VECTOR(4 downto 0);
begin
  one <= "00001";

  u_ge1: gte5
    port map (
      a   => a,
      b   => one,
      gte => gte
    );
end structural_gte_one;

library ieee;
use ieee.std_logic_1164.all;

----------------------------------------------------------------------
-- counter >= 17
----------------------------------------------------------------------

entity gte_seventeen is
  port (
    a   : in  STD_LOGIC_VECTOR(4 downto 0);
    gte : out STD_LOGIC
  );
end gte_seventeen;

architecture structural_gte_seventeen of gte_seventeen is
  component gte5
    port (
      a   : in  STD_LOGIC_VECTOR(4 downto 0);
      b   : in  STD_LOGIC_VECTOR(4 downto 0);
      gte : out STD_LOGIC
    );
  end component;

  signal seventeen : STD_LOGIC_VECTOR(4 downto 0);
begin
  -- 17 = 10001
  seventeen <= "10001";

  u_ge17: gte5
    port map (
      a   => a,
      b   => seventeen,
      gte => gte
    );
end structural_gte_seventeen;

library ieee;
use ieee.std_logic_1164.all;

-- Single-bit tri-state buffer cell
entity tbuf1 is
    port (
        d  : in  std_logic;  -- data to drive
        en : in  std_logic;  -- active-high output enable
        b  : out std_logic   -- driven bus bit (or 'Z')
    );
end tbuf1;

architecture structural of tbuf1 is
begin
    -- Drive the line when enabled, otherwise float.
    b <= d when en = '1' else 'Z';
end structural;


library ieee;
use ieee.std_logic_1164.all;

-- 8-bit tri-state bus driver built structurally from 8 copies of tbuf1
entity tbuf8 is
    port (
        d   : in  std_logic_vector(7 downto 0);  -- data from cache/CPU side
        en  : in  std_logic;                     -- bus enable for all bits
        b   : out std_logic_vector(7 downto 0)   -- shared CPU data bus
    );
end tbuf8;

architecture structural of tbuf8 is

    -- VHDL-87 style component declaration (no "is")
    component tbuf1
        port (
            d  : in  std_logic;
            en : in  std_logic;
            b  : out std_logic
        );
    end component;

begin
    gen_bits : for i in 0 to 7 generate
        u_tbuf_bit : tbuf1
            port map (
                d  => d(i),
                en => en,
                b  => b(i)
            );
    end generate;

end structural;

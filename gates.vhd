-- Low-level gate components (these can be behavioral)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- 2-input AND gate
entity and2 is
    port (
        a, b : in  STD_LOGIC;
        y    : out STD_LOGIC
    );
end and2;

architecture behavioral of and2 is
begin
    y <= a and b;
end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- 3-input AND gate
entity and3 is
    port (
        a, b, c : in  STD_LOGIC;
        y       : out STD_LOGIC
    );
end and3;

architecture behavioral of and3 is
begin
    y <= a and b and c;
end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- 4-input AND gate
entity and4 is
    port (
        a, b, c, d : in  STD_LOGIC;
        y          : out STD_LOGIC
    );
end and4;

architecture behavioral of and4 is
begin
    y <= a and b and c and d;
end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- 2-input OR gate
entity or2 is
    port (
        a, b : in  STD_LOGIC;
        y    : out STD_LOGIC
    );
end or2;

architecture behavioral of or2 is
begin
    y <= a or b;
end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- 3-input OR gate
entity or3 is
    port (
        a, b, c : in  STD_LOGIC;
        y       : out STD_LOGIC
    );
end or3;

architecture behavioral of or3 is
begin
    y <= a or b or c;
end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- 4-input OR gate
entity or4 is
    port (
        a, b, c, d : in  STD_LOGIC;
        y          : out STD_LOGIC
    );
end or4;

architecture behavioral of or4 is
begin
    y <= a or b or c or d;
end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- 8-input OR gate
entity or8 is
    port (
        a, b, c, d, e, f, g, h : in  STD_LOGIC;
        y                      : out STD_LOGIC
    );
end or8;

architecture behavioral of or8 is
begin
    y <= a or b or c or d or e or f or g or h;
end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- NOT gate (inverter)
entity inv is
    port (
        a : in  STD_LOGIC;
        y : out STD_LOGIC
    );
end inv;

architecture behavioral of inv is
begin
    y <= not a;
end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- 2-input NAND gate
entity nand2 is
    port (
        a, b : in  STD_LOGIC;
        y    : out STD_LOGIC
    );
end nand2;

architecture behavioral of nand2 is
begin
    y <= a nand b;
end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- 2-input NOR gate
entity nor2 is
    port (
        a, b : in  STD_LOGIC;
        y    : out STD_LOGIC
    );
end nor2;

architecture behavioral of nor2 is
begin
    y <= a nor b;
end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- 2-input XOR gate
entity xor2 is
    port (
        a, b : in  STD_LOGIC;
        y    : out STD_LOGIC
    );
end xor2;

architecture behavioral of xor2 is
begin
    y <= a xor b;
end behavioral;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- 2-input XNOR gate
entity xnor2 is
    port (
        a, b : in  STD_LOGIC;
        y    : out STD_LOGIC
    );
end xnor2;

architecture behavioral of xnor2 is
begin
    y <= not (a xor b);
end behavioral;
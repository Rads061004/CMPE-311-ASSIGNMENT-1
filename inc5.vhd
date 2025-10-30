library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity inc5 is
    port (
        a   : in  STD_LOGIC_VECTOR(4 downto 0);
        inc : out STD_LOGIC_VECTOR(4 downto 0)
    );
end inc5;

architecture structural of inc5 is
    component adder5
        port (
            a, b : in  STD_LOGIC_VECTOR(4 downto 0);
            cin  : in  STD_LOGIC; 
            sum  : out STD_LOGIC_VECTOR(4 downto 0);
            cout : out STD_LOGIC
        );
    end component;

    signal one         : STD_LOGIC_VECTOR(4 downto 0);
    signal cin_sig     : STD_LOGIC;
    signal cout_unused : STD_LOGIC;
begin
    one     <= "00001";  -- signal for b
    cin_sig <= '0';      -- signal for cin

    u_add: adder5 port map (
        a    => a,
        b    => one,
        cin  => cin_sig,
        sum  => inc,
        cout => cout_unused
    );
end structural;

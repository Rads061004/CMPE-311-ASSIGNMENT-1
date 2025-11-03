library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity decoder is
    port (
        block_addr : in  std_logic_vector(1 downto 0);
        block_sel  : out std_logic_vector(3 downto 0)
    );
end decoder;

architecture structural of decoder is
    component and2
        port (a, b : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    component inv
        port (a : in STD_LOGIC; y : out STD_LOGIC);
    end component;
    
    signal addr0, addr1 : std_logic;
    signal addr0_n, addr1_n : std_logic;
    
begin
    addr0 <= block_addr(0);
    addr1 <= block_addr(1);
    
    u_inv0: inv port map (a => addr0, y => addr0_n);
    u_inv1: inv port map (a => addr1, y => addr1_n);
    
    u_and0: and2 port map (a => addr1_n, b => addr0_n, y => block_sel(0));
    
    u_and1: and2 port map (a => addr1_n, b => addr0, y => block_sel(1));
    
    u_and2: and2 port map (a => addr1, b => addr0_n, y => block_sel(2));

    u_and3: and2 port map (a => addr1, b => addr0, y => block_sel(3));
    

end structural;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity decoder_tb is
end decoder_tb;

architecture behavior of decoder_tb is
    component decoder
        Port (
            block_addr : in  STD_LOGIC_VECTOR(1 downto 0);
            block_sel  : out STD_LOGIC_VECTOR(3 downto 0)
        );
    end component;

    signal block_addr : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal block_sel  : STD_LOGIC_VECTOR(3 downto 0);

begin
    uut: decoder
        port map (
            block_addr => block_addr,
            block_sel  => block_sel
        );

    stim_proc: process
    begin
        block_addr <= "00"; wait for 10 ns;
        block_addr <= "01"; wait for 10 ns;
        block_addr <= "10"; wait for 10 ns;
        block_addr <= "11"; wait for 10 ns;

        assert false report "Decoder Test Finished" severity failure;
    end process;

end behavior;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mux_tb is
end mux_tb;

architecture behavior of mux_tb is
    component mux
        Port (
            word_addr : in  STD_LOGIC_VECTOR(1 downto 0);
            block_data: in  STD_LOGIC_VECTOR(31 downto 0);
            word_out  : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    signal word_addr  : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal block_data : STD_LOGIC_VECTOR(31 downto 0) := std_logic_vector(to_unsigned(16#44332211#, 32));
    signal word_out   : STD_LOGIC_VECTOR(7 downto 0);

begin
    uut: mux
        port map (
            word_addr  => word_addr,
            block_data => block_data,
            word_out   => word_out
        );

    stim_proc: process
    begin
        word_addr <= "00"; wait for 10 ns; 
        word_addr <= "01"; wait for 10 ns; 
        word_addr <= "10"; wait for 10 ns; 
        word_addr <= "11"; wait for 10 ns; 

        assert false report "Mux Test Finished" severity failure;
    end process;

end behavior;

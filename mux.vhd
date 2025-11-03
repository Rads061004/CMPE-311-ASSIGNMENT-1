library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mux is
    Port (
        word_addr : in  STD_LOGIC_VECTOR(1 downto 0);   
        block_data: in  STD_LOGIC_VECTOR(31 downto 0);  
        word_out  : out STD_LOGIC_VECTOR(7 downto 0)    
    );
end mux;

architecture RTL of mux is
begin
    process(word_addr, block_data)
    begin
        case word_addr is
            when "00" => word_out <= block_data(7 downto 0);
            when "01" => word_out <= block_data(15 downto 8);
            when "10" => word_out <= block_data(23 downto 16);
            when "11" => word_out <= block_data(31 downto 24);
            when others => word_out <= (others => '0');
        end case;
    end process;

end RTL;

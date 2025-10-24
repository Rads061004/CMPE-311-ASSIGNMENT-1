library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity decoder is
    Port (
        block_addr : in  STD_LOGIC_VECTOR(1 downto 0);  
        block_sel  : out STD_LOGIC_VECTOR(3 downto 0)   
    );
end decoder;

architecture RTL of decoder is
begin
    process(block_addr)
    begin
        case block_addr is
            when "00" => block_sel <= "0001";
            when "01" => block_sel <= "0010";
            when "10" => block_sel <= "0100";
            when "11" => block_sel <= "1000";
            when others => block_sel <= "0000";
        end case;
    end process;

end RTL;

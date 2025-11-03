library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_block_tb is
end cache_block_tb;

architecture sim of cache_block_tb is

    component cache_block
        port (
            clk        : in  std_logic;
            reset      : in  std_logic;

            enable     : in  std_logic;

            data_in    : in  std_logic_vector(7 downto 0);
            data_out   : out std_logic_vector(7 downto 0);
            byte_sel   : in  std_logic_vector(1 downto 0);
            rd_wr      : in  std_logic;                     
                                                         

            mem_in     : in  std_logic_vector(7 downto 0);

            we         : in  std_logic;                     
            set_tag    : in  std_logic;                  
            tag_in     : in  std_logic_vector(1 downto 0);  

            valid_out  : out std_logic;
            tag_out    : out std_logic_vector(1 downto 0);
            hit_miss   : out std_logic                     
        );
    end component;

    signal clk        : std_logic := '0';
    signal reset      : std_logic := '0';
    signal enable     : std_logic := '0';

    signal data_in    : std_logic_vector(7 downto 0) := (others => '0');
    signal data_out   : std_logic_vector(7 downto 0);
    signal byte_sel   : std_logic_vector(1 downto 0) := "00";
    signal rd_wr      : std_logic := '0';  

    signal mem_in     : std_logic_vector(7 downto 0) := (others => '0');
    signal we         : std_logic := '0';

    signal tag_in     : std_logic_vector(1 downto 0) := (others => '0');
    signal set_tag    : std_logic := '0';
    signal tag_out    : std_logic_vector(1 downto 0);
    signal valid_out  : std_logic;

    signal hit_miss   : std_logic;

    function U8(val : integer) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(val, 8));
    end U8;

begin
    dut: cache_block
        port map (
            clk        => clk,
            reset      => reset,
            enable     => enable,

            data_in    => data_in,
            data_out   => data_out,
            byte_sel   => byte_sel,
            rd_wr      => rd_wr,

            mem_in     => mem_in,

            we         => we,
            set_tag    => set_tag,
            tag_in     => tag_in,

            valid_out  => valid_out,
            tag_out    => tag_out,
            hit_miss   => hit_miss
        );

    clk <= not clk after 5 ns;

    stim_proc : process
    begin
        reset <= '1';
        wait until rising_edge(clk);
        reset <= '0';

        enable <= '1';

        rd_wr     <= '1';         
        set_tag   <= '1';         
        we        <= '1';         
        tag_in    <= "10";       

        mem_in    <= U8(16#11#);
        byte_sel  <= "00";
        wait until rising_edge(clk);

        set_tag   <= '0';

        mem_in    <= U8(16#22#);
        byte_sel  <= "01";
        wait until rising_edge(clk);

        mem_in    <= U8(16#33#);
        byte_sel  <= "10";
        wait until rising_edge(clk);

        mem_in    <= U8(16#44#);
        byte_sel  <= "11";
        wait until rising_edge(clk);

        we      <= '0';
        rd_wr   <= '0';  

        tag_in   <= "01";
        wait for 10 ns;

        tag_in   <= "10";
        wait for 10 ns;

        rd_wr    <= '1';
        byte_sel <= "10";   
        wait until rising_edge(clk);

        rd_wr    <= '0';             
        data_in  <= U8(16#A5#);      
        byte_sel <= "01";            
        we       <= '1';
        wait until rising_edge(clk);
        we       <= '0';

        rd_wr    <= '1';            
        byte_sel <= "01";            
        wait until rising_edge(clk);

        wait for 50 ns;
        assert false report "Simulation finished." severity failure;
    end process;

end sim;


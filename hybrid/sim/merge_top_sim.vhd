library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
	use IEEE.MATH_REAL.ALL;

entity merge_top_sim is
--  Port ( );
end merge_top_sim;

architecture Behavioral of merge_top_sim is

	constant CLK_PERIOD : time := 10 ns;
    constant WIDTH : integer := 32;
    constant DEPTH : integer := 32;
    constant LEN: integer := 1024;

	
component merge_top is
    Port (
        axi_clk: in std_logic;
        axi_resetn: in std_logic;
     -- slave interface
        i_data_valid: in std_logic;
        i_data_last: in std_logic;
        i_data: in std_logic_vector(WIDTH-1 DOWNTO 0);
        o_data_ready: out std_logic;
     -- master interface
        o_data_valid: out std_logic;
        o_data_last: out std_logic;
        o_data: out std_logic_vector(WIDTH-1 DOWNTO 0);
        i_data_ready: in std_logic;
        
     -- interrupt
        intr: out std_logic
    );
end component;

	
	

	signal rst 		: std_logic := '0';
	signal reset_n : std_logic := '1';
	signal clk 			: std_logic := '1';
    signal d_out_last: std_logic;
	signal d_in, d_out 	: std_logic_vector(WIDTH-1 DOWNTO 0);
	signal d_in_valid: std_logic;
	signal d_in_last: std_logic := '0';
	signal d_out_valid: std_logic;
    signal d_out_ready: std_logic;
	signal dinInteger 	: integer;
	

begin

	-- Lascio solo il modulo che voglio simulare

	merge_top_inst : merge_top

		Port Map(
            axi_clk => clk,
			axi_resetn 	=> reset_n,
			i_data_valid => d_in_valid,
            i_data_last => d_in_last,
            i_data => d_in,
            o_data_last => d_out_last,
            o_data_ready =>d_out_ready,
            o_data_valid => d_out_valid,
            o_data => d_out,
            i_data_ready => '1'
       
		);

	
	clk <= not clk after CLK_PERIOD/2;

	d_in <= std_logic_vector(to_unsigned(dinInteger,d_in'LENGTH));
    reset_n <= not rst;
        
    
	process
	variable x : real;
	variable seed1: positive;
	variable seed2: positive;
	
	begin

        seed1:=1;
        seed2:=2;
		rst <= '1';
		dinInteger <= 0;
        
		for I in 0 to 5 loop
			wait until rising_edge(clk);
		end loop;

		rst <= '0';
		d_in_last <= '0';
        d_in_valid<='0';
		for I in 0 to LEN-1 loop
			 wait until rising_edge(clk);
			 uniform(seed1, seed2, x);
			 d_in_valid<='1';
             dinInteger <= integer(abs(floor(x * 256.0)));
             
		end loop;

		
		d_in_last<='1';
		
		wait until rising_edge(clk);
		d_in_valid<='0';
        d_in_last<='0';
		
		wait;
	end process;
	
	assert_process:process(clk)
		variable out1: integer := 0;
	    variable out2: integer := 0;
	begin
	   if rising_edge(clk) and d_out_valid='1' and d_out_last='0' then
	       out1:=out2;
	       out2:=to_integer(unsigned(d_out));
	       assert out1<=out2 report "ERROR!!! "& integer'image(out1)&" <= "& integer'image(out2)&" is not true!";
	   end if;
	end process;
    
    
end Behavioral;
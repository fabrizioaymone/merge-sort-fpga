library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity sipo_reg is
    Generic(
        DEPTH: integer;
        WIDTH: integer
    );
    Port (
        clk: in std_logic;
        reset: in std_logic;
        -- input data
        i_data_valid: in std_logic;
        i_data: in std_logic_vector(WIDTH-1 DOWNTO 0);
        -- output data
        o_data: out std_logic_vector(DEPTH*WIDTH-1 DOWNTO 0)
    );
end sipo_reg;

architecture Behavioral of sipo_reg is

    -- SIPO register
    type sipo_reg_type is array(DEPTH-1 DOWNTO 0) of std_logic_vector(WIDTH-1 DOWNTO 0);
    signal sipo_reg: sipo_reg_type;

begin

    sipo_reg(DEPTH-1)<=i_data;

    FOR_GEN: for I in DEPTH-1 DOWNTO 0 generate
        o_data((I+1)*WIDTH-1 DOWNTO I*WIDTH)<=sipo_reg(I);
    end generate;



    process(clk, reset)
    
    begin
        if reset='1' then
            sipo_reg(sipo_reg'LEFT-1 DOWNTO sipo_reg'RIGHT)<=(Others=>(Others=>'0'));            
        elsif rising_edge(clk) then
        
            if i_data_valid='1' then
                sipo_reg(sipo_reg'LEFT-1 DOWNTO sipo_reg'RIGHT)<= sipo_reg(sipo_reg'LEFT DOWNTO sipo_reg'RIGHT+1);
             end if;
         
         end if;
    
    end process;    

end Behavioral;

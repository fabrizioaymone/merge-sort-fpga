library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity sipo_reg is
    Generic(
        LEN: integer;
        WIDTH: integer
    );
    Port (
        clk: in std_logic;
        reset: in std_logic;
        -- input data
        i_data_valid: in std_logic;
        i_data_last: in std_logic;
        i_data: in std_logic_vector(WIDTH-1 DOWNTO 0);
        shift: in std_logic;
        -- output data
        o_data: out std_logic_vector(LEN*WIDTH-1 DOWNTO 0)
    );
end sipo_reg;

architecture Behavioral of sipo_reg is

    -- SIPO register
    type sipo_reg_type is array(LEN-1 DOWNTO 0) of std_logic_vector(WIDTH-1 DOWNTO 0);
    signal sipo_reg: sipo_reg_type;
    
    -- state
    type state_type is (ACQUIRE, STOP);
    signal state, next_state: state_type;
begin


    FOR_GEN: for I in LEN-1 DOWNTO 0 generate
        o_data((I+1)*WIDTH-1 DOWNTO I*WIDTH)<=sipo_reg(I);
    end generate;



    sync:process(clk, reset)
    
    begin
        if reset='1' then
            sipo_reg(sipo_reg'LEFT DOWNTO sipo_reg'RIGHT)<=(Others=>(Others=>'0'));
            state<=ACQUIRE;            
        
        elsif rising_edge(clk) then
            if (i_data_valid='1' and state=ACQUIRE) or shift='1' then
                sipo_reg<= sipo_reg(sipo_reg'LEFT-1 DOWNTO sipo_reg'RIGHT) & i_data;
             end if;
             if i_data_last='1' and state=ACQUIRE then
                state<=STOP;
             end if;
         
         end if;
    
    end process;

    
    
    
        

end Behavioral;
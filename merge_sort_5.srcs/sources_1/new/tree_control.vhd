library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tree_control is
    Generic(
        DEPTH: integer;
        WIDTH: integer
    );
    Port (
        clk: in std_logic;
        reset: in std_logic;
        -- input data
        i_data_valid: in std_logic;
        i_data_last: in std_logic;
        i_data: in std_logic_vector(WIDTH-1 DOWNTO 0);
        -- output data
        o_data: out std_logic_vector(DEPTH*WIDTH-1 DOWNTO 0);
        o_empty: out std_logic_vector(DEPTH-1 DOWNTO 0);
        o_rd_en: in std_logic_vector(DEPTH-1 DOWNTO 0)
    );
end tree_control;

architecture Behavioral of tree_control is

    -- SIPO register
    type sipo_reg_type is array(DEPTH-1 DOWNTO 0) of std_logic_vector(WIDTH-1 DOWNTO 0);
    signal sipo_reg: sipo_reg_type;

    -- FIFO FWFT buffers
    component FIFO_FWFT is
        Generic(
            WIDTH: integer;
            DEPTH: integer
        );
        Port(
            clk: in std_logic;
            reset: in std_logic;
         -- write data
            wr_en: in std_logic;
            d_in: in std_logic_vector(WIDTH-1 DOWNTO 0);
         -- read data
            rd_en: in std_logic;  
            d_out: out std_logic_vector(WIDTH-1 DOWNTO 0);
        -- is possible to write data?
            full: out std_logic;
        -- is signal read valid?       
            empty  : out std_logic
        );
    end component;


begin

    sipo_reg(DEPTH-1)<=i_data;


    FOR_GEN: for I in DEPTH-1 DOWNTO 0 generate
        inst_FIFO_FWFT:FIFO_FWFT
        Generic Map(
            WIDTH   =>  WIDTH,
            DEPTH   =>  1
        )
        Port Map(
            
            clk     =>  clk,
            reset   =>  reset,
            
            wr_en   =>  i_data_last,
            d_in    =>  sipo_reg(I),
            
            rd_en   =>  o_rd_en(I),
            d_out   =>  o_data((I+1)*WIDTH-1 DOWNTO I*WIDTH),
            
            empty   =>  o_empty(I)
            
        );
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

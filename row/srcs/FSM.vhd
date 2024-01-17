library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FSM is
    Generic(
        DEPTH: integer;
        WIDTH: integer
    );
    Port (
        clk: in std_logic;
        reset: in std_logic;
        
        -- input data
        i_data_last: in std_logic;
        i_data: in std_logic_vector(DEPTH*WIDTH-1 DOWNTO 0);
        
        -- input data from buffers
        
        i_full: in std_logic_vector((DEPTH/2)-1 DOWNTO 0);
        i_empty: in std_logic_vector((DEPTH/2)-1 DOWNTO 0);
        i_size: in std_logic_vector(DEPTH-1 DOWNTO 0);
        -- output data
        o_data: out std_logic_vector(DEPTH*WIDTH-1 DOWNTO 0);
        o_empty: out std_logic_vector(DEPTH-1 DOWNTO 0);
        o_rd_en: in std_logic_vector(DEPTH-1 DOWNTO 0);
        
        -- copy part
        block_rd_en: out std_logic;
        o_valid: out std_logic;
        o_sel: out std_logic;
        o_finished: out std_logic
    );
end FSM;

architecture Behavioral of FSM is


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
    
    -- STATE TYPE
    
    type state_type is (IDLE, COMP, COPY);
    
    signal state : state_type := IDLE;
    
    signal count: integer;
    
    signal wr_en: std_logic_vector(DEPTH-1 DOWNTO 0);
    signal wr_en_final: std_logic_vector(DEPTH-1 DOWNTO 0);
    -- output buff
    

    signal o_empty_buff: std_logic_vector(DEPTH-1 DOWNTO 0);
    
    -- buffers sizes
    type integer_array is array (natural range <>) of integer;
    constant FIFO_SIZES : integer_array(0 to DEPTH-1) := ( 1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,    1,
    1,    1,    1,    1,    1,    1,    1,    1,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,    2,
    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,
    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,
    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,
    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,
    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,
    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,
    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,
    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,
    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,
    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,    4,
    4,    4,    4,    4,    4,    4,    4,    4,    8,    8,    8,    8,
    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,
    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,
    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,
    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,
    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,    8,
   16,   16,   16,   16,   16,   16,   16,   16,   16,   16,   16,   16,
   16,   16,   16,   16,   16,   16,   16,   16,   16,   16,   16,   16,
   16,   16,   16,   16,   16,   16,   16,   16,   32,   32,   32,   32,
   32,   32,   32,   32,   32,   32,   32,   32,   32,   32,   32,   32,
   64,   64,   64,   64,   64,   64,   64,   64,  128,  128,  128,  128,
  256,  256,  512, 1024);
begin

    o_empty <= o_empty_buff;
    wr_en_final <= (Others=>i_data_last) when state=IDLE else wr_en; 
    
    FOR_GEN: for I in DEPTH-1 DOWNTO 0 generate
        inst_FIFO_FWFT:FIFO_FWFT
        Generic Map(
            WIDTH   =>  WIDTH,
            DEPTH   => FIFO_SIZES(I)
        )
        Port Map(
            
            clk     =>  clk,
            reset   =>  reset,
            
            wr_en   =>  wr_en_final(I),
            d_in    =>  i_data((I+1)*WIDTH-1 DOWNTO I*WIDTH),
            
            rd_en   =>  o_rd_en(I),
            d_out   =>  o_data((I+1)*WIDTH-1 DOWNTO I*WIDTH),
            
            empty   =>  o_empty_buff(I)
            
        );
    end generate;
    
             
            

    Sync_logic: process(clk, reset)
    begin
        if reset='1' then
            state <= IDLE;
        elsif rising_edge(clk) then
        
        
                  
            if state=IDLE then
            
                if i_data_last='1' then
                    state <= COMP;
                    o_sel <= '1';
                    o_valid <= '1';
                    wr_en <= (Others=>'0');
                    block_rd_en <= '0';
                    o_finished <= '0';
                else
                    o_sel <= '0';
                    o_valid <= '0';
                    wr_en <= (Others=>'0');
                    block_rd_en <= '0';
                    o_finished <= '1';
                end if;
                count <= 0;
                
                
            elsif state=COMP then
            
                if i_full(DEPTH/2-1) = '1' then
                    state <= IDLE;
                    o_sel <= '0';
                    o_valid <= '0';
                    wr_en <= (Others=>'0');
                    block_rd_en <= '0';
                    o_finished <= '1';
                    
                elsif to_integer(unsigned(i_size)) = 2**(count+1) then
                    state <= COPY;
                    count <= count+1;
                    
                    o_sel <= '1';
                    o_valid <='0';
                    wr_en(DEPTH-1 DOWNTO DEPTH-DEPTH/(2**count)) <= (Others=>'1');
                    wr_en((DEPTH-DEPTH/(2**count)-1) DOWNTO 0) <= (Others=>'0');
                    block_rd_en <= '1';
                    o_finished <= '0';
                else
                    o_sel <= '1';
                    o_valid <= '1';
                    wr_en <= (Others=>'0');
                    block_rd_en <= '0';
                    o_finished <= '0';
                end if;
                
                
                            
            elsif state=COPY then
            
                if i_full(DEPTH/2-1) = '1' then
                    state <= IDLE;
                    o_sel <= '0';
                    o_valid <= '0';
                    wr_en <= (Others=>'0');
                    block_rd_en <= '0';
                    o_finished <= '1';
                elsif  to_integer(unsigned(i_size)) = 1 then
                    wr_en <= (Others=>'0');
                elsif i_empty = (i_empty'range =>'1') then
                    state <= COMP;
                    wr_en <= (Others=>'0');
                else
                    o_sel <= '1';
                    o_valid <='0';
                    wr_en(DEPTH-1 DOWNTO DEPTH-DEPTH/(2**count)) <= (Others=>'1');
                    wr_en((DEPTH-DEPTH/(2**count)-1) DOWNTO 0) <= (Others=>'0');
                    block_rd_en <= '1';
                    o_finished <= '0';
                end if;
            end if;
        end if;
    end process;
    
 
end Behavioral;

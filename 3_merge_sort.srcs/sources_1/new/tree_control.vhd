library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tree_control is
    Generic(
        DEPTH: integer;
        WIDTH: integer;
        LEN: integer
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
        o_rd_en: in std_logic_vector(DEPTH-1 DOWNTO 0);
        
        -- second tree control
        sel: out std_logic_vector(4 DOWNTO 0);
        
        i_full_demux: in std_logic;
        i_full_all: in std_logic_vector(31 DOWNTO 0);
        i_wr_en_demux: out std_logic;
        i_rd_en_first_tree: out std_logic;
        i_full_first_tree: in std_logic;
        start: out std_logic
        
    );
end tree_control;

architecture Behavioral of tree_control is

    -- SIPO register
    type sipo_reg_type is array(LEN-1 DOWNTO 0) of std_logic_vector(WIDTH-1 DOWNTO 0);
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
    
    type state_type is (IDLE, FIRST_TREE, COPY, SHIFT, SECOND_TREE);
    signal state, next_state: state_type;
    
    signal sel_buf: std_logic_vector(4 DOWNTO 0);
    signal wr_en_sig: std_logic;
    
    signal count: std_logic_vector(4 DOWNTO 0);
    signal counter: integer;
    signal shifted: std_logic;
    signal start_buf: std_logic;
    
    signal i_wr_en_demux_b, i_rd_en_first_tree_b: std_logic;
begin

    sel<=sel_buf;
    i_wr_en_demux<=i_wr_en_demux_b;
    i_rd_en_first_tree<=i_rd_en_first_tree_b;
    start<=start_buf;

    FOR_GEN: for I in DEPTH-1 DOWNTO 0 generate
        inst_FIFO_FWFT:FIFO_FWFT
        Generic Map(
            WIDTH   =>  WIDTH,
            DEPTH   =>  1
        )
        Port Map(
            
            clk     =>  clk,
            reset   =>  reset,
            
            wr_en   =>  wr_en_sig,
            d_in    =>  sipo_reg(I+(LEN-DEPTH)),
            
            rd_en   =>  o_rd_en(I),
            d_out   =>  o_data((I+1)*WIDTH-1 DOWNTO I*WIDTH),
            
            empty   =>  o_empty(I)
            
        );
    end generate;


    sync_logic:process(clk, reset)
    
    begin
    
    
    
        if reset='1' then
            sipo_reg<=(Others=>(Others=>'0'));
            wr_en_sig<='0';
            count<="00000";
            counter<=0;
            i_rd_en_first_tree_b<='0';
            i_wr_en_demux_b<='0';
            state<=IDLE;            
        elsif rising_edge(clk) then
            
            if i_data_valid='1' then
                sipo_reg<= sipo_reg(sipo_reg'LEFT-1 DOWNTO sipo_reg'RIGHT)&i_data;
            end if;
            
            if state=IDLE then
                sel_buf<="00000";
                start_buf<='0';
                if i_data_last='1' then
                    state<=FIRST_TREE;
                end if;            
            elsif state=FIRST_TREE then
                if i_full_first_tree='1' and start_buf='0' then
                    state<=COPY;
                end if;
            elsif state=COPY then
                if i_full_all="11111111111111111111111111111111" then
                    state<= SECOND_TREE;
                elsif i_full_demux='1' then
                    sel_buf<=std_logic_vector(unsigned(sel_buf)+1);
                    state<=SHIFT;
                end if;
            elsif state=SHIFT then
                if shifted='1' then
                    state<=FIRST_TREE;
                end if;
            elsif state=SECOND_TREE then
                start_buf<='1';
            end if;            
            
            
             if wr_en_sig='1' then
                wr_en_sig<='0';
             elsif i_data_last='1' then
                wr_en_sig<='1';
             elsif state<=FIRST_TREE and unsigned(sel_buf)/=unsigned(count) then
                count<=std_logic_vector(unsigned(count)+1);
                wr_en_sig<='1';
             end if;
        
            if state=COPY then
                if i_wr_en_demux_b='1' and i_rd_en_first_tree_b='1' then
                    i_wr_en_demux_b<='0';
                    i_rd_en_first_tree_b<='0';
                elsif i_full_demux='0' then
                    i_wr_en_demux_b<='1';
                    i_rd_en_first_tree_b<='1';
                end if;
                
                counter<=0;
                
            end if;
                
            if state=SHIFT then
                if counter/=DEPTH then
                sipo_reg<= sipo_reg(sipo_reg'LEFT-1 DOWNTO sipo_reg'RIGHT)&sipo_reg(sipo_reg'LEFT);
                counter<=counter+1;
                elsif counter=DEPTH then
                    shifted<='1';
                end if;
            else
                counter<=0;
                shifted<='0';
            end if;         
         
         end if;
    
    end process;
    
   
end Behavioral;
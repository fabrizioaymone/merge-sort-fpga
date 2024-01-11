library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FSM is
    Generic(
        LEN: integer;
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
        i_size: in std_logic_vector(LEN-1 DOWNTO 0);
        -- output data
        o_data: out std_logic_vector(DEPTH*WIDTH-1 DOWNTO 0);
        o_empty: out std_logic_vector(DEPTH-1 DOWNTO 0);
        o_rd_en: in std_logic_vector(DEPTH-1 DOWNTO 0);
        
        --shift
        
        shift_sig: out std_logic;
        -- copy part
        block_rd_en: out std_logic_vector(DEPTH/2-1 DOWNTO 0);
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
    
    type state_type is (IDLE, COMP, SHIFT, COPY);
    
    signal state, next_state : state_type := IDLE;
    
    signal count: integer;
    
    signal wr_en: std_logic_vector(DEPTH-1 DOWNTO 0);
    signal wr_en_final: std_logic_vector(DEPTH-1 DOWNTO 0);
    -- output buff
    
    signal clock_count: integer;
    signal total_count: integer;
    signal copy_clock_count: integer;

    signal o_empty_buff: std_logic_vector(DEPTH-1 DOWNTO 0);
    
    
    signal i_data_last_ret: std_logic;
    
begin

    o_empty <= o_empty_buff;
    wr_en_final <= (Others=>i_data_last_ret) when state=IDLE else wr_en; 
    
    FOR_GEN: for I in DEPTH-1 DOWNTO 0 generate
        inst_FIFO_FWFT:FIFO_FWFT
        Generic Map(
            WIDTH   =>  WIDTH,
            DEPTH   =>  LEN
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
            i_data_last_ret<='0';
            clock_count<=0;
            total_count<=DEPTH;
        elsif rising_edge(clk) then
            state <= next_state;
            if i_data_last='1' then
                i_data_last_ret<='1';
            elsif i_data_last_ret<='1' then
                i_data_last_ret<='0';
            end if;
            if state=SHIFT then
                clock_count<=clock_count+1;
                total_count<=total_count+1;
                copy_clock_count<=0;
            end if;
            if state=COPY then
                copy_clock_count<=copy_clock_count+1;
                if copy_clock_count<=0 then
                    wr_en<=(Others=>'1');
                    block_rd_en<=(Others=>'1');
                elsif copy_clock_count=1 then
                    wr_en(DEPTH-DEPTH/2-1 DOWNTO 0)<=(Others=>'0');
                elsif copy_clock_count=2 then
                    wr_en(DEPTH-2)<='0';
                    block_rd_en(0)<='0';
                end if;
                if to_integer(unsigned(i_size))=1 then
                    wr_en<=(Others=>'0');
                    block_rd_en<=(Others=>'0');                
                
                end if;
            else
                    wr_en<=(Others=>'0');
                    block_rd_en<=(Others=>'0'); 
            end if;
        end if;
        
    end process;    

    NS_logic: process(i_data_last, i_full, i_empty, state, i_size, clock_count, total_count)
    begin
        case (state) is 
            when IDLE =>
                if i_data_last_ret='1' then
                    next_state <= COMP;
                end if;
                count <= 0;
            when COMP =>
                if i_full(DEPTH/2-1) = '1' then
                    next_state <= IDLE;
                elsif to_integer(unsigned(i_size)) = 2**(count+1) then
                    next_state <= SHIFT;
                    count <= count+1;
                end if;
            when SHIFT =>
                if clock_count=DEPTH/2-1 then
                    next_state <= COPY;
                 end if;
                 if total_count=LEN-1 then
                    next_state <= COPY;
                 end if;
       
            when COPY =>
                count<=0;
                if i_full(DEPTH/2-1) = '1' then
                    next_state <= IDLE;
                elsif to_integer(unsigned(i_size))=1 then -- i_empty = (i_empty'range =>'1') then
                    next_state <= COMP;
                end if;
        end case;
    end process;
    
    output_logic : process(state, clk)
    begin
        case (state) is 
            when IDLE =>
                o_sel <= '0';
                o_valid <= '0';
                o_finished <= '1';
                shift_sig<='0';
            when COMP =>
                o_sel <= '1';
                o_valid <= '1';
                shift_sig<='0';
                o_finished <= '0';
            when SHIFT =>
                o_sel <= '1';
                o_valid <= '0';
                shift_sig <= '1';
                o_finished <= '0';
            when COPY =>
                
                o_sel <= '1';
                o_valid <='0';
                shift_sig<='0';                   -- wr_en(DEPTH-1 DOWNTO DEPTH-DEPTH/2) <= (Others=>'1');
                o_finished <= '0';    
        end case;
    end process; 
end Behavioral;
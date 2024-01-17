library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;
    use IEEE.MATH_REAL.ALL;


entity merge_top is
    Generic(
        DEPTH: integer := 1024;
        WIDTH: integer := 8
    );
    Port (
        axi_clk: in std_logic;
        axi_resetn: in std_logic;
     -- slave interface
        i_data_valid: in std_logic;
        i_data_last: in std_logic;
        i_data: in std_logic_vector(32-1 DOWNTO 0);
        o_data_ready: out std_logic;
     -- master interface
        o_data_valid: out std_logic;
        o_data_last: out std_logic;
        o_data: out std_logic_vector(32-1 DOWNTO 0);
        i_data_ready: in std_logic;
        
     -- interrupt
        intr: out std_logic
    );
end merge_top;

architecture Behavioral of merge_top is

 -- COMPONENTS

    component sipo_reg is
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
    end component;
    
    component FSM is
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
    end component;
    
    component merge_block
        Generic(
            DEPTH_IN: integer;
            WIDTH: integer
            
        );
        Port(
            clk: in std_logic;
            i_valid: in std_logic;
            reset: in std_logic;
            -- input data
            d_in_left, d_in_right: in std_logic_vector(WIDTH-1 DOWNTO 0);
            rd_en_left, rd_en_right: out std_logic;
        --  full_in_left, full_in_right: in std_logic;
            empty_in_left, empty_in_right: in std_logic;
            -- output data
            d_out: out std_logic_vector(WIDTH-1 DOWNTO 0);
            rd_en_out: in std_logic;
            full_out: out std_logic;
            i_size: out std_logic_vector(DEPTH_IN*2-1 DOWNTO 0);  
            empty_out: out std_logic;
            last: out std_logic
            
        );
    end component;

 -- SIGNALS
   
    
    -- output data of sipo_reg 
    signal o_data_sipo_reg: std_logic_vector(DEPTH*WIDTH-1 DOWNTO 0);
    
    -- output data of blocks
    signal o_data_blocks: std_logic_vector(WIDTH*(DEPTH/2)-1 DOWNTO 0);
    signal o_empty_blocks: std_logic_vector((DEPTH/2)-1 DOWNTO 0);
    signal o_full_blocks: std_logic_vector((DEPTH/2)-1 DOWNTO 0);
    signal o_rd_en_blocks: std_logic_vector(DEPTH-1 DOWNTO 0);
    signal i_size: std_logic_vector(DEPTH-1 DOWNTO 0);
    signal o_last_blocks: std_logic_vector(DEPTH-1 DOWNTO 0);
    -- input data to blocks
    signal i_data_blocks: std_logic_vector(DEPTH*WIDTH-1 DOWNTO 0);
    signal i_empty_blocks: std_logic_vector(DEPTH-1 DOWNTO 0);
    signal i_rd_en: std_logic;
    signal i_valid_blocks: std_logic;
    
    -- input data to FSM
    signal i_data_FSM: std_logic_vector(DEPTH*WIDTH-1 DOWNTO 0);
    

    -- select from FSM
    signal sel: std_logic;
    
    signal rd_en_out: std_logic;
    
    signal reset: std_logic;
    signal finished: std_logic;   
    -- size of FIFOs
    type integer_array is array (natural range <>) of integer;
    constant MERGE_BLOCK_SIZES : integer_array(0 to DEPTH/2-1) := (1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,   1,
   1,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,
   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,
   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,
   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,
   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,
   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,
   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,
   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,
   2,   2,   2,   2,   2,   2,   2,   2,   2,   4,   4,   4,   4,   4,   4,
   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,
   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,
   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,
   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   4,   8,   8,
   8,   8,   8,   8,   8,   8,   8,   8,   8,   8,   8,   8,   8,   8,   8,
   8,   8,   8,   8,   8,   8,   8,   8,   8,   8,   8,   8,   8,   8,   8,
  16,  16,  16,  16,  16,  16,  16,  16,  16,  16,  16,  16,  16,  16,  16,
  16,  32,  32,  32,  32,  32,  32,  32,  32,  64,  64,  64,  64, 128, 128,
 256, 512);
    
begin
    
    
    reset<= not axi_resetn;
    intr<='0';
    
    -- slave interface
    o_data_ready<='1';
    
    -- master interface
    o_data <= std_logic_vector(to_unsigned(0, 32 - WIDTH)) & o_data_blocks(WIDTH*DEPTH/2-1 DOWNTO WIDTH*(DEPTH/2-1));
    o_data_valid <= (not o_empty_blocks(DEPTH/2-1)) and finished;
    rd_en_out <=  i_data_ready when sel='0' else i_rd_en;
    o_data_last <= o_last_blocks(DEPTH/2-1) and ((not o_empty_blocks(DEPTH/2-1)) and finished);
    


    inst_sipo_reg:sipo_reg
    Generic Map(
            DEPTH=>DEPTH,
            WIDTH=>WIDTH
        )
    Port Map(
            clk=>axi_clk,
            reset=> reset,
            -- input data
            i_data_valid=> i_data_valid,
            i_data=> i_data(WIDTH-1 DOWNTO 0),
            -- output data
            o_data=>o_data_sipo_reg
    );
    
    inst_FSM:FSM
    Generic Map(
            DEPTH=>DEPTH,
            WIDTH=>WIDTH
        )
    Port Map(
        clk => axi_clk,
        reset => reset,
        
        -- input data
        i_data_last => i_data_last,
        i_data => i_data_FSM,
        
        -- input data from buffers
        
        i_full => o_full_blocks,
        i_empty => o_empty_blocks,
        i_size => i_size,
        
        -- output data
        o_data => i_data_blocks,
        o_empty => i_empty_blocks,
        o_rd_en => o_rd_en_blocks,

        
        -- copy part
        block_rd_en => i_rd_en,
        o_valid => i_valid_blocks,
        o_sel => sel,
        o_finished => finished
    );
    
    -- multiplexer
    
    i_data_FSM(DEPTH/2*WIDTH-1 DOWNTO 0) <= o_data_sipo_reg(DEPTH/2*WIDTH-1 DOWNTO 0);
    with sel select  i_data_FSM(DEPTH*WIDTH-1 DOWNTO DEPTH/2*WIDTH) <= o_data_sipo_reg(DEPTH*WIDTH-1 DOWNTO DEPTH/2*WIDTH) when '0', o_data_blocks when '1', (Others=>'0') when Others;
    
    
    FOR_GEN: for I in DEPTH/2-1 DOWNTO 0 generate
        IF_GEN_1: if I = DEPTH/2-1 generate
        inst_merge_block:merge_block
        Generic Map(
            DEPTH_IN=>MERGE_BLOCK_SIZES(I),
            WIDTH=>WIDTH
        )
        Port Map(
            clk => axi_clk,
            i_valid => i_valid_blocks,
            reset => reset,
            -- input data
            d_in_left => i_data_blocks(WIDTH*((I+1)*2)-1 DOWNTO WIDTH*(2*I+1)),
            d_in_right => i_data_blocks(WIDTH*(2*I+1)-1 DOWNTO WIDTH*(2*I)),
            rd_en_left=>o_rd_en_blocks((I+1)*2-1),
            rd_en_right=>o_rd_en_blocks(I*2),
        --  full_in_left, full_in_right: in std_logic;
            empty_in_left=>i_empty_blocks((I+1)*2-1),
            empty_in_right=>i_empty_blocks(I*2),
            -- output data
            d_out=>o_data_blocks(WIDTH*(I+1)-1 DOWNTO WIDTH*I),
            rd_en_out=>rd_en_out,
            full_out=> o_full_blocks(I),
            i_size=> i_size, 
            empty_out=> o_empty_blocks(I),
            last=> o_last_blocks(I)    
        );
        end generate;
        IF_GEN_2: if I/=DEPTH/2-1 generate
        inst_merge_block:merge_block
        Generic Map(
            DEPTH_IN=>MERGE_BLOCK_SIZES(I),
            WIDTH=>WIDTH
        )
        Port Map(
            clk => axi_clk,
            i_valid => i_valid_blocks,
            reset => reset,
            -- input data
            d_in_left => i_data_blocks(WIDTH*((I+1)*2)-1 DOWNTO WIDTH*(2*I+1)),
            d_in_right => i_data_blocks(WIDTH*(2*I+1)-1 DOWNTO WIDTH*(2*I)),
            rd_en_left=>o_rd_en_blocks((I+1)*2-1),
            rd_en_right=>o_rd_en_blocks(I*2),
        --  full_in_left, full_in_right: in std_logic;
            empty_in_left=>i_empty_blocks((I+1)*2-1),
            empty_in_right=>i_empty_blocks(I*2),
            -- output data
            d_out=>o_data_blocks(WIDTH*(I+1)-1 DOWNTO WIDTH*I),
            rd_en_out=>i_rd_en,
            full_out=> o_full_blocks(I),
            empty_out=> o_empty_blocks(I),
            last=> o_last_blocks(I)    
        );
        end generate;  
    end generate;
    
    
    
        

end Behavioral;

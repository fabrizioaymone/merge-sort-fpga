library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.MATH_REAL.ALL;


entity merge_top is
    Generic(
        DEPTH: integer := 4;
        WIDTH: integer := 32
    );
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
end merge_top;

architecture Behavioral of merge_top is

 -- COMPONENTS

    component tree_control is
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
    end component;
    
    component merge_block is
        Generic(
            DEPTH_IN: integer;
            WIDTH: integer
            
        );
        Port(
            clk: in std_logic;
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
            empty_out: out std_logic;
            last: out std_logic
            
        );
    end component;

 -- SIGNALS
    type record_FIFO is record
        data: std_logic_vector(WIDTH-1 DOWNTO 0);
        rd_en: std_logic;
        empty: std_logic;
        last: std_logic;
    end record record_FIFO;

    type signal_array is array(0 to integer(log2(real(DEPTH))), 0 to DEPTH-1) of record_FIFO;  
    signal connections: signal_array;   
    
    -- tree control output
    signal o_data_tree_control: std_logic_vector(DEPTH*WIDTH-1 DOWNTO 0);
    signal o_empty_tree_control: std_logic_vector(DEPTH-1 DOWNTO 0);
    signal o_rd_en_tree_control: std_logic_vector(DEPTH-1 DOWNTO 0);
    
    signal reset: std_logic;
begin
    
    
    reset<= not axi_resetn;
    intr<='0';
    
    -- slave interface
    o_data_ready<='1';
    
    -- master interface
    o_data <= connections(integer(log2(real(DEPTH))), 0).data;
    o_data_valid <= not connections(integer(log2(real(DEPTH))), 0).empty;
    connections(integer(log2(real(DEPTH))), 0).rd_en <= i_data_ready;
    o_data_last <= connections(integer(log2(real(DEPTH))), 0).last;
    
    inst_tree_control:tree_control
        Generic Map(
            DEPTH=>DEPTH,
            WIDTH=>WIDTH
        )
        Port Map(
            clk=>axi_clk,
            reset=> reset,
            -- input data
            i_data_valid=> i_data_valid,
            i_data_last=> i_data_last,
            i_data=> i_data,
            -- output data
            o_data=>o_data_tree_control,
            o_empty=>o_empty_tree_control,
            o_rd_en=> o_rd_en_tree_control    
        );

FOR_GEN_OUTPUT: for I in DEPTH-1 DOWNTO 0 generate
    connections(0,I).data <= o_data_tree_control((I+1)*WIDTH-1 DOWNTO I*WIDTH);
    o_rd_en_tree_control(I) <= connections(0, I).rd_en;
    connections(0,I).empty <= o_empty_tree_control(I);
end generate;


FOR_GEN_LEVEL: for LEVEL in 0 to integer(log2(real(DEPTH)))-1 generate
    FOR_GEN_INSTANCE: for INSTANCE in 0 to DEPTH/(2**(LEVEL+1))-1 generate
    
        
        inst_merge_block: merge_block
        Generic Map(
            DEPTH_IN => 2**LEVEL,
            WIDTH => WIDTH
        )
        Port Map(
            clk => axi_clk,
            reset => reset,
            
            d_in_left => connections(LEVEL, 2*INSTANCE).data,
            d_in_right => connections(LEVEL, 2*INSTANCE+1).data,
            empty_in_left => connections(LEVEL, 2*INSTANCE).empty,
            empty_in_right => connections(LEVEL, 2*INSTANCE+1).empty,
            rd_en_left => connections(LEVEL, 2*INSTANCE).rd_en,
            rd_en_right => connections(LEVEL, 2*INSTANCE+1).rd_en,
            
            d_out => connections(LEVEL+1, INSTANCE).data,
            empty_out => connections(LEVEL+1, INSTANCE).empty,
            rd_en_out => connections(LEVEL+1, INSTANCE).rd_en,
            last => connections(LEVEL+1, INSTANCE).last
        ); 
        
       
    end generate;
end generate;


end Behavioral;

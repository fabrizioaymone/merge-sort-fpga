library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;
    use IEEE.MATH_REAL.ALL;


entity merge_top is
    Generic(
        DEPTH: integer := 32;
        WIDTH: integer := 8;
        LEN: integer := 1024
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
 -- CONSTANTS
 
 constant N_BUF: integer := LEN/DEPTH;
 -- constant SEL : positive := positive(ceil(log2(real(N_BUF))));
 
 -- COMPONENTS

    component tree_control is
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
            last: out std_logic;
            half: out std_logic;
            
            -- start
            start: in std_logic := '1'
            
        );
    
    end component;
    
    
    component FIFO_FWFT is
        Generic(
            DEPTH: integer;
            WIDTH: integer
            
        );
        Port (
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
            empty  : out std_logic;
         -- is it last?
            last: out std_logic;
            half: out std_logic
    
        );
    end component;

 -- SIGNALS
    type record_FIFO is record
        data: std_logic_vector(WIDTH-1 DOWNTO 0);
        rd_en: std_logic;
        empty: std_logic;
        full: std_logic;
        last: std_logic;
        half: std_logic;
    end record record_FIFO;
    
    type signal_array_mux is array(0 to DEPTH-1) of record_FIFO;  
    signal connections_mux_1, connections_mux_2: signal_array_mux;

    type signal_array is array(0 to integer(log2(real(DEPTH))), 0 to DEPTH-1) of record_FIFO;  
    signal connections: signal_array;   
    
    -- tree control output
    signal o_data_tree_control: std_logic_vector(DEPTH*WIDTH-1 DOWNTO 0);
    signal o_empty_tree_control: std_logic_vector(DEPTH-1 DOWNTO 0);
    signal o_rd_en_tree_control: std_logic_vector(DEPTH-1 DOWNTO 0);
    
    
    signal full_first_tree: std_logic;
    signal start: std_logic;
    
    -- DEMUX
    signal sel_demux: std_logic_vector(4 DOWNTO 0);
    signal i_data_demux: std_logic_vector(WIDTH-1 DOWNTO 0);
    signal i_full_demux: std_logic;
    signal i_wr_en_demux: std_logic;
    
    
    
    -- FIFO BUFFERS 
    signal i_data_buffers: std_logic_vector(N_BUF*WIDTH-1 DOWNTO 0);
    signal i_full_buffers: std_logic_vector(N_BUF-1 DOWNTO 0);
    signal i_wr_en_buffers: std_logic_vector(N_BUF-1 DOWNTO 0);
    
    signal o_data_valid_buf: std_logic;
    signal rd_en_first_tree: std_logic;
    
    signal reset: std_logic;
    
    -- SLAVE INTERFACE
    signal count: integer;
    
    
    
begin
    
    
    reset<= not axi_resetn;
    intr<='0';
    
    -- slave interface
    o_data_ready<='1';
    o_data_valid<=o_data_valid_buf;
    
    inst_tree_control:tree_control
        Generic Map(
            DEPTH=>DEPTH,
            WIDTH=>WIDTH,
            LEN=>LEN
        )
        Port Map(
            clk=>axi_clk,
            reset=> reset,
            -- input data
            i_data_valid=> i_data_valid,
            i_data_last=> i_data_last,
            i_data=> i_data(WIDTH-1 DOWNTO 0),
            -- output data
            o_data=>o_data_tree_control,
            o_empty=>o_empty_tree_control,
            o_rd_en=> o_rd_en_tree_control,
            -- second tree
            sel             =>   sel_demux,
            i_full_demux    =>   i_full_demux, 
            i_full_all      =>   i_full_buffers,
            i_wr_en_demux   =>   i_wr_en_demux,
            i_rd_en_first_tree =>  rd_en_first_tree,
            i_full_first_tree => connections(integer(log2(real(DEPTH))), 0).half,
            start           => start
        );

-- FIRST TREE

FOR_GEN_OUTPUT: for I in DEPTH-1 DOWNTO 0 generate
    connections_mux_1(I).data <= o_data_tree_control((I+1)*WIDTH-1 DOWNTO I*WIDTH);
    o_rd_en_tree_control(I) <= connections_mux_1(I).rd_en;
    connections_mux_1(I).empty <= o_empty_tree_control(I);
end generate;

-- connection to first tree
FOR_GEN_TO_FIRST_TREE: for I in DEPTH-1 DOWNTO 0 generate
    connections(0,I).data <= connections_mux_1(I).data when start='0' else connections_mux_2(I).data;
    connections_mux_1(I).rd_en <= connections(0,I).rd_en when start='0' else '0';
    connections_mux_2(I).rd_en <= connections(0,I).rd_en when start='1' else '0';
    connections(0,I).empty <= connections_mux_1(I).empty when start='0' else connections_mux_2(I).empty;
end generate;


FOR_GEN_LEVEL: for LEVEL in 0 to integer(log2(real(DEPTH)))-1 generate
    FOR_GEN_INSTANCE: for INSTANCE in 0 to DEPTH/(2**(LEVEL+1))-1 generate
    
        
        inst_merge_block: merge_block
        Generic Map(
            DEPTH_IN => 2**LEVEL*DEPTH,
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
            full_out => connections(LEVEL+1, INSTANCE).full,
            rd_en_out => connections(LEVEL+1, INSTANCE).rd_en,
            last => connections(LEVEL+1, INSTANCE).last,
            half => connections(LEVEL+1, INSTANCE).half
        ); 
        
       
    end generate;
end generate;

-- LAST MERGE BLOCK -> DEMUX


    i_data_demux <= connections(integer(log2(real(DEPTH))), 0).data when start='0' else (Others=>'0');
    
                                          
  demux_for_full: for I in 31 DOWNTO 0 generate
   i_data_buffers((I+1)*WIDTH-1 DOWNTO I*WIDTH)<=i_data_demux when to_integer(unsigned(sel_demux)) = abs(I-31) else (Others=>'0');
  end generate;
       
    with sel_demux select i_full_demux <= i_full_buffers(31) when "00000",
                                          i_full_buffers(30) when "00001",
                                          i_full_buffers(29) when "00010",
                                          i_full_buffers(28) when "00011",
                                          i_full_buffers(27) when "00100",
                                          i_full_buffers(26) when "00101",
                                          i_full_buffers(25) when "00110",
                                          i_full_buffers(24) when "00111",
                                          i_full_buffers(23) when "01000",
                                          i_full_buffers(22) when "01001",
                                          i_full_buffers(21) when "01010",
                                          i_full_buffers(20) when "01011",
                                          i_full_buffers(19) when "01100",
                                          i_full_buffers(18) when "01101",
                                          i_full_buffers(17) when "01110",
                                          i_full_buffers(16) when "01111",
                                          i_full_buffers(15) when "10000",
                                          i_full_buffers(14) when "10001",
                                          i_full_buffers(13) when "10010",
                                          i_full_buffers(12) when "10011",
                                          i_full_buffers(11) when "10100",
                                          i_full_buffers(10) when "10101",
                                          i_full_buffers(9) when "10110",
                                          i_full_buffers(8) when "10111",
                                          i_full_buffers(7) when "11000",
                                          i_full_buffers(6) when "11001",
                                          i_full_buffers(5) when "11010",
                                          i_full_buffers(4) when "11011",
                                          i_full_buffers(3) when "11100",
                                          i_full_buffers(2) when "11101",
                                          i_full_buffers(1) when "11110",
                                          i_full_buffers(0) when "11111",
                                          '0' when others;
  
  demux_for_wr_en: for I in 31 DOWNTO 0 generate
    i_wr_en_buffers(I)<=i_wr_en_demux when to_integer(unsigned(sel_demux)) = abs(I-31) else '0';
  end generate;  
          
    
FOR_GEN_BUFFERS: for I in N_BUF-1 DOWNTO 0 generate
    inst_FIFO_FWFT:FIFO_FWFT
    Generic Map(
        WIDTH   =>  WIDTH,
        DEPTH   =>  DEPTH
    )
    Port Map(
        
        clk     =>  axi_clk,
        reset   =>  reset,
        
        wr_en   =>  i_wr_en_buffers(I),
        d_in    =>  i_data_buffers((I+1)*WIDTH-1 DOWNTO I*WIDTH),
        
        rd_en   =>  connections_mux_2(I).rd_en,
        d_out   =>  connections_mux_2(I).data,
        full    =>  i_full_buffers(I),
        empty   =>  connections_mux_2(I).empty
        
    );
end generate;
    
    -- master interface
    o_data <= (std_logic_vector(to_unsigned(0, 32 - WIDTH)) & connections(integer(log2(real(DEPTH))), 0).data) when start='1' else (Others=>'0');
    o_data_valid_buf <= not connections(integer(log2(real(DEPTH))), 0).empty when start='1' else '0';
    connections(integer(log2(real(DEPTH))), 0).rd_en <= i_data_ready when start='1' else rd_en_first_tree;
    
    o_data_last <= connections(integer(log2(real(DEPTH))), 0).last;
    
end Behavioral;
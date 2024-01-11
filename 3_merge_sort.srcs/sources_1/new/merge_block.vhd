library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity merge_block is
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

end merge_block;

architecture Behavioral of merge_block is

-- COMPONENTS

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
 
 -- signals to FIFO
signal d_in: std_logic_vector(WIDTH-1 DOWNTO 0);
signal wr_en: std_logic;
signal full_int: std_logic;
signal empty_int: std_logic;
 -- signals to read from left and right input FIFOs
signal rd_en_left_int: std_logic;
signal rd_en_right_int: std_logic;

begin

-- read from input

rd_en_left<=rd_en_left_int;
rd_en_right<=rd_en_right_int;

inst_FIFO_FWFT: FIFO_FWFT
    Generic Map(
        DEPTH=>2*DEPTH_IN,
        WIDTH=>WIDTH
        
    )
    Port Map(
        clk=>clk,
        reset=>reset,
        d_in=>d_in,
        d_out=>d_out,
        rd_en=> rd_en_out,
        wr_en=>wr_en,
        full=>full_int,
        empty=>empty_int,
        last=> last,
        half=> half
    );

-- signal to output

empty_out<= empty_int;
full_out<=full_int;


process(clk, reset)

begin

if reset='1' then
    rd_en_right_int<='0';
    rd_en_left_int<='0';
    wr_en<='0';
elsif rising_edge(clk) then
    
    if rd_en_right_int='1' or rd_en_left_int='1' then
        rd_en_right_int<='0';
        rd_en_left_int <='0';
        wr_en<='0'; 
    elsif empty_in_left='0' and empty_in_right='0' and start='1' then
        wr_en<='1';
        if unsigned(d_in_left)<= unsigned(d_in_right) then
            d_in<=d_in_left;
            rd_en_left_int<='1';
            rd_en_right_int<='0';
        else
            d_in<=d_in_right;
            rd_en_right_int<='1';
            rd_en_left_int<='0';
        end if;
    elsif empty_in_left='1' and empty_in_right='0' and start='1' then
        wr_en<='1';
        d_in<=d_in_right;
        rd_en_right_int<='1';
        rd_en_left_int<='0';
    elsif empty_in_left='0' and empty_in_right='1' and start='1' then
        wr_en<='1';
        d_in<=d_in_left;
        rd_en_left_int<='1';
        rd_en_right_int<='0';
    elsif empty_in_left='1' and empty_in_right='1' then
        wr_en<='0';
        rd_en_left_int<='0';
        rd_en_right_int<='0';
    end if;

end if;

end process;


end Behavioral;


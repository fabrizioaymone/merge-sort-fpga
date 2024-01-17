library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.MATH_REAL.ALL;
    
entity FIFO_FWFT is
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
     -- is it half full
        half: out std_logic

    );
end FIFO_FWFT;

architecture Behavioral of FIFO_FWFT is
 -- register bank   
    type mem_type is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 DOWNTO 0);
    signal mem: mem_type;
    
    signal wr_ptr, rd_ptr: integer range 0 to DEPTH-1 := 0;
    signal count: integer range 0 to DEPTH := 0;
    
    signal full_int, empty_int: std_logic;
    
    signal last_count: integer;
     
     
     


     
     
begin

    d_out <= mem(rd_ptr); 

 -- full and empty
    full_int <= '1' when count=DEPTH else '0';
    empty_int <= '1' when count=0 else '0';
    half <= '1' when count= integer(sqrt(real(DEPTH))) else '0';
    
    full <= full_int;
    empty <= empty_int;
    
    last <= '1' when last_count=DEPTH*2-1 else '0';
    
    
    process(clk, reset)
    
    begin 
        if reset = '1' then
            count <= 0;
            last_count <=0;
            wr_ptr <= 0;
            rd_ptr <= 0;
            mem<=(Others=>(Others=>'0'));
        elsif rising_edge(clk) then
                
             if wr_en='1' and rd_en = '0' then
                if full_int='0' then
                    count<= count+1;
                    mem(wr_ptr) <= d_in;
                end if;
             
             elsif  wr_en = '0' and rd_en ='1' then
                if empty_int = '0' then
                    count <= count-1;
                    last_count <= last_count+1;
                end if;
             
             
             elsif wr_en='1' and rd_en='1' then
                if empty_int='1' then
                    count <= count+1;
                elsif full_int='1' then
                    count <= count-1;                    
                end if;            
            end if;         
    
             -- wr
             
             if wr_en ='1' and full_int='0' then
                if wr_ptr = DEPTH-1 then
                    wr_ptr<=0;
                else
                    wr_ptr <= wr_ptr+1;
                end if;
             end if;
             
             -- rd
             if rd_en='1' and empty_int='0' then
                if rd_ptr=DEPTH-1 then
                    rd_ptr<=0;
                else
                    rd_ptr<=rd_ptr+1;
                end if;
            end if;
            
            if wr_en='1' and full_int='0' then
                mem(wr_ptr) <= d_in;
            end if;
            
      end if;
end process;     

    

    

end Behavioral;
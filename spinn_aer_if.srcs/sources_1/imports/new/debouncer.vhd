LIBRARY ieee;
USE ieee.std_logic_1164.all;

entity debouncer is
    generic(
        clk_freq     : integer:= 150000000; 
        microseconds : integer := 10000
        );   
    port(
        button  : in std_logic;  
        result  : out std_logic; 
        clk     : in std_logic;  
        rst     : in std_logic  
        );
end debouncer;

architecture Behavioral of debouncer is

    -- signals
    signal ff          : std_logic_vector(1 downto 0);
    signal counter_set : std_logic; 

begin
 
    counter_set <= ff(0) xor ff(1); 
  
    debouncher_proc : process(clk)
      
    -- process variables
    variable cnt :  integer range 0 to clk_freq/1000000 * microseconds - 1;

    begin
       
        if rising_edge(clk) then
            if rst = '1' then
                ff(1 downto 0) <= "00";
                result <= '0'; 
            else
                ff(0) <= button;
                ff(1) <= ff(0);
            
                if counter_set = '1' then
                    cnt := 0;
                elsif cnt < clk_freq/1000000 * microseconds - 1 then
                    cnt := cnt + 1;
                else
                    result <= ff(1);
                end if;            
            end if;
        end if;
    
    end process debouncher_proc;

end Behavioral;
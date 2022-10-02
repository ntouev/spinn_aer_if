library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity synchronizer is
    port (
        sync_in : in std_logic;
        
        sync_out : out std_logic;
        
        clk : in std_logic
    );
end synchronizer;

architecture Behavioral of synchronizer is

    --signals
    signal temp : std_logic;

begin
    
    sync : process (clk)
    begin
        if rising_edge(clk) then
            temp <= sync_in;
            sync_out <= temp;
        end if;
    end process sync;

end Behavioral;
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity spinn_driver is
    port (
        pkt_data  : in std_logic_vector (39 downto 0);
        spinn_ack : in std_logic;
        new_packet: in std_logic;

        spinn_data: out std_logic_vector (6 downto 0);
        busy      : out std_logic; -- gets HIGH while transmitting 11 flits

        clk : in std_logic;
        rst : in std_logic
    );
end spinn_driver;

architecture Behavioral of spinn_driver is

    -- signals
    signal bit_bucket : std_logic_vector (3 downto 0);
    signal bucket_cnt : integer;
    signal spinn_ack_old : std_logic;
    signal spinn_data_i : std_logic_vector (6 downto 0) := "0000000";
    
    -- spinn_driver FSM
    type state_type is (RESET, WAIT_FOR_NEW_PKT_RISE, WAIT_FOR_NEW_PKT_FALL, UPDATE_SPINN_DATA, WAIT_FOR_FIRST_ACK, BUCKET_CNT_INCREMENT, WAIT_FOR_ACK);
    signal state: state_type := RESET;

begin

buffer_spinn_data_output : process (clk) is
begin
    if rising_edge(clk) then
        spinn_data <= spinn_data_i; 
    end if;
end process buffer_spinn_data_output;
	
	with bucket_cnt select bit_bucket <=
	   pkt_data(3  downto 0)  when 0,
	   pkt_data(7  downto 4)  when 1,
	   pkt_data(11 downto 8)  when 2,
	   pkt_data(15 downto 12) when 3,
	   pkt_data(19 downto 16) when 4,
	   pkt_data(23 downto 20) when 5,
	   pkt_data(27 downto 24) when 6,
	   pkt_data(31 downto 28) when 7,	   
	   pkt_data(35 downto 32) when 8,
	   pkt_data(39 downto 36) when 9,
	              "1111" when others;  

    spinn_driver_fsm : process(clk) is
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= RESET;
            else
                case state is
                    when RESET =>
                        busy <= '0';
                        bucket_cnt <= 0;    
                        spinn_ack_old <= spinn_ack;
                        state <= WAIT_FOR_NEW_PKT_RISE;
                        
                    when WAIT_FOR_NEW_PKT_RISE =>
                        if new_packet = '1' then
                            busy <= '1';
                            bucket_cnt <= 0;
                            spinn_ack_old <= spinn_ack;
                            state <= WAIT_FOR_NEW_PKT_FALL;
                        else
                            busy <= '0';
                            bucket_cnt <= 0; 
                            spinn_ack_old <= spinn_ack;
                            state <= WAIT_FOR_NEW_PKT_RISE;       
                        end if;
                        
                    when WAIT_FOR_NEW_PKT_FALL =>
                        if new_packet = '0' then
                            busy <= '1';
                            bucket_cnt <= 0;
                            spinn_ack_old <= spinn_ack;
                            state <= WAIT_FOR_FIRST_ACK;
                        else
                            busy <= '1';
                            bucket_cnt <= 0; 
                            spinn_ack_old <= spinn_ack;
                            state <= WAIT_FOR_NEW_PKT_FALL;       
                        end if;
                    
                    when WAIT_FOR_FIRST_ACK =>
                                if bit_bucket = "0000" then
                                    spinn_data_i <= spinn_data_i xor "0010001";
                                elsif bit_bucket = "0001" then
                                    spinn_data_i <= spinn_data_i xor "0010010";
                                else
                                    spinn_data_i <= spinn_data_i xor "1111111";
                                end if;
                    
                                busy <= '1';
                                bucket_cnt <= 0;
                                spinn_ack_old <= spinn_ack;
                                state <= BUCKET_CNT_INCREMENT;
                                
                    when BUCKET_CNT_INCREMENT =>   
                                busy <= '1';
                                bucket_cnt <= bucket_cnt + 1;
                                state <= WAIT_FOR_ACK;         
                                
                    when WAIT_FOR_ACK =>
                        if spinn_ack /= spinn_ack_old  then
                            
                            spinn_ack_old <= spinn_ack;
                            
                            if bucket_cnt < 10 then
                                if bit_bucket = "0000" then
                                    spinn_data_i <= spinn_data_i xor "0010001";
                                elsif bit_bucket = "0001" then
                                    spinn_data_i <= spinn_data_i xor "0010010";
                                elsif bit_bucket = "0010" then
                                    spinn_data_i <= spinn_data_i xor "0010100";
                                elsif bit_bucket = "0011" then
                                    spinn_data_i <= spinn_data_i xor "0011000";
                
                                elsif bit_bucket = "0100" then
                                    spinn_data_i <= spinn_data_i xor "0100001";
                                elsif bit_bucket = "0101" then
                                    spinn_data_i <= spinn_data_i xor "0100010";              
                                elsif bit_bucket = "0110" then
                                    spinn_data_i <= spinn_data_i xor "0100100";
                                elsif bit_bucket = "0111" then
                                    spinn_data_i <= spinn_data_i xor "0101000";
                
                                elsif bit_bucket = "1000" then
                                    spinn_data_i <= spinn_data_i xor "1000001";
                                elsif bit_bucket = "1001" then
                                    spinn_data_i <= spinn_data_i xor "1000010";
                                elsif bit_bucket = "1010" then
                                    spinn_data_i <= spinn_data_i xor "1000100";
                                elsif bit_bucket = "1011" then
                                    spinn_data_i <= spinn_data_i xor "1001000";
                
                                elsif bit_bucket = "1100" then
                                    spinn_data_i <= spinn_data_i xor "0000011";
                                elsif bit_bucket = "1101" then
                                    spinn_data_i <= spinn_data_i xor "0000110";              
                                elsif bit_bucket = "1110" then
                                    spinn_data_i <= spinn_data_i xor "0001100";
                                elsif bit_bucket = "1111" then
                                    spinn_data_i <= spinn_data_i xor "0001001";
                                else
                                    spinn_data_i <= spinn_data_i xor "1111111";
                                end if;
                            
                                busy <= '1';
                                state <= BUCKET_CNT_INCREMENT;
                            elsif bucket_cnt = 10 then    
                                spinn_data_i <= spinn_data_i xor "1100000";
                                busy <= '1';
                                state <= BUCKET_CNT_INCREMENT;
                            else
                                -- 
                            end if;
                        else
                        -- come here if spinn_ack_old == spinn_ack
                            if bucket_cnt = 11 then
                                busy <= '0';
                                bucket_cnt <= 0;
                                state <= WAIT_FOR_NEW_PKT_RISE;
                            else
                                state <= WAIT_FOR_ACK;
                            end if;
                        end if;
                    
                    when others =>
                        -- 
                end case;
            end if;
        end if;
    end process spinn_driver_fsm;

end Behavioral;

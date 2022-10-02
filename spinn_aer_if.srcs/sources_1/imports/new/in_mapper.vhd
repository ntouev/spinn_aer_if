library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity in_mapper is
    port (
        aer_data : in std_logic_vector (14 downto 0);  -- 15th bit is always 0 so ignore it
        aer_req : in std_logic;
        aer_ack : out std_logic;

        new_packet: out std_logic;
        pkt_data : out std_logic_vector (39 downto 0);

        busy : in std_logic;
        
        start : in std_logic;

        clk : in std_logic;
        rst : in std_logic
    );
end in_mapper;

architecture Behavioral of in_mapper is

    -- constants
    constant VIRTUAL_KEY : std_logic_vector (15 downto 0) := x"fefe";
    constant MULTICAST_PACKET : std_logic_vector (1 downto 0) := "00";
    constant TIMESTAMP_NOT_SUPPORTED : std_logic_vector (1 downto 0) := "00";
    constant PAYLOD : std_logic := '0';

    -- signals
    signal parity : std_logic;
    signal pkt_data_i        : std_logic_vector (38 downto 0); -- whole packet excluding parity
    signal new_packet_i      : std_logic;                      -- triggers a new conversion in spinn_driver module after -> ON -> OFF
    signal ticks             : integer;
    signal ticks_rst         : std_logic;
    signal new_packet_enable : std_logic;

    -- 4 phase ack FSM 
    type state_type is (RESET, WAIT_FOR_RECEIVE_DUMMY, WAIT_FOR_REQUEST_DUMMY, CHECK_FOR_RESET_DUMMY, CHECK_START, WAIT_FOR_RECEIVE, WAIT_FOR_REQUEST, CHECK_FOR_RESET);
    signal state : state_type := RESET;

begin

    new_packet <= new_packet_i;

    dump_proc: process (clk)
    begin
        if rising_edge(clk) then
            if (busy = '0') and (new_packet_enable = '1') then
                pkt_data <= pkt_data_i & parity;
            end if;
        end if;
    end process dump_proc;

    pkt_data_i <= VIRTUAL_KEY & '0' & aer_data & MULTICAST_PACKET & "00" & TIMESTAMP_NOT_SUPPORTED & PAYLOD;
    
    parity <= not( 
              '0' xor pkt_data_i(38) xor pkt_data_i(37) xor pkt_data_i(36) xor pkt_data_i(35) xor pkt_data_i(34) xor pkt_data_i(33) xor pkt_data_i(32) xor pkt_data_i(31) xor
                      pkt_data_i(30) xor pkt_data_i(29) xor pkt_data_i(28) xor pkt_data_i(27) xor pkt_data_i(26) xor pkt_data_i(25) xor pkt_data_i(24) xor pkt_data_i(23) xor
                      pkt_data_i(22) xor pkt_data_i(21) xor pkt_data_i(20) xor pkt_data_i(19) xor pkt_data_i(18) xor pkt_data_i(17) xor pkt_data_i(16) xor pkt_data_i(15) xor
                      pkt_data_i(14) xor pkt_data_i(13) xor pkt_data_i(12) xor pkt_data_i(11) xor pkt_data_i(10) xor pkt_data_i(9)  xor pkt_data_i(8)  xor pkt_data_i(7)  xor
                      pkt_data_i(6)  xor pkt_data_i(5)  xor pkt_data_i(4)  xor pkt_data_i(3)  xor pkt_data_i(2)  xor pkt_data_i(1)  xor pkt_data_i(0)
                 );

    four_phase_ack_fsm : process (clk)
    begin
        if rising_edge(clk) then
            case state is
                when RESET =>
                    new_packet_i <= '0';
                    aer_ack <= '1';
                    ticks_rst <= '0';
                    state <= CHECK_START;
                        
                when CHECK_START =>
                    if start = '1' then
                        state <= WAIT_FOR_RECEIVE;
                    else
                        state <= WAIT_FOR_RECEIVE_DUMMY;
                    end if;    
                        
                when WAIT_FOR_RECEIVE_DUMMY =>
                    if aer_req = '0' then  
                        aer_ack <= '0';
                        state <= WAIT_FOR_REQUEST_DUMMY;
                    else
                        aer_ack <= '1';
                        state <= WAIT_FOR_RECEIVE_DUMMY;
                    end if;                  
                    
                when WAIT_FOR_REQUEST_DUMMY =>
                    if aer_req = '1' then
                        aer_ack <= '1';
                        state <= CHECK_FOR_RESET_DUMMY;
                    else
                        aer_ack <= '0';
                        state <= WAIT_FOR_REQUEST_DUMMY;
                    end if;
                        
                when CHECK_FOR_RESET_DUMMY =>
                    if rst = '1' then
                        state <= RESET;
                    else
                        state <= CHECK_START;    
                    end if;
                            
                when WAIT_FOR_RECEIVE =>
                    if aer_req = '0' then  

                        if (busy = '0') and (new_packet_enable = '1') then
                            new_packet_i <= '1';
                            ticks_rst <= '1';
                        end if;  

                        aer_ack <= '0';
                        state <= WAIT_FOR_REQUEST;
                    else
                        aer_ack <= '1';
                        state <= WAIT_FOR_RECEIVE;
                    end if;
                    
                when WAIT_FOR_REQUEST =>
                       
                    new_packet_i <= '0';
                    ticks_rst <= '0';
                        
                    if aer_req = '1' then
                        aer_ack <= '1';
                        state <= CHECK_FOR_RESET;
                    else
                        aer_ack <= '0';
                        state <= WAIT_FOR_REQUEST;
                    end if;
                        
                when CHECK_FOR_RESET =>
                    if rst = '1' then
                        state <= RESET;
                    else
                        state <= WAIT_FOR_RECEIVE;    
                    end if;
                        
                when others =>
                    -- catch all the rest cases here
            end case;
        end if;
    end process four_phase_ack_fsm;

    max_spinn_triggering_proc : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                new_packet_enable <= '0';
                ticks <= 0;
            else
                if ticks_rst = '1' then
                    ticks <= 0;
                else   
                    -- 3000 --> 50 kHz  limit,
                    -- 1500 --> 100 kHz limit,
                    -- 1000 --> 150 kHz limit,
                    -- 750 --> 200 kHz  limit
                     if ticks >= 1000 - 1 then 
                        new_packet_enable <= '1';
                    else
                        new_packet_enable <= '0';
                        ticks <= ticks + 1;
                    end if;
                end if;
            end if;

        end if;
    end process max_spinn_triggering_proc;

end Behavioral;
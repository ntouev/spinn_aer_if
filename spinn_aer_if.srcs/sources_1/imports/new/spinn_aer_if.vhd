library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity spinn_aer_if is
    port (
        dbg_busy: out std_logic;
        
        -- dvs side
        aer_data : in std_logic_vector (14 downto 0);
        aer_req  : in std_logic;
        aer_ack  : out std_logic;
        dbg_aer_ack: out std_logic;

        -- spinnaker side
        spinn_ack : in std_logic;
        spinn_data: out std_logic_vector (6 downto 0);
        
        -- clocks
        sysclk : in std_logic; -- 12 MHz
        rst_btn : in std_logic;
        rst_sw : in std_logic;
         
        -- UI
        start_btn : in std_logic;
        start_sw : in std_logic;
        led : out std_logic_vector (1 downto 0);
--        led0_b : out std_logic;
--        led0_r : out std_logic;
        led0_g : out std_logic
    );
end spinn_aer_if;

architecture Behavioral of spinn_aer_if is

    -- clock
    component clk_wiz_0
        port (
            clk_out1 : out std_logic;
            reset : in std_logic;
            locked : out std_logic;
            clk_in1 : in std_logic
        );
    end component;

    -- debouncer
    -- the following is configured for 150 MHz clock. 
    -- Adjust appropriately if clock changes!
    component debouncer
        port (       
            button : in std_logic;
            result : out std_logic;
            
            clk : in std_logic;
            rst: in std_logic
        );
    end component;

    -- synchronizer
    component synchronizer
        port (
            sync_in : in std_logic;
            sync_out : out std_logic;
            clk : in std_logic
        );
    end component;

    -- in_mapper
    component in_mapper
        port (
            aer_data : in std_logic_vector (14 downto 0);
            aer_req : in std_logic;
            aer_ack : out std_logic;

            new_packet: out std_logic;
            pkt_data : out std_logic_vector (39 downto 0);

            busy : in std_logic;
            
            start : in std_logic;
            
            clk : in std_logic;
            rst : in std_logic
        );
    end component;

    -- spinn_driver
    component spinn_driver
        port (
            pkt_data  : in std_logic_vector (39 downto 0);
            spinn_ack : in std_logic;
            new_packet: in std_logic;

            spinn_data: out std_logic_vector (6 downto  0);
            busy      : out std_logic;

            clk : in std_logic;
            rst : in std_logic
        );
    end component;


    -- signals
    signal locked : std_logic;
    signal clk : std_logic;
    signal rst : std_logic;
    signal clk_rst : std_logic;
    signal ticks : integer;
    signal led_0 : std_logic;
    signal synched_aer_req : std_logic;
    signal synched_spinn_ack : std_logic;
    signal new_packet : std_logic;
    signal busy       : std_logic; 
    signal pkt_data : std_logic_vector (39 downto 0);
    signal debounched_start : std_logic;
    signal aer_ack_i : std_logic;
    signal start : std_logic;
begin

    inst_clk_wiz_0 : clk_wiz_0
    port map(
        clk_out1 => clk,
        reset => clk_rst,
        locked => locked,
        clk_in1 => sysclk
    );

    inst_aer_req_synchronizer : synchronizer
    port map(
        sync_in => aer_req,
        sync_out => synched_aer_req,
        clk => clk
    );

    inst_start_debouncer : debouncer
    port map(       
        button => start,
        result => debounched_start,
            
        clk => clk,
        rst => rst
    );

    inst_spinn_ack_synchronizer : synchronizer
    port map(
        sync_in => spinn_ack,
        sync_out => synched_spinn_ack,
        clk => clk
    );

    inst_in_mapper : in_mapper
    port map(
        aer_data => aer_data,
        aer_req => synched_aer_req,
        aer_ack => aer_ack_i,

        new_packet => new_packet,
        pkt_data => pkt_data,
        
        busy => busy,
        
        start => debounched_start,

        clk => clk,
        rst => rst
    );

    inst_spinn_driver : spinn_driver
    port map(
        pkt_data => pkt_data,
        spinn_ack => synched_spinn_ack,
        new_packet => new_packet,

        spinn_data => spinn_data,
        busy  => busy,

        clk => clk,
        rst => rst
    );

    -- tie clock reset to gnound till this is actually needed
    clk_rst <= '0';
    rst <= rst_btn or rst_sw;
    start <= start_btn or start_sw;    

    dbg_busy <= not(busy);  -- red light brightness according to traffic (spinnaker side)
    dbg_aer_ack <= aer_ack_i; -- blue light brightness according to traffic (aer side)
    aer_ack <= aer_ack_i;
    
   -----------------------------------------------------------------------------------------------------------------
   -------------------------------------------------- led driver ---------------------------------------------------
   -----------------------------------------------------------------------------------------------------------------

    led(0) <= led_0;
    led(1) <= '0';   -- tie to ground for now
    
    led0_g <= '1';   -- negative logic rgb led

    -- toggle led with  1Hz freq to validate clk (visually)    
    one_hertz_led_toggling : process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                led_0 <= '0';
                ticks <= 0;
            else   
                if ticks = 150000000 - 1 then
                    ticks <= 0;
                    led_0 <= led_0 xor '1';
                else
                    ticks <= ticks + 1;
                end if;
            end if;
        end if;
    end process one_hertz_led_toggling;
   -----------------------------------------------------------------------------------------------------------------

end Behavioral;
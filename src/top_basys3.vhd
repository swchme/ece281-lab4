library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Lab 4
entity top_basys3 is
    port(
        -- inputs
        clk     : in std_logic;
        sw      : in std_logic_vector(15 downto 0);
        btnU    : in std_logic;
        btnL    : in std_logic;
        btnR    : in std_logic;

        -- outputs
        led     : out std_logic_vector(15 downto 0);
        seg     : out std_logic_vector(6 downto 0);
        an      : out std_logic_vector(3 downto 0)
    );
end top_basys3;

architecture top_basys3_arch of top_basys3 is

    -- Signal declarations
    signal w_slow_clk : std_logic;
    signal w_floor1   : std_logic_vector(3 downto 0);
    signal w_floor2   : std_logic_vector(3 downto 0);
    signal w_seg1     : std_logic_vector(6 downto 0);
    signal w_seg2     : std_logic_vector(6 downto 0);
    signal w_seg_f    : std_logic_vector(6 downto 0);
    signal r_an       : std_logic_vector(3 downto 0);  -- Internal signal for anode control

    -- Component declarations
    component clock_divider is
        generic (constant k_DIV : natural := 2);
        port (
            i_clk   : in std_logic;
            i_reset : in std_logic;
            o_clk   : out std_logic
        );
    end component;

    component elevator_controller_fsm is
        port (
            i_clk       : in std_logic;
            i_reset     : in std_logic;
            is_stopped  : in std_logic;
            go_up_down  : in std_logic;
            o_floor     : out std_logic_vector(3 downto 0)
        );
    end component;

    component sevenseg_decoder is
        port (
            i_Hex   : in std_logic_vector(3 downto 0);
            o_seg_n : out std_logic_vector(6 downto 0)
        );
    end component;

begin

    -- Clock Divider (0.5s)
    u_clkdiv : clock_divider
        generic map (k_DIV => 25000000)
        port map (
            i_clk   => clk,
            i_reset => btnL,
            o_clk   => w_slow_clk
        );

    -- Elevator FSM 1
    u_elevator1 : elevator_controller_fsm
        port map (
            i_clk       => w_slow_clk,
            i_reset     => btnR,
            is_stopped  => sw(0),
            go_up_down  => sw(1),
            o_floor     => w_floor1
        );

    -- Elevator FSM 2
    u_elevator2 : elevator_controller_fsm
        port map (
            i_clk       => w_slow_clk,
            i_reset     => btnR,
            is_stopped  => sw(14),
            go_up_down  => sw(15),
            o_floor     => w_floor2
        );

    -- 7-Segment Decoders
    u_decoder1 : sevenseg_decoder
        port map (
            i_Hex   => w_floor1,
            o_seg_n => w_seg1
        );

    u_decoder2 : sevenseg_decoder
        port map (
            i_Hex   => w_floor2,
            o_seg_n => w_seg2
        );

    u_decoder_f : sevenseg_decoder
        port map (
            i_Hex   => "1111",   -- hex "F"
            o_seg_n => w_seg_f
        );

    -- LED Display Debug
    led(15)          <= w_slow_clk;
    led(14 downto 8) <= (others => '0');
    led(7 downto 4)  <= w_floor2;
    led(3 downto 0)  <= w_floor1;

    -- Active-Low Anode Control (static)
    -- an(0) = elevator 1
    -- an(2) = elevator 2
    -- an(1), an(3) = show "F"
    r_an <= "1011"; -- Example: Enable elevator 2 display (an2) and others off
    an <= r_an;     -- Connect internal signal to output port

    -- Multiplex the segment outputs using with-select
    with r_an select
        seg <= w_seg1   when "1110",  -- an(0) - elevator 1
               w_seg_f  when "1101",  -- an(1) - "F"
               w_seg2   when "1011",  -- an(2) - elevator 2
               w_seg_f  when "0111",  -- an(3) - "F"
               "1111111" when others; -- off

end top_basys3_arch;
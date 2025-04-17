library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

-- Lab 4
entity top_basys3 is
    port(
        -- inputs
        clk     :   in std_logic; -- native 100MHz FPGA clock
        sw      :   in std_logic_vector(15 downto 0);
        btnU    :   in std_logic; -- master_reset
        btnL    :   in std_logic; -- clk_reset
        btnR    :   in std_logic; -- fsm_reset

        -- outputs
        led :   out std_logic_vector(15 downto 0);
        seg :   out std_logic_vector(6 downto 0); -- 7-segment segments (active-low)
        an  :   out std_logic_vector(3 downto 0)  -- anodes (active-low)
    );
end top_basys3;

architecture top_basys3_arch of top_basys3 is

    -- signal declarations
    signal w_slow_clk         : std_logic;
    signal w_fast_clk         : std_logic;  -- used for TDM
    signal w_floor1           : std_logic_vector(3 downto 0);
    signal w_floor2           : std_logic_vector(3 downto 0);
    signal w_seg1             : std_logic_vector(6 downto 0);
    signal w_seg2             : std_logic_vector(6 downto 0);
    signal w_mux_data         : std_logic_vector(3 downto 0);
    signal w_sel              : std_logic_vector(3 downto 0);
    signal w_seg_muxed        : std_logic_vector(6 downto 0);

    -- component declarations
    component sevenseg_decoder is
        port (
            i_Hex : in STD_LOGIC_VECTOR (3 downto 0);
            o_seg_n : out STD_LOGIC_VECTOR (6 downto 0)
        );
    end component;

    component elevator_controller_fsm is
        port (
            i_clk        : in  STD_LOGIC;
            i_reset      : in  STD_LOGIC;
            is_stopped   : in  STD_LOGIC;
            go_up_down   : in  STD_LOGIC;
            o_floor      : out STD_LOGIC_VECTOR (3 downto 0)
        );
    end component;

    component TDM4 is
        generic ( constant k_WIDTH : natural := 4);
        port (
            i_clk    : in  STD_LOGIC;
            i_reset  : in  STD_LOGIC;
            i_D3     : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            i_D2     : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            i_D1     : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            i_D0     : in  STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            o_data   : out STD_LOGIC_VECTOR (k_WIDTH - 1 downto 0);
            o_sel    : out STD_LOGIC_VECTOR (3 downto 0)
        );
    end component;

    component clock_divider is
        generic ( constant k_DIV : natural := 2 );
        port (
            i_clk    : in std_logic;
            i_reset  : in std_logic;
            o_clk    : out std_logic
        );
    end component;

begin
    -- PORT MAPS ----------------------------------------

    -- Slow clock for FSMs (0.5s)
    u_clkdiv_slow : entity work.clock_divider
        generic map ( k_DIV => 25000000 )
        port map (
            i_clk    => clk,
            i_reset  => btnL,
            o_clk    => w_slow_clk
        );

    -- Fast clock for TDM (about every 1ms or less)
    u_clkdiv_fast : entity work.clock_divider
        generic map ( k_DIV => 50000 )  -- 1ms at 50MHz
        port map (
            i_clk    => clk,
            i_reset  => btnL,
            o_clk    => w_fast_clk
        );

    -- Elevator FSM 1
    u_elevator1 : entity work.elevator_controller_fsm
        port map (
            i_clk       => w_slow_clk,
            i_reset     => btnR,
            is_stopped  => sw(0),
            go_up_down  => sw(1),
            o_floor     => w_floor1
        );

    -- Elevator FSM 2
    u_elevator2 : entity work.elevator_controller_fsm
        port map (
            i_clk       => w_slow_clk,
            i_reset     => btnR,
            is_stopped  => sw(14),
            go_up_down  => sw(15),
            o_floor     => w_floor2
        );

    -- Seven segment decoders
    u_segdec1 : entity work.sevenseg_decoder
        port map (
            i_Hex   => w_floor1,
            o_seg_n => w_seg1
        );

    u_segdec2 : entity work.sevenseg_decoder
        port map (
            i_Hex   => w_floor2,
            o_seg_n => w_seg2
        );

    -- Time Division Multiplexer
    u_tdm : entity work.TDM4
        generic map ( k_WIDTH => 4 )
        port map (
            i_clk    => w_fast_clk,
            i_reset  => btnU,
            i_D3     => "1111",       -- Show "F" on an(3)
            i_D2     => w_floor2,     -- Elevator 2
            i_D1     => "1111",       -- Show "F" on an(1)
            i_D0     => w_floor1,     -- Elevator 1
            o_data   => w_mux_data,
            o_sel    => w_sel
        );

    -- Decode selected floor for current digit
    seg_decoder_mux : entity work.sevenseg_decoder
        port map (
            i_Hex   => w_mux_data,
            o_seg_n => w_seg_muxed
        );

    -- CONCURRENT STATEMENTS ----------------------------


    -- LED Debug
    
    led(15)           <= w_slow_clk;
    led(14 downto 8)  <= (others => '0');
    led(7 downto 4)   <= w_floor2;
    led(3 downto 0)   <= w_floor1;

    -- Drive active-low segment and anode outputs
    seg <= w_seg_muxed;
    an  <= not w_sel;  -- TDM o_sel is one-cold, invert to get active-low anodes

end top_basys3_arch;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tlc_plus is
    generic (
        BCD_WIDTH : natural := 4;
        CLK_WIDTH : natural := 27;
        CLK_FREQ  : natural := 50--000000
    );
    port (
        clk_i   : in  std_logic;
        rstn_i  : in  std_logic;

        -- request button
        reqn_i  : in  std_logic;

        -- traffic lights and the wait light
        leds    : out std_logic_vector (5 downto 0);

        -- countdown digits
        seg0_o  : out std_logic_vector (6 downto 0);
        seg1_o  : out std_logic_vector (6 downto 0)
    );
end tlc_plus;

architecture Behavior of tlc_plus is
    -- Internal signals
    signal both_rollover : std_logic;
    signal one_second    : std_logic;
    signal ten_seconds   : std_logic;
    signal timer_load    : std_logic;
    signal wait_on       : std_logic;
    signal light_code    : unsigned         (1 downto 0);
    signal start_time    : unsigned         (7 downto 0);
    signal bcd0          : unsigned         (BCD_WIDTH-1 downto 0);
    signal bcd1          : unsigned         (BCD_WIDTH-1 downto 0);
    signal ctd_enable    : std_logic;
    signal rollovers     : std_logic_vector (1 downto 0);

begin

    both_rollover <= '1' when rollovers = "11" else '0';
    ten_seconds   <= one_second and rollovers(0);
    -- only display countdown when peds are passing
    ctd_enable    <= '1' when light_code = to_unsigned(3, 2) else '0';

    fsm_0: entity work.fsm
        port map(
            clk_i         => clk_i,
            rstn_i        => rstn_i,
            reqn_i        => reqn_i,
            times_up_i    => both_rollover,
            light_code_o  => light_code,
            wait_on_o     => wait_on,
            timer_load_o  => timer_load,
            timer_value_o => start_time
        );

    counter_slow: entity work.counter
        generic map(
            WIDTH    => CLK_WIDTH,
            START_AT => CLK_FREQ
        )
        port map(
            clk_i        => clk_i,
            rstn_i       => rstn_i,
            load_i       => timer_load,
            enable_i     => '1',
            start_time_i => to_unsigned(CLK_FREQ, CLK_WIDTH),
            count_o      => open,  -- Unused
            rollover_o   => one_second
        );

    -- Ones digit
    counter_0: entity work.counter
        generic map(
            WIDTH    => BCD_WIDTH,
            START_AT => 10
        )
        port map(
            clk_i        => clk_i,
            rstn_i       => rstn_i,
            load_i       => timer_load,
            enable_i     => one_second,
            start_time_i => start_time(3 downto 0),
            count_o      => bcd0,
            rollover_o   => rollovers(0)
        );

    -- Tens digit
    counter_1: entity work.counter
        generic map(
            WIDTH    => BCD_WIDTH,
            START_AT => 10
        )
        port map(
            clk_i        => clk_i,
            rstn_i       => rstn_i,
            load_i       => timer_load,
            enable_i     => ten_seconds,
            start_time_i => start_time(7 downto 4),
            count_o      => bcd1,
            rollover_o   => rollovers(1)
        );

    bcd7seg_0: entity work.bcd7seg
        port map(
            bcd => std_logic_vector(bcd0),
            ena => ctd_enable,
            hex => seg0_o
        );

    bcd7seg_1: entity work.bcd7seg
        port map(
            bcd => std_logic_vector(bcd1),
            ena => ctd_enable,
            hex => seg1_o
        );

    light_0: entity work.light
        port map(
            wait_on    => wait_on,
            light_code => light_code,
            leds       => leds
        );

end Behavior;

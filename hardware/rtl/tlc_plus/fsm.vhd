library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fsm is
    generic (
        VEH_PASS_SECONDS : unsigned(7 downto 0) := "00001001";   -- 9s
        VEH_SLOW_SECONDS : unsigned(7 downto 0) := "00000011";   -- 3s
        VEH_STOP_SECONDS : unsigned(7 downto 0) := "00000010";   -- 2s
        PED_PASS_SECONDS : unsigned(7 downto 0) := "00010000"    -- 10s
    );
    port (
        clk_i         : in  std_logic;
        rstn_i        : in  std_logic;

        reqn_i        : in  std_logic;
        times_up_i    : in  std_logic;

        light_code_o  : out unsigned (1 downto 0);
        wait_on_o     : out std_logic;

        timer_load_o  : out std_logic;
        timer_value_o : out unsigned (7 downto 0)
    );
end fsm;

architecture Behavior of fsm is
    -- State names
    type state_t is (
        VEH_PASS, 
        VEH_SLOW, 
        VEH_STOP, 
        PED_PASS
    );
    signal state, next_state : state_t;

    -- Internal signals
    signal req_reg : std_logic;
    -- reset overrides
    signal timer_load_normal, timer_load_rst   : std_logic;
    signal timer_value_normal, timer_value_rst : unsigned (7 downto 0);

begin
    
    timer_load_o  <= timer_load_normal or timer_load_rst;
    timer_value_o <= timer_value_rst 
            when (timer_value_rst /= to_unsigned(0, 8))
            else timer_value_normal;

    comb_proc: process(state, req_reg, times_up_i)
    begin
        -- Default assignments
        next_state         <= state;
        timer_load_normal  <= '0';
        timer_value_normal <= (others => '0');
        wait_on_o          <= req_reg;

        case state is
            when VEH_PASS =>
                light_code_o <= to_unsigned(0, 2);
                if ((req_reg = '1') and (times_up_i = '1')) then
                    next_state         <= VEH_SLOW;
                    timer_load_normal  <= '1';
                    timer_value_normal <= VEH_SLOW_SECONDS;
                end if;
            when VEH_SLOW =>
                light_code_o <= to_unsigned(1, 2);
                if (times_up_i = '1') then
                    next_state         <= VEH_STOP;
                    timer_load_normal  <= '1';
                    timer_value_normal <= VEH_STOP_SECONDS;
                end if;
            when VEH_STOP =>
                light_code_o <= to_unsigned(2, 2);
                if (times_up_i = '1') then
                    next_state         <= PED_PASS;
                    timer_load_normal  <= '1';
                    timer_value_normal <= PED_PASS_SECONDS;
                end if;
            when PED_PASS =>
                light_code_o <= to_unsigned(3, 2);
                if (times_up_i = '1') then
                    next_state         <= VEH_PASS;
                    timer_load_normal  <= '1';
                    timer_value_normal <= VEH_PASS_SECONDS;
                end if;
            when others =>
                null;
        end case;
    end process comb_proc;

    seq_proc: process(clk_i, rstn_i)
    begin
        if (rstn_i = '0') then
            state           <= VEH_PASS;
            timer_value_rst <= (others => '0');
            timer_load_rst  <= '1';
            req_reg         <= '0';
        elsif rising_edge(clk_i) then
            state           <= next_state;
            timer_load_rst  <= '0';
            timer_value_rst <= (others => '0');

            case state is
                when VEH_PASS =>
                    -- Cache pedestrian request
                    req_reg <= req_reg or (not reqn_i);
                when PED_PASS =>
                    req_reg <= '0';
                when others =>
                    null;
            end case;
        end if;
    end process seq_proc;

end Behavior;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity light is
    Port (
        wait_on    : in  std_logic;
        light_code : in  unsigned         (1 downto 0);
        leds       : out std_logic_vector (5 downto 0)
                 -- {wait_light, veh[r,y,g], ped[r,g]}
    );
end light;

architecture Behavior of light is
    -- Static constants for case statement
    constant CODE0 : unsigned(1 downto 0) := "00";
    constant CODE1 : unsigned(1 downto 0) := "01";
    constant CODE2 : unsigned(1 downto 0) := "10";
    constant CODE3 : unsigned(1 downto 0) := "11";

begin
    
    process(wait_on, light_code)
    begin
        leds(5) <= wait_on;
        case light_code is
            when CODE0 =>
                leds(4 downto 0) <= "00110";
            when CODE1 =>
                leds(4 downto 0) <= "01010";
            when CODE2 =>
                leds(4 downto 0) <= "10010";
            when CODE3 =>
                leds(4 downto 0) <= "10001";
            when others =>
                leds(5 downto 0) <= "111111";  -- Error code
        end case;
    end process;
end Behavior;

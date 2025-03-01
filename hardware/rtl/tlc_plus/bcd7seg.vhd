library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity bcd7seg is
    Port (
        bcd : in  STD_LOGIC_VECTOR (3 downto 0);
        ena : in  STD_LOGIC;
        hex : out STD_LOGIC_VECTOR (6 downto 0)
    );
end bcd7seg;

architecture Behavior of bcd7seg is
begin
    process(bcd, ena)
    begin
        case bcd is
            when "0000" => hex <= "1000000"; -- 0
            when "0001" => hex <= "1111001"; -- 1
            when "0010" => hex <= "0100100"; -- 2
            when "0011" => hex <= "0110000"; -- 3
            when "0100" => hex <= "0011001"; -- 4
            when "0101" => hex <= "0010010"; -- 5
            when "0110" => hex <= "0000010"; -- 6
            when "0111" => hex <= "1111000"; -- 7
            when "1000" => hex <= "0000000"; -- 8
            when "1001" => hex <= "0010000"; -- 9
            when others => hex <= "0000110"; -- 'E' for 'error' (invalid bcd)
        end case;

        -- All off if enable is low
        if (ena = '0') then
            hex <= "1111111";
        end if;
    end process;
end Behavior;

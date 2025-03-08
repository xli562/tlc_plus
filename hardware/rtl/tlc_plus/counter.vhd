-- /* BCD counter */

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity counter is
    generic (
        WIDTH    : integer := 4;
        START_AT : integer := 10
    );
    port (
        clk_i        : in  std_logic;
        rstn_i       : in  std_logic;

        load_i       : in  std_logic;
        enable_i     : in  std_logic;
        
        start_time_i : in  unsigned (WIDTH-1 downto 0);
        count_o      : out unsigned (WIDTH-1 downto 0);
        rollover_o   : out std_logic
    );
end counter;

architecture Behavior of counter is
    signal count_s : unsigned(WIDTH-1 downto 0);

begin
    
    process(clk_i, rstn_i)
    begin
        if rstn_i = '0' then
            count_s <= (others => '0');
        elsif rising_edge(clk_i) then
            if load_i = '1' then
                count_s <= start_time_i;
            elsif enable_i = '1' then
                if count_s = 0 then
                    count_s <= to_unsigned(START_AT - 1, WIDTH);
                else
                    count_s <= count_s - 1;
                end if;
            end if;
        end if;
    end process;

    count_o    <= count_s;
    rollover_o <= '1' when count_s = 0 else '0';

end Behavior;

-- Copyright 2018 Jonas Fuhrmann. All rights reserved.
--
-- This project is dual licensed under GNU General Public License version 3
-- and a commercial license available on request.
---------------------------------------------------------------------------
-- For non commercial use only:
-- This file is part of tinyTPU.
-- 
-- tinyTPU is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- 
-- tinyTPU is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with tinyTPU. If not, see <http://www.gnu.org/licenses/>.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;

entity TB_MACC is
end entity TB_MACC;

architecture BEH of TB_MACC is
    component DUT is
        generic(
        -- The width of the last sum input
        LAST_SUM_WIDTH      : natural   := 0;
        -- The width of the output register
        PARTIAL_SUM_WIDTH   : natural   := 16
        );
        port(
            CLK, RESET      : in std_logic;
            ENABLE          : in std_logic;
            -- Weights - current and preload
            WEIGHT_INPUT    : in BYTE_TYPE;
            PRELOAD_WEIGHT  : in std_logic;
            LOAD_WEIGHT     : in std_logic;
            -- Input
            INPUT           : in BYTE_TYPE;
            LAST_SUM        : in std_logic_vector(LAST_SUM_WIDTH-1 downto 0);
            -- Output
            PARTIAL_SUM     : out std_logic_vector(PARTIAL_SUM_WIDTH-1 downto 0)
        );
    end component DUT;
    for all : DUT use entity WORK.MACC(BEH);
    
    constant LAST_SUM_WIDTH : natural := 8;
    constant SUM_WIDTH      : natural := 16;
    signal CLK, RESET       : std_logic;
    signal ENABLE           : std_logic;
    signal WEIGHT_INPUT     : BYTE_TYPE;
    signal PRELOAD_WEIGHT   : std_logic;
    signal LOAD_WEIGHT      : std_logic;
    signal INPUT            : BYTE_TYPE;
    signal LAST_SUM         : std_logic_vector(LAST_SUM_WIDTH-1 downto 0);
    
    signal PARTIAL_SUM      : std_logic_vector(SUM_WIDTH-1 downto 0);
    
    signal RESULT_NOW       : std_logic;
    
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean;

begin

    DUT_i0 : DUT
    generic map(
        LAST_SUM_WIDTH,
        SUM_WIDTH
    )
    port map(
        CLK => CLK,
        RESET => RESET,
        ENABLE => ENABLE,
        WEIGHT_INPUT => WEIGHT_INPUT,
        PRELOAD_WEIGHT => PRELOAD_WEIGHT,
        LOAD_WEIGHT => LOAD_WEIGHT,
        INPUT => INPUT,
        LAST_SUM => LAST_SUM,
        PARTIAL_SUM => PARTIAL_SUM
    );
    
    STIMULUS:
    process is
    begin
        stop_the_clock <= false;
        RESULT_NOW <= '0';
        ENABLE <= '0';
        PRELOAD_WEIGHT <= '0';
        LOAD_WEIGHT <= '0';
        RESET <= '0';
        WEIGHT_INPUT <= (others => '0');
        INPUT <= (others => '0');
        LAST_SUM <= (others => '0');
        wait until '1'=CLK and CLK'event;
        RESET <= '1';
        wait until '1'=CLK and CLK'event;
        RESET <= '0';
        
        -- TEST0: Trimmed result --
        for INPUT_VAL in 0 to 255 loop
            
            for LAST_VAL in 0 to 255 loop
                
                for WEIGHT in 0 to 255 loop   -- 8 Bit is enough for simulation purposes
                    
                    ENABLE <= '0';
                    WEIGHT_INPUT <= std_logic_vector(to_unsigned(WEIGHT, BYTE_WIDTH));
                    PRELOAD_WEIGHT <= '1';
                    wait until '1'=CLK and CLK'event;   -- Loading the next weight
                    LOAD_WEIGHT <= '1';
                    PRELOAD_WEIGHT <= '0';
                    wait until '1'=CLK and CLK'event;
                    ENABLE <= '1';
                    INPUT <= std_logic_vector(to_unsigned(INPUT_VAL, BYTE_WIDTH));
                    LOAD_WEIGHT <= '0';
                    PRELOAD_WEIGHT <= not PRELOAD_WEIGHT;
                    wait until '1'=CLK and CLK'event;   -- Switch to new weight value and load input
                    LAST_SUM <= std_logic_vector(to_unsigned(LAST_VAL, LAST_SUM_WIDTH));
                    wait until '1'=CLK and CLK'event;   -- Wait for result
                    wait until '1'=CLK and CLK'event;
                    RESULT_NOW <= '1';
                    wait for 1 ns;
                    -- Check the result
                    if PARTIAL_SUM /= std_logic_vector(to_unsigned(WEIGHT, BYTE_WIDTH)
                                                     * to_unsigned(INPUT_VAL, BYTE_WIDTH)
                                                     + to_unsigned(LAST_VAL, LAST_SUM_WIDTH)) then
                        report "Result is not correct!" severity ERROR;
                        stop_the_clock <= true;
                        wait;
                    end if;
                    wait until '1'=CLK and CLK'event;
                    RESULT_NOW <= '0';
                end loop;
            end loop;
        end loop;
        
        -- TEST1: Full size --
        for INPUT_VAL in 0 to 255 loop
            
            for LAST_VAL in 0 to 255 loop
                
                for WEIGHT in 0 to 255 loop   -- 8 Bit is enough for simulation purposes
                
                    ENABLE <= '0';
                    WEIGHT_INPUT <= std_logic_vector(to_unsigned(WEIGHT, BYTE_WIDTH));
                    PRELOAD_WEIGHT <= '1';
                    wait until '1'=CLK and CLK'event;   -- Loading the next weight
                    LOAD_WEIGHT <= '1';
                    PRELOAD_WEIGHT <= '0';
                    wait until '1'=CLK and CLK'event;
                    ENABLE <= '1';
                    INPUT <= std_logic_vector(to_unsigned(INPUT_VAL, BYTE_WIDTH));
                    LOAD_WEIGHT <= '0';
                    PRELOAD_WEIGHT <= not PRELOAD_WEIGHT;
                    wait until '1'=CLK and CLK'event;   -- Switch to new weight value and load input
                    LAST_SUM <= std_logic_vector(to_unsigned(LAST_VAL, LAST_SUM_WIDTH));
                    wait until '1'=CLK and CLK'event;   -- Wait for result
                    wait until '1'=CLK and CLK'event;
                    RESULT_NOW <= '1';
                    wait for 1 ns;
                    -- Check the result
                    if PARTIAL_SUM /= std_logic_vector(to_unsigned(WEIGHT, BYTE_WIDTH)
                                                     * to_unsigned(INPUT_VAL, BYTE_WIDTH)
                                                     + to_unsigned(LAST_VAL, LAST_SUM_WIDTH)) then
                        report "Result is not correct!" severity ERROR;
                        stop_the_clock <= true;
                        wait;
                    end if;
                    wait until '1'=CLK and CLK'event;
                    RESULT_NOW <= '0';
                end loop;
            end loop;
        end loop;
        stop_the_clock <= true;
        report "The test was successful!" severity NOTE;
        wait;
    end process;
    
    CLOCK_GEN: 
    process
    begin
        while not stop_the_clock loop
          CLK <= '0', '1' after clock_period / 2;
          wait for clock_period;
        end loop;
        wait;
    end process CLOCK_GEN;

end architecture BEH;
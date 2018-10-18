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

entity TB_RUNTIME_COUNTER is
end entity TB_RUNTIME_COUNTER;

architecture BEH of TB_RUNTIME_COUNTER is
    signal CLK, RESET       : std_logic;
        
    signal INSTRUCTION_EN   : std_logic;
    signal SYNCHRONIZE      : std_logic;
    signal COUNTER_VAL      : WORD_TYPE;
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean;
begin
    DUT_i : entity WORK.RUNTIME_COUNTER(BEH)
    port map(
        CLK => CLK,
        RESET => RESET,
        INSTRUCTION_EN => INSTRUCTION_EN,
        SYNCHRONIZE => SYNCHRONIZE,
        COUNTER_VAL => COUNTER_VAL
    );
    
    STIMULUS:
    process is
    begin
        RESET <= '0';
        INSTRUCTION_EN <= '0';
        SYNCHRONIZE <= '0';
        wait until CLK='1' and CLK'event;
        RESET <= '1';
        wait until CLK='1' and CLK'event;
        RESET <= '0';
        wait until CLK='1' and CLK'event;
        INSTRUCTION_EN <= '1';
        wait until CLK='1' and CLK'event;
        INSTRUCTION_EN <= '0';
        for i in 0 to 31 loop
            wait until CLK='1' and CLK'event;
        end loop;
        INSTRUCTION_EN <= '1';
        wait until CLK='1' and CLK'event;
        INSTRUCTION_EN <= '0';
        for i in 0 to 31 loop
            wait until CLK='1' and CLK'event;
        end loop;
        SYNCHRONIZE <= '1';
        wait until CLK='1' and CLK'event;
        SYNCHRONIZE <= '0';
        wait;
    end process STIMULUS;
    
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
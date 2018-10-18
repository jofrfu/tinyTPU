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

entity TB_LOOK_AHEAD_BUFFER is
end entity TB_LOOK_AHEAD_BUFFER;

architecture BEH of TB_LOOK_AHEAD_BUFFER is
    component DUT is
        port(
            CLK, RESET          :  in std_logic;
            ENABLE              :  in std_logic;
            
            INSTRUCTION_BUSY    :  in std_logic;
            
            INSTRUCTION_INPUT   :  in INSTRUCTION_TYPE;
            INSTRUCTION_WRITE   :  in std_logic;
            
            INSTRUCTION_OUTPUT  : out INSTRUCTION_TYPE;
            INSTRUCTION_READ    : out std_logic
        );
    end component DUT;
    for all : DUT use entity WORK.LOOK_AHEAD_BUFFER(BEH);
    
    signal CLK                  : std_logic;
    signal RESET                : std_logic;
    signal ENABLE               : std_logic;
    
    signal INSTRUCTION_BUSY     : std_logic;
    
    signal INSTRUCTION_INPUT    : INSTRUCTION_TYPE;
    signal INSTRUCTION_WRITE    : std_logic;
    
    signal INSTRUCTION_OUTPUT   : INSTRUCTION_TYPE;
    signal INSTRUCTION_READ     : std_logic;
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean := false;
begin

    DUT_i : DUT
    port map(
        CLK => CLK,
        RESET => RESET,
        ENABLE => ENABLE,
        INSTRUCTION_BUSY => INSTRUCTION_BUSY,
        INSTRUCTION_INPUT => INSTRUCTION_INPUT,
        INSTRUCTION_WRITE => INSTRUCTION_WRITE,
        INSTRUCTION_OUTPUT => INSTRUCTION_OUTPUT,
        INSTRUCTION_READ => INSTRUCTION_READ
    );

    STIMULUS:
    process is
    begin
        RESET <= '0';
        ENABLE <= '0';
        INSTRUCTION_INPUT <= INIT_INSTRUCTION;
        INSTRUCTION_WRITE <= '0';
        INSTRUCTION_BUSY <= '0';
        wait until '1'=CLK and CLK'event;
        RESET <= '1';
        wait until '1'=CLK and CLK'event;
        RESET <= '0';
        ENABLE <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_INPUT.OP_CODE <= "00001000";
        INSTRUCTION_WRITE <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_WRITE <= '0';
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_INPUT.OP_CODE <= "00100000";
        INSTRUCTION_WRITE <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_INPUT.OP_CODE <= "10000000";
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_INPUT.OP_CODE <= "00100000";
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_BUSY <= '1';
        INSTRUCTION_WRITE <= '0';
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_BUSY <= '0';
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
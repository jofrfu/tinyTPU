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

--! @file RUNTIME_COUNTER.vhdl
--! @author Jonas Fuhrmann
--! @brief This component includes the counter for runtime measurements.
--! @details The counter starts when a new Instruction is feeded to the TPU.
--! When the TPU signals a synchronization, the counter will stop and hold it's value.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;

entity RUNTIME_COUNTER is
    port(
        CLK, RESET      :  in std_logic;
        
        INSTRUCTION_EN  :  in std_logic; --!< Signals that a new Instruction was feeded and starts the counter.
        SYNCHRONIZE     :  in std_logic; --!< Signals that the calculations are done, stops the counter and holds it's value.
        COUNTER_VAL     : out WORD_TYPE  --!< The current value of the counter. 
    );
end entity RUNTIME_COUNTER;

--! @brief The architecture of the runtime counter.
architecture BEH of RUNTIME_COUNTER is
    signal COUNTER_cs : WORD_TYPE := (others => '0');
    signal COUNTER_ns : WORD_TYPE;
    
    signal PIPELINE_cs : WORD_TYPE := (others => '0');
    signal PIPELINE_ns : WORD_TYPE;
    
    signal STATE_cs : std_logic := '0';
    signal STATE_ns : std_logic;
    
    signal RESET_COUNTER : std_logic;
    
    attribute use_dsp : string;
    attribute use_dsp of COUNTER_ns : signal is "yes";
begin
    -- Actual adder
    COUNTER_ns  <= std_logic_vector(unsigned(COUNTER_cs) + '1');
    -- Pipeline for DSP performance
    PIPELINE_ns <= COUNTER_cs;
    COUNTER_VAL <= PIPELINE_cs;

    FSM:
    process(INSTRUCTION_EN, SYNCHRONIZE, STATE_cs) is
        variable INST_EN_SYNCH : std_logic_vector(0 to 1);
    begin
        INST_EN_SYNCH := INSTRUCTION_EN & SYNCHRONIZE;
        case STATE_cs is
            when '0' =>
                case INST_EN_SYNCH is
                    when "00" =>
                        STATE_ns <= '0';
                        RESET_COUNTER <= '0';
                    when "01" =>
                        STATE_ns <= '0';
                        RESET_COUNTER <= '0';
                    when "10" =>
                        STATE_ns <= '1';
                        RESET_COUNTER <= '1';
                    when "11" =>
                        STATE_ns <= '0';
                        RESET_COUNTER <= '0';
                    when others => -- Shouldn't happen
                        STATE_ns <= '0';
                        RESET_COUNTER <= '0';
                end case;
            when '1' =>
                case INST_EN_SYNCH is
                    when "00" =>
                        STATE_ns <= '1';
                        RESET_COUNTER <= '0';
                    when "01" =>
                        STATE_ns <= '0';
                        RESET_COUNTER <= '0';
                    when "10" =>
                        STATE_ns <= '1';
                        RESET_COUNTER <= '0';
                    when "11" =>
                        STATE_ns <= '0';
                        RESET_COUNTER <= '0';
                    when others => -- Shouldn't happen
                        STATE_ns <= '0';
                        RESET_COUNTER <= '0';
                end case;
            when others => -- Shouldn't happen
                STATE_ns <= '0';
                RESET_COUNTER <= '0';
        end case;
    end process FSM;
    
    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                STATE_cs <= '0';
                PIPELINE_cs <= (others => '0');
            else
                STATE_cs <= STATE_ns;
                PIPELINE_cs <= PIPELINE_ns;
            end if;
            
            if RESET_COUNTER = '1' then
                COUNTER_cs <= (others => '0');
            else
                if STATE_cs = '1' then
                    COUNTER_cs <= COUNTER_ns;
                end if;
            end if;
        end if;
    end process SEQ_LOG;
end architecture BEH;
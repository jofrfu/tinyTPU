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

--! @file DSP_COUNTER.vhdl
--! @author Jonas Fuhrmann
--! @brief This component is a counter, which uses a DSP block for fast, big adders.
--! @details The counter starts at 0 and can be resetted. If the counter reaches a given end value, an event signal is asserted.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    
entity DSP_COUNTER is
    generic(
        COUNTER_WIDTH   : natural := 32 --!< The width of the counter.
    );
    port(
        CLK, RESET  : in  std_logic;
        ENABLE      : in  std_logic;
        
        END_VAL     : in  std_logic_vector(COUNTER_WIDTH-1 downto 0); --!< The end value of he counter, at which this component will produce the event signal.
        LOAD        : in  std_logic; --!< Load signal for the end value.
        
        COUNT_VAL   : out std_logic_vector(COUNTER_WIDTH-1 downto 0); --!< The current value of the counter.
        
        COUNT_EVENT : out std_logic --!< The event, which will be asserted when the end value was reached.
    );
end entity DSP_COUNTER;

--! @brief The architecture of the DSP counter component.
architecture BEH of DSP_COUNTER is
    signal COUNTER : std_logic_vector(COUNTER_WIDTH-1 downto 0) := (others => '0');    
    signal END_REG : std_logic_vector(COUNTER_WIDTH-1 downto 0) := (others => '0');
    
    signal EVENT_cs : std_logic := '0';
    signal EVENT_ns : std_logic;
    
    signal EVENT_PIPE_cs : std_logic := '0';
    signal EVENT_PIPE_ns : std_logic;
    
    attribute use_dsp : string;
    attribute use_dsp of COUNTER : signal is "yes";
begin
    COUNT_VAL <= COUNTER;
    COUNT_EVENT <= EVENT_PIPE_cs;
    EVENT_PIPE_ns <= EVENT_cs;

    CHECK:
    process(COUNTER, END_REG) is
    begin
        if COUNTER = END_REG then
            EVENT_ns <= '1';
        else
            EVENT_ns <= '0';
        end if;
    end process CHECK;
    
    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                COUNTER <= (others => '0');
                EVENT_cs <= '0';
                EVENT_PIPE_cs <= '0';
            else
                if ENABLE = '1' then
                    COUNTER <= std_logic_vector(unsigned(COUNTER) + '1');
                    EVENT_cs <= EVENT_ns;
                    EVENT_PIPE_cs <= EVENT_PIPE_ns;
                end if;
            end if;
            
            if LOAD = '1' then
                END_REG <= END_VAL;
            end if;
        end if;
    end process SEQ_LOG;
end architecture BEH;

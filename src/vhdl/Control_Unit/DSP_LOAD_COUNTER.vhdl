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

--! @file DSP_LOAD_COUNTER.vhdl
--! @author Jonas Fuhrmann
--! @brief This component is a counter, which uses a DSP block for fast, big adders.
--! @details The counter can be loaded with any given value and adds the start value every clock cycle.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    
entity DSP_LOAD_COUNTER is
    generic(
        COUNTER_WIDTH   : natural := 32;
        MATRIX_WIDTH    : natural := 14
    );
    port(
        CLK, RESET  : in  std_logic;
        ENABLE      : in  std_logic;
        
        START_VAL   : in  std_logic_vector(COUNTER_WIDTH-1 downto 0); --!< The given start value of the counter.
        LOAD        : in  std_logic; --!< Load flag for the start value.
        
        COUNT_VAL   : out std_logic_vector(COUNTER_WIDTH-1 downto 0) --!< The current value of the counter.
    );
end entity DSP_LOAD_COUNTER;

--! @brief The architecture of the DSP load counter component.
architecture BEH of DSP_LOAD_COUNTER is
    signal COUNTER_INPUT_cs : std_logic_vector(COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal COUNTER_INPUT_ns : std_logic_vector(COUNTER_WIDTH-1 downto 0);
    
    signal INPUT_PIPE_cs : std_logic_vector(COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal INPUT_PIPE_ns : std_logic_vector(COUNTER_WIDTH-1 downto 0);
    
    signal COUNTER_cs : std_logic_vector(COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal COUNTER_ns : std_logic_vector(COUNTER_WIDTH-1 downto 0);
    
    signal LOAD_cs : std_logic := '0';
    signal LOAD_ns : std_logic;
    
    attribute use_dsp : string;
    attribute use_dsp of COUNTER_ns : signal is "yes";
begin
    LOAD_ns <= LOAD;

    INPUT_PIPE_ns <= START_VAL when LOAD = '1' else (0 => '1', others => '0');
    COUNTER_INPUT_ns <= INPUT_PIPE_cs;
    
    COUNTER_ns <= std_logic_vector(unsigned(COUNTER_cs) + unsigned(COUNTER_INPUT_cs));
    COUNT_VAL <= COUNTER_cs;
    
    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                COUNTER_INPUT_cs <= (others => '0');
                INPUT_PIPE_cs <= (others => '0');
                LOAD_cs <= '0';
            else
                if ENABLE = '1' then
                    COUNTER_INPUT_cs <= COUNTER_INPUT_ns;
                    INPUT_PIPE_cs <= INPUT_PIPE_ns;
                    LOAD_cs <= LOAD_ns;
                end if;
            end if;
            
            if LOAD_cs = '1' then
                COUNTER_cs <= (others => '0');
            else
                if ENABLE = '1' then
                    COUNTER_cs <= COUNTER_ns;
                end if;
            end if;
        end if;
    end process SEQ_LOG;
end architecture BEH;

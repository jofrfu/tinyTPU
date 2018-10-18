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

--! @file SYSTOLIC_DATA_SETUP.vhdl
--! @author Jonas Fuhrmann
--! @brief This component takes a byte array and diagonalizes it for the matrix multiply unit.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    
entity SYSTOLIC_DATA_SETUP is
    generic(
        MATRIX_WIDTH  : natural := 14
    );
    port(
        CLK, RESET      : in  std_logic;
        ENABLE          : in  std_logic;
        DATA_INPUT      : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< The byte array input to be diagonalized.
        SYSTOLIC_OUTPUT : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) --!< The diagonalized output.
    );
end entity SYSTOLIC_DATA_SETUP;

--! @brief Architecture of the systolic data setup component.
architecture BEH of SYSTOLIC_DATA_SETUP is
    signal BUFFER_REG_cs : BYTE_ARRAY_2D_TYPE(1 to MATRIX_WIDTH-1, 1 to MATRIX_WIDTH-1) := (others => (others => (others => '0')));
    signal BUFFER_REG_ns : BYTE_ARRAY_2D_TYPE(1 to MATRIX_WIDTH-1, 1 to MATRIX_WIDTH-1);
begin
    
    SHIFT_REG:
    process(DATA_INPUT, BUFFER_REG_cs) is
        variable DATA_INPUT_v       : BYTE_ARRAY_TYPE(1 to MATRIX_WIDTH-1);
        variable BUFFER_REG_cs_v    : BYTE_ARRAY_2D_TYPE(1 to MATRIX_WIDTH-1, 1 to MATRIX_WIDTH-1);
        variable BUFFER_REG_ns_v    : BYTE_ARRAY_2D_TYPE(1 to MATRIX_WIDTH-1, 1 to MATRIX_WIDTH-1);
    begin
        DATA_INPUT_v := DATA_INPUT(1 to MATRIX_WIDTH-1);
        BUFFER_REG_cs_v := BUFFER_REG_cs;
        
        for i in 1 to MATRIX_WIDTH-1 loop
            for j in 1 to MATRIX_WIDTH-1 loop
                if i = 1 then
                    BUFFER_REG_ns_v(i, j) := DATA_INPUT_v(j);
                else
                    BUFFER_REG_ns_v(i, j) := BUFFER_REG_cs_v(i-1, j);
                end if;
            end loop;
        end loop;
        
        BUFFER_REG_ns <= BUFFER_REG_ns_v;
    end process SHIFT_REG;
    
    SYSTOLIC_OUTPUT(0) <= DATA_INPUT(0);
    
    SYSTOLIC_PROCESS:
    process(BUFFER_REG_cs) is
        variable BUFFER_REG_cs_v    : BYTE_ARRAY_2D_TYPE(1 to MATRIX_WIDTH-1, 1 to MATRIX_WIDTH-1);
        variable SYSTOLIC_OUTPUT_v  : BYTE_ARRAY_TYPE(1 to MATRIX_WIDTH-1);
    begin
        BUFFER_REG_cs_v := BUFFER_REG_cs;
        
        for i in 1 to MATRIX_WIDTH-1 loop 
            SYSTOLIC_OUTPUT_v(i) := BUFFER_REG_cs_v(i, i);
        end loop;
        
        SYSTOLIC_OUTPUT(1 to MATRIX_WIDTH-1) <= SYSTOLIC_OUTPUT_v;
    end process SYSTOLIC_PROCESS;
    
    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                BUFFER_REG_cs <= (others => (others => (others => '0')));
            else
                if ENABLE = '1' then
                    BUFFER_REG_cs <= BUFFER_REG_ns;
                end if;
            end if;
        end if;
    end process SEQ_LOG;
end architecture BEH;
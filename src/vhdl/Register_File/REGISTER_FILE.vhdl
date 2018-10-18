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

--! @file REGISTER_FILE.vhdl
--! @author Jonas Fuhrmann
--! @brief This component includes accumulator registers. Registers are accumulated or overwritten.
--! @details The register file constists of block RAM, which is redundant for a seperate accumulation port.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    
entity REGISTER_FILE is
    generic(
        MATRIX_WIDTH    : natural := 14;
        REGISTER_DEPTH  : natural := 512
    );
    port(
        CLK, RESET          : in  std_logic;
        ENABLE              : in  std_logic;
        
        WRITE_ADDRESS       : in  ACCUMULATOR_ADDRESS_TYPE;
        WRITE_PORT          : in  WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
        WRITE_ENABLE        : in  std_logic;
        
        ACCUMULATE          : in  std_logic;
        
        READ_ADDRESS        : in  ACCUMULATOR_ADDRESS_TYPE;
        READ_PORT           : out WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1)
    );
end entity REGISTER_FILE;

--! @brief The architecture of the register file.
architecture BEH of REGISTER_FILE is
    type ACCUMULATOR_TYPE is array(0 to REGISTER_DEPTH-1) of std_logic_vector(4*BYTE_WIDTH*MATRIX_WIDTH-1 downto 0);
    shared variable ACCUMULATORS        : ACCUMULATOR_TYPE;
    shared variable ACCUMULATORS_COPY   : ACCUMULATOR_TYPE;
    
    attribute ram_style                 : string;
    attribute ram_style of ACCUMULATORS : variable is "block";
    attribute ram_style of ACCUMULATORS_COPY : variable is "block";
    
    -- Memory port signals
    signal ACC_WRITE_EN         : std_logic;
    signal ACC_WRITE_ADDRESS    : ACCUMULATOR_ADDRESS_TYPE;
    signal ACC_READ_ADDRESS     : ACCUMULATOR_ADDRESS_TYPE;
    signal ACC_ACCU_ADDRESS     : ACCUMULATOR_ADDRESS_TYPE;
    signal ACC_WRITE_PORT       : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal ACC_READ_PORT        : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal ACC_ACCUMULATE_PORT  : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    -- DSP signals
    signal DSP_ADD_PORT0_cs     : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal DSP_ADD_PORT0_ns     : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal DSP_ADD_PORT1_cs     : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal DSP_ADD_PORT1_ns     : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal DSP_RESULT_PORT_cs   : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal DSP_RESULT_PORT_ns   : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal DSP_PIPE0_cs         : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal DSP_PIPE0_ns         : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal DSP_PIPE1_cs         : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal DSP_PIPE1_ns         : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    -- Pipeline registers
    signal ACCUMULATE_PORT_PIPE0_cs : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal ACCUMULATE_PORT_PIPE0_ns : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal ACCUMULATE_PORT_PIPE1_cs : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal ACCUMULATE_PORT_PIPE1_ns : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    signal ACCUMULATE_PIPE_cs   : std_logic_vector(0 to 2) := (others => '0');
    signal ACCUMULATE_PIPE_ns   : std_logic_vector(0 to 2);
    
    signal WRITE_PORT_PIPE0_cs  : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal WRITE_PORT_PIPE0_ns  : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal WRITE_PORT_PIPE1_cs  : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal WRITE_PORT_PIPE1_ns  : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal WRITE_PORT_PIPE2_cs  : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal WRITE_PORT_PIPE2_ns  : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    signal WRITE_ENABLE_PIPE_cs : std_logic_vector(0 to 5) := (others => '0');
    signal WRITE_ENABLE_PIPE_ns : std_logic_vector(0 to 5);
    
    signal WRITE_ADDRESS_PIPE0_cs : ACCUMULATOR_ADDRESS_TYPE := (others => '0');
    signal WRITE_ADDRESS_PIPE0_ns : ACCUMULATOR_ADDRESS_TYPE;
    signal WRITE_ADDRESS_PIPE1_cs : ACCUMULATOR_ADDRESS_TYPE := (others => '0');
    signal WRITE_ADDRESS_PIPE1_ns : ACCUMULATOR_ADDRESS_TYPE;
    signal WRITE_ADDRESS_PIPE2_cs : ACCUMULATOR_ADDRESS_TYPE := (others => '0');
    signal WRITE_ADDRESS_PIPE2_ns : ACCUMULATOR_ADDRESS_TYPE;
    signal WRITE_ADDRESS_PIPE3_cs : ACCUMULATOR_ADDRESS_TYPE := (others => '0');
    signal WRITE_ADDRESS_PIPE3_ns : ACCUMULATOR_ADDRESS_TYPE;
    signal WRITE_ADDRESS_PIPE4_cs : ACCUMULATOR_ADDRESS_TYPE := (others => '0');
    signal WRITE_ADDRESS_PIPE4_ns : ACCUMULATOR_ADDRESS_TYPE;
    signal WRITE_ADDRESS_PIPE5_cs : ACCUMULATOR_ADDRESS_TYPE := (others => '0');
    signal WRITE_ADDRESS_PIPE5_ns : ACCUMULATOR_ADDRESS_TYPE;
    
    signal READ_ADDRESS_PIPE0_cs : ACCUMULATOR_ADDRESS_TYPE := (others => '0');
    signal READ_ADDRESS_PIPE0_ns : ACCUMULATOR_ADDRESS_TYPE;
    signal READ_ADDRESS_PIPE1_cs : ACCUMULATOR_ADDRESS_TYPE := (others => '0');
    signal READ_ADDRESS_PIPE1_ns : ACCUMULATOR_ADDRESS_TYPE;
    signal READ_ADDRESS_PIPE2_cs : ACCUMULATOR_ADDRESS_TYPE := (others => '0');
    signal READ_ADDRESS_PIPE2_ns : ACCUMULATOR_ADDRESS_TYPE;
    signal READ_ADDRESS_PIPE3_cs : ACCUMULATOR_ADDRESS_TYPE := (others => '0');
    signal READ_ADDRESS_PIPE3_ns : ACCUMULATOR_ADDRESS_TYPE;
    signal READ_ADDRESS_PIPE4_cs : ACCUMULATOR_ADDRESS_TYPE := (others => '0');
    signal READ_ADDRESS_PIPE4_ns : ACCUMULATOR_ADDRESS_TYPE;
    signal READ_ADDRESS_PIPE5_cs : ACCUMULATOR_ADDRESS_TYPE := (others => '0');
    signal READ_ADDRESS_PIPE5_ns : ACCUMULATOR_ADDRESS_TYPE;
    
    attribute use_dsp : string;
    attribute use_dsp of DSP_RESULT_PORT_ns : signal is "yes";
begin
    WRITE_PORT_PIPE0_ns <= WRITE_PORT;
    WRITE_PORT_PIPE1_ns <= WRITE_PORT_PIPE0_cs;
    WRITE_PORT_PIPE2_ns <= WRITE_PORT_PIPE1_cs;

    DSP_ADD_PORT0_ns <= WRITE_PORT_PIPE2_cs;
    
    ACC_WRITE_PORT <= DSP_RESULT_PORT_cs;
    
    ACCUMULATE_PORT_PIPE0_ns <= ACC_ACCUMULATE_PORT;
    ACCUMULATE_PORT_PIPE1_ns <= ACCUMULATE_PORT_PIPE0_cs;
    
    ACCUMULATE_PIPE_ns(1 to 2) <= ACCUMULATE_PIPE_cs(0 to 1);
    ACCUMULATE_PIPE_ns(0) <= ACCUMULATE;

    ACC_ACCU_ADDRESS <= WRITE_ADDRESS;
    WRITE_ADDRESS_PIPE0_ns <= WRITE_ADDRESS;
    WRITE_ADDRESS_PIPE1_ns <= WRITE_ADDRESS_PIPE0_cs;
    WRITE_ADDRESS_PIPE2_ns <= WRITE_ADDRESS_PIPE1_cs;
    WRITE_ADDRESS_PIPE3_ns <= WRITE_ADDRESS_PIPE2_cs;
    WRITE_ADDRESS_PIPE4_ns <= WRITE_ADDRESS_PIPE3_cs;
    WRITE_ADDRESS_PIPE5_ns <= WRITE_ADDRESS_PIPE4_cs;
    ACC_WRITE_ADDRESS <= WRITE_ADDRESS_PIPE5_cs;
    
    WRITE_ENABLE_PIPE_ns(1 to 5) <= WRITE_ENABLE_PIPE_cs(0 to 4);
    WRITE_ENABLE_PIPE_ns(0) <= WRITE_ENABLE;
    ACC_WRITE_EN <= WRITE_ENABLE_PIPE_cs(5);
    
    READ_ADDRESS_PIPE0_ns <= READ_ADDRESS;
    READ_ADDRESS_PIPE1_ns <= READ_ADDRESS_PIPE0_cs;
    READ_ADDRESS_PIPE2_ns <= READ_ADDRESS_PIPE1_cs;
    READ_ADDRESS_PIPE3_ns <= READ_ADDRESS_PIPE2_cs;
    READ_ADDRESS_PIPE4_ns <= READ_ADDRESS_PIPE3_cs;
    READ_ADDRESS_PIPE5_ns <= READ_ADDRESS_PIPE4_cs;
    ACC_READ_ADDRESS <= READ_ADDRESS_PIPE5_cs;
    
    READ_PORT <= ACC_READ_PORT;
    
    DSP_PIPE0_ns <= DSP_ADD_PORT0_cs;
    DSP_PIPE1_ns <= DSP_ADD_PORT1_cs;
    
    DSP_ADD:
    process(DSP_PIPE0_cs, DSP_PIPE1_cs) is
    begin
        for i in 0 to MATRIX_WIDTH-1 loop
            DSP_RESULT_PORT_ns(i) <= std_logic_vector(unsigned(DSP_PIPE0_cs(i)) + unsigned(DSP_PIPE1_cs(i)));
        end loop;
    end process DSP_ADD;

    ACC_MUX:
    process(ACCUMULATE_PORT_PIPE1_cs, ACCUMULATE_PIPE_cs(2)) is
    begin
        if ACCUMULATE_PIPE_cs(2) = '1' then
            DSP_ADD_PORT1_ns <= ACCUMULATE_PORT_PIPE1_cs;
        else
            DSP_ADD_PORT1_ns <= (others => (others => '0'));
        end if;
    end process ACC_MUX;
    
    ACC_PORT0:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if ENABLE = '1' then
                --synthesis translate_off
                if to_integer(unsigned(ACC_WRITE_ADDRESS)) < REGISTER_DEPTH then
                --synthesis translate_on
                    if ACC_WRITE_EN = '1' then
                        ACCUMULATORS(to_integer(unsigned(ACC_WRITE_ADDRESS))) := WORD_ARRAY_TO_BITS(ACC_WRITE_PORT);
                        ACCUMULATORS_COPY(to_integer(unsigned(ACC_WRITE_ADDRESS))) := WORD_ARRAY_TO_BITS(ACC_WRITE_PORT);
                    end if;
                --synthesis translate_off
                end if;
                --synthesis translate_on
            end if;
        end if;
    end process ACC_PORT0;
    
    ACC_PORT1:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if ENABLE = '1' then
                --synthesis translate_off
                if to_integer(unsigned(ACC_READ_ADDRESS)) < REGISTER_DEPTH then
                --synthesis translate_on
                    ACC_READ_PORT <= BITS_TO_WORD_ARRAY(ACCUMULATORS(to_integer(unsigned(ACC_READ_ADDRESS))));
                    ACC_ACCUMULATE_PORT <= BITS_TO_WORD_ARRAY(ACCUMULATORS_COPY(to_integer(unsigned(ACC_ACCU_ADDRESS))));
                --synthesis translate_off
                end if;
                --synthesis translate_on
            end if;
        end if;
    end process ACC_PORT1;
    
    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                DSP_ADD_PORT0_cs    <= (others => (others => '0'));
                DSP_ADD_PORT1_cs    <= (others => (others => '0'));
                DSP_RESULT_PORT_cs  <= (others => (others => '0'));
                DSP_PIPE0_cs        <= (others => (others => '0'));
                DSP_PIPE1_cs        <= (others => (others => '0'));
                
                ACCUMULATE_PORT_PIPE0_cs <= (others => (others => '0'));
                ACCUMULATE_PORT_PIPE1_cs <= (others => (others => '0'));
                
                ACCUMULATE_PIPE_cs <= (others => '0');
                
                WRITE_PORT_PIPE0_cs <= (others => (others => '0'));
                WRITE_PORT_PIPE1_cs <= (others => (others => '0'));
                WRITE_PORT_PIPE2_cs <= (others => (others => '0'));
                
                WRITE_ENABLE_PIPE_cs <= (others => '0');
                
                WRITE_ADDRESS_PIPE0_cs <= (others => '0');
                WRITE_ADDRESS_PIPE1_cs <= (others => '0');
                WRITE_ADDRESS_PIPE2_cs <= (others => '0');
                WRITE_ADDRESS_PIPE3_cs <= (others => '0');
                WRITE_ADDRESS_PIPE4_cs <= (others => '0');
                WRITE_ADDRESS_PIPE5_cs <= (others => '0');
                
                READ_ADDRESS_PIPE0_cs <= (others => '0');
                READ_ADDRESS_PIPE1_cs <= (others => '0');
                READ_ADDRESS_PIPE2_cs <= (others => '0');
                READ_ADDRESS_PIPE3_cs <= (others => '0');
                READ_ADDRESS_PIPE4_cs <= (others => '0');
                READ_ADDRESS_PIPE5_cs <= (others => '0');
            else
                if ENABLE = '1' then 
                    DSP_ADD_PORT0_cs    <= DSP_ADD_PORT0_ns;
                    DSP_ADD_PORT1_cs    <= DSP_ADD_PORT1_ns;
                    DSP_RESULT_PORT_cs  <= DSP_RESULT_PORT_ns;
                    DSP_PIPE0_cs        <= DSP_PIPE0_ns;
                    DSP_PIPE1_cs        <= DSP_PIPE1_ns;
                    
                    ACCUMULATE_PORT_PIPE0_cs <= ACCUMULATE_PORT_PIPE0_ns;
                    ACCUMULATE_PORT_PIPE1_cs <= ACCUMULATE_PORT_PIPE1_ns;
                    
                    ACCUMULATE_PIPE_cs <= ACCUMULATE_PIPE_ns;
                    
                    WRITE_PORT_PIPE0_cs <= WRITE_PORT_PIPE0_ns;
                    WRITE_PORT_PIPE1_cs <= WRITE_PORT_PIPE1_ns;
                    WRITE_PORT_PIPE2_cs <= WRITE_PORT_PIPE2_ns;
                    
                    WRITE_ENABLE_PIPE_cs <= WRITE_ENABLE_PIPE_ns;
                
                    WRITE_ADDRESS_PIPE0_cs <= WRITE_ADDRESS_PIPE0_ns;
                    WRITE_ADDRESS_PIPE1_cs <= WRITE_ADDRESS_PIPE1_ns;
                    WRITE_ADDRESS_PIPE2_cs <= WRITE_ADDRESS_PIPE2_ns;
                    WRITE_ADDRESS_PIPE3_cs <= WRITE_ADDRESS_PIPE3_ns;
                    WRITE_ADDRESS_PIPE4_cs <= WRITE_ADDRESS_PIPE4_ns;
                    WRITE_ADDRESS_PIPE5_cs <= WRITE_ADDRESS_PIPE5_ns;
                    
                    READ_ADDRESS_PIPE0_cs <= READ_ADDRESS_PIPE0_ns;
                    READ_ADDRESS_PIPE1_cs <= READ_ADDRESS_PIPE1_ns;
                    READ_ADDRESS_PIPE2_cs <= READ_ADDRESS_PIPE2_ns;
                    READ_ADDRESS_PIPE3_cs <= READ_ADDRESS_PIPE3_ns;
                    READ_ADDRESS_PIPE4_cs <= READ_ADDRESS_PIPE4_ns;
                    READ_ADDRESS_PIPE5_cs <= READ_ADDRESS_PIPE5_ns;
                end if;
            end if;
        end if;
    end process SEQ_LOG;
end architecture BEH;
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
    
entity TB_TPU is
end entity TB_TPU;

architecture BEH of TB_TPU is
    component DUT is
        generic(
            MATRIX_WIDTH            : natural := 14
        );  
        port(   
            CLK, RESET              : in  std_logic;
            ENABLE                  : in  std_logic;
            -- For data width check - 0 to 255 => width: 1 to 256
            TPU_MAX_INDEX           : out BYTE_TYPE;
            -- Splitted instruction input
            LOWER_INSTRUCTION_WORD  : in  WORD_TYPE;
            MIDDLE_INSTRUCTION_WORD : in  WORD_TYPE;
            UPPER_INSTRUCTION_WORD  : in  HALFWORD_TYPE;
            INSTRUCTION_WRITE_EN    : in  std_logic_vector(0 to 2);
            -- Instruction buffer flags for interrupts
            INSTRUCTION_EMPTY       : out std_logic;
            INSTRUCTION_FULL        : out std_logic;
        
            WEIGHT_WRITE_PORT       : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            WEIGHT_ADDRESS          : in  WEIGHT_ADDRESS_TYPE;
            WEIGHT_ENABLE           : in  std_logic;
            WEIGHT_WRITE_ENABLE     : in  std_logic_vector(0 to MATRIX_WIDTH-1);
                
            BUFFER_WRITE_PORT       : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            BUFFER_READ_PORT        : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            BUFFER_ADDRESS          : in  BUFFER_ADDRESS_TYPE;
            BUFFER_ENABLE           : in  std_logic;
            BUFFER_WRITE_ENABLE     : in  std_logic_vector(0 to MATRIX_WIDTH-1);
            -- Memory synchronization flag for interrupt 
            SYNCHRONIZE             : out std_logic
        );
    end component DUT;
    for all : DUT use entity WORK.TPU(BEH);
    
    constant MATRIX_WIDTH           : natural := 14;
    
    signal CLK                      : std_logic;
    signal RESET                    : std_logic;
    signal ENABLE                   : std_logic;
        
    signal TPU_MAX_INDEX            : BYTE_TYPE;
        
    signal LOWER_INSTRUCTION_WORD   : WORD_TYPE;
    signal MIDDLE_INSTRUCTION_WORD  : WORD_TYPE;
    signal UPPER_INSTRUCTION_WORD   : HALFWORD_TYPE;
    signal INSTRUCTION_WRITE_EN     : std_logic_vector(0 to 2);
        
    signal INSTRUCTION_EMPTY        : std_logic;
    signal INSTRUCTION_FULL         : std_logic;
        
    signal WEIGHT_WRITE_PORT        : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal WEIGHT_ADDRESS           : WEIGHT_ADDRESS_TYPE;
    signal WEIGHT_ENABLE            : std_logic;
    signal WEIGHT_WRITE_ENABLE      : std_logic_vector(0 to MATRIX_WIDTH-1);
            
    signal BUFFER_WRITE_PORT        : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal BUFFER_READ_PORT         : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal BUFFER_ADDRESS           : BUFFER_ADDRESS_TYPE;
    signal BUFFER_ENABLE            : std_logic;
    signal BUFFER_WRITE_ENABLE      : std_logic_vector(0 to MATRIX_WIDTH-1);
        
    signal SYNCHRONIZE              : std_logic;
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean;
    
    
    signal INSTRUCTION : INSTRUCTION_TYPE;
begin
    DUT_i : DUT
    generic map(
        MATRIX_WIDTH => MATRIX_WIDTH
    )
    port map(
        CLK => CLK,
        RESET => RESET,
        ENABLE => ENABLE,
        TPU_MAX_INDEX => TPU_MAX_INDEX,
        LOWER_INSTRUCTION_WORD => LOWER_INSTRUCTION_WORD,
        MIDDLE_INSTRUCTION_WORD => MIDDLE_INSTRUCTION_WORD,
        UPPER_INSTRUCTION_WORD => UPPER_INSTRUCTION_WORD,
        INSTRUCTION_WRITE_EN => INSTRUCTION_WRITE_EN,
        INSTRUCTION_EMPTY => INSTRUCTION_EMPTY,
        INSTRUCTION_FULL => INSTRUCTION_FULL,
        WEIGHT_WRITE_PORT => WEIGHT_WRITE_PORT,
        WEIGHT_ADDRESS => WEIGHT_ADDRESS,
        WEIGHT_ENABLE => WEIGHT_ENABLE,
        WEIGHT_WRITE_ENABLE => WEIGHT_WRITE_ENABLE,
        BUFFER_WRITE_PORT => BUFFER_WRITE_PORT,
        BUFFER_READ_PORT => BUFFER_READ_PORT,
        BUFFER_ADDRESS => BUFFER_ADDRESS,
        BUFFER_ENABLE => BUFFER_ENABLE,
        BUFFER_WRITE_ENABLE => BUFFER_WRITE_ENABLE,
        SYNCHRONIZE => SYNCHRONIZE
    );
    
    LOWER_INSTRUCTION_WORD <= INSTRUCTION_TO_BITS(INSTRUCTION)(4*BYTE_WIDTH-1 downto 0);
    MIDDLE_INSTRUCTION_WORD <= INSTRUCTION_TO_BITS(INSTRUCTION)(2*4*BYTE_WIDTH-1 downto 4*BYTE_WIDTH);
    UPPER_INSTRUCTION_WORD <= INSTRUCTION_TO_BITS(INSTRUCTION)(2*4*BYTE_WIDTH+2*BYTE_WIDTH-1 downto 2*4*BYTE_WIDTH);
    
    STIMULUS:
    process is
    begin
        ENABLE <= '0';
        RESET <= '0';
        INSTRUCTION <= INIT_INSTRUCTION;
        INSTRUCTION_WRITE_EN <= (others => '0');
        WEIGHT_WRITE_PORT <= (others => (others => '0'));
        WEIGHT_ADDRESS <= (others => '0');
        WEIGHT_ENABLE <= '0';
        WEIGHT_WRITE_ENABLE <= (others => '0');
        BUFFER_WRITE_PORT <= (others => (others => '0'));
        BUFFER_ADDRESS <= (others => '0');
        BUFFER_ENABLE <= '0';
        BUFFER_WRITE_ENABLE <= (others => '0');
        
        wait until '1'=CLK and CLK'event;
        RESET <= '1';
        wait until '1'=CLK and CLK'event;
        RESET <= '0';
        wait until '1'=CLK and CLK'event;
        ENABLE <= '1';
        INSTRUCTION.OP_CODE <= "00001000"; -- load weight
        INSTRUCTION.CALC_LENGTH <= std_logic_vector(to_unsigned(14, LENGTH_WIDTH));
        INSTRUCTION.BUFFER_ADDRESS <= x"000000";
        INSTRUCTION.ACC_ADDRESS <= x"0000";
        
        INSTRUCTION_WRITE_EN <= (others => '1');
        wait until '1'=CLK and CLK'event;
        INSTRUCTION.OP_CODE <= "00100000"; -- matrix multiply
        INSTRUCTION.CALC_LENGTH <= std_logic_vector(to_unsigned(14, LENGTH_WIDTH));
        INSTRUCTION.BUFFER_ADDRESS <= x"000000";
        INSTRUCTION.ACC_ADDRESS <= x"0000";
        
        INSTRUCTION_WRITE_EN <= (others => '1');
        wait until '1'=CLK and CLK'event;
        INSTRUCTION.OP_CODE <= "10001001"; -- unsigned sigmoid activation
        INSTRUCTION.CALC_LENGTH <= std_logic_vector(to_unsigned(14, LENGTH_WIDTH));
        INSTRUCTION.BUFFER_ADDRESS <= x"00000E"; -- store to address 14 and up
        INSTRUCTION.ACC_ADDRESS <= x"0000";
        
        INSTRUCTION_WRITE_EN <= (others => '1');
        wait until '1'=CLK and CLK'event;
        INSTRUCTION.OP_CODE <= "11111111"; -- synchronize
        INSTRUCTION.CALC_LENGTH <= x"00000000";
        INSTRUCTION.BUFFER_ADDRESS <= x"000000";
        INSTRUCTION.ACC_ADDRESS <= x"0000";
        
        INSTRUCTION_WRITE_EN <= (others => '1');
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_WRITE_EN <= (others => '0');
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
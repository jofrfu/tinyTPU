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
    
entity TB_CONTROL_COORDINATOR is
end entity TB_CONTROL_COORDINATOR;

architecture BEH of TB_CONTROL_COORDINATOR is
    component DUT is
        port(
            CLK, RESET                  :  in std_logic;
            ENABLE                      :  in std_logic;
                
            INSTRUCTION                 :  in INSTRUCTION_TYPE;
            INSTRUCTION_EN              :  in std_logic;
            
            BUSY                        : out std_logic;
            
            WEIGHT_BUSY                 :  in std_logic; 
            WEIGHT_INSTRUCTION          : out WEIGHT_INSTRUCTION_TYPE;
            WEIGHT_INSTRUCTION_EN       : out std_logic;
            
            MATRIX_BUSY                 :  in std_logic;
            MATRIX_INSTRUCTION          : out INSTRUCTION_TYPE;
            MATRIX_INSTRUCTION_EN       : out std_logic;
            
            ACTIVATION_BUSY             :  in std_logic;
            ACTIVATION_INSTRUCTION      : out INSTRUCTION_TYPE;
            ACTIVATION_INSTRUCTION_EN   : out std_logic
        );
    end component DUT;
    for all : DUT use entity WORK.CONTROL_COORDINATOR(BEH);
    
    signal CLK, RESET   : std_logic;
    signal ENABLE       : std_logic;
    
    signal INSTRUCTION      : INSTRUCTION_TYPE;
    signal INSTRUCTION_EN   : std_logic;
    
    signal BUSY : std_logic;
     
    signal WEIGHT_BUSY              : std_logic; 
    signal WEIGHT_INSTRUCTION       : WEIGHT_INSTRUCTION_TYPE;
    signal WEIGHT_INSTRUCTION_EN    : std_logic;
     
    signal MATRIX_BUSY              : std_logic;
    signal MATRIX_INSTRUCTION       : INSTRUCTION_TYPE;
    signal MATRIX_INSTRUCTION_EN    : std_logic;
     
    signal ACTIVATION_BUSY              : std_logic;
    signal ACTIVATION_INSTRUCTION       : INSTRUCTION_TYPE;
    signal ACTIVATION_INSTRUCTION_EN    : std_logic;
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean;
begin
    DUT_i : DUT
    port map(
        CLK                         => CLK,
        RESET                       => RESET,
        ENABLE                      => ENABLE,
        INSTRUCTION                 => INSTRUCTION,
        INSTRUCTION_EN              => INSTRUCTION_EN,
        BUSY                        => BUSY,
        WEIGHT_BUSY                 => WEIGHT_BUSY,
        WEIGHT_INSTRUCTION          => WEIGHT_INSTRUCTION,
        WEIGHT_INSTRUCTION_EN       => WEIGHT_INSTRUCTION_EN,
        MATRIX_BUSY                 => MATRIX_BUSY,
        MATRIX_INSTRUCTION          => MATRIX_INSTRUCTION,
        MATRIX_INSTRUCTION_EN       => MATRIX_INSTRUCTION_EN,
        ACTIVATION_BUSY             => ACTIVATION_BUSY,
        ACTIVATION_INSTRUCTION      => ACTIVATION_INSTRUCTION,
        ACTIVATION_INSTRUCTION_EN   => ACTIVATION_INSTRUCTION_EN
    );
    
    STIMULUS:
    process is
    begin
        RESET           <= '1';
        ENABLE          <= '0';
        INSTRUCTION     <= INIT_INSTRUCTION;
        INSTRUCTION_EN  <= '0';
        WEIGHT_BUSY     <= '0';
        MATRIX_BUSY     <= '0';
        ACTIVATION_BUSY <= '0';
        wait until '1'=CLK and CLK'event;
        RESET           <= '0';
        wait until '1'=CLK and CLK'event;
        -- Test weight
        ENABLE          <= '1';
        -- Test weight
        INSTRUCTION.OP_CODE <= "00001000";
        INSTRUCTION.CALC_LENGTH <= x"00000500";
        INSTRUCTION.ACC_ADDRESS <= x"0A30";
        INSTRUCTION_EN  <= '1';
        WEIGHT_BUSY     <= '0';
        MATRIX_BUSY     <= '0';
        ACTIVATION_BUSY <= '0';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_EN  <= '0';
        wait until '1'=CLK and CLK'event;
        -- Test multiple weight
        WEIGHT_BUSY     <= '1';
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        INSTRUCTION.OP_CODE <= "00001000";
        INSTRUCTION.CALC_LENGTH <= x"00047100";
        INSTRUCTION.ACC_ADDRESS <= x"0B30";
        INSTRUCTION_EN  <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_EN  <= '0';
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        WEIGHT_BUSY     <= '0';
        -- Test two weights in a row
        INSTRUCTION.CALC_LENGTH <= x"00000500";
        INSTRUCTION.ACC_ADDRESS <= x"0A30";
        INSTRUCTION_EN  <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION.CALC_LENGTH <= x"00095900";
        INSTRUCTION.ACC_ADDRESS <= x"0CD0";
        wait until '1'=CLK and CLK'event;
        WEIGHT_BUSY     <= '1';
        INSTRUCTION_EN <= '0';
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        WEIGHT_BUSY     <= '0';
        wait until '1'=CLK and CLK'event;
        
        -- Test matrix
        INSTRUCTION.OP_CODE <= "00101000";
        INSTRUCTION.CALC_LENGTH <= x"00300000";
        INSTRUCTION.ACC_ADDRESS <= x"0370";
        INSTRUCTION_EN  <= '1';
        WEIGHT_BUSY     <= '0';
        MATRIX_BUSY     <= '0';
        ACTIVATION_BUSY <= '0';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_EN  <= '0';
        wait until '1'=CLK and CLK'event;
        -- Test multiple matrix
        MATRIX_BUSY     <= '1';
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        INSTRUCTION.OP_CODE <= "00100001";
        INSTRUCTION.CALC_LENGTH <= x"00047100";
        INSTRUCTION.ACC_ADDRESS <= x"0B30";
        INSTRUCTION_EN  <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_EN  <= '0';
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        MATRIX_BUSY     <= '0';
        -- Test two matrix in a row
        INSTRUCTION.CALC_LENGTH <= x"00000500";
        INSTRUCTION.ACC_ADDRESS <= x"0A30";
        INSTRUCTION_EN  <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION.CALC_LENGTH <= x"00095900";
        INSTRUCTION.ACC_ADDRESS <= x"0CD0";
        wait until '1'=CLK and CLK'event;
        MATRIX_BUSY     <= '1';
        INSTRUCTION_EN <= '0';
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        MATRIX_BUSY     <= '0';
        
        -- Test activation
        INSTRUCTION.OP_CODE <= "10101000";
        INSTRUCTION.CALC_LENGTH <= x"00300000";
        INSTRUCTION.ACC_ADDRESS <= x"0370";
        INSTRUCTION_EN  <= '1';
        WEIGHT_BUSY     <= '0';
        MATRIX_BUSY     <= '0';
        ACTIVATION_BUSY <= '0';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_EN  <= '0';
        wait until '1'=CLK and CLK'event;
        -- Test multiple activation
        ACTIVATION_BUSY     <= '1';
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        INSTRUCTION.OP_CODE <= "10000001";
        INSTRUCTION.CALC_LENGTH <= x"00047100";
        INSTRUCTION.ACC_ADDRESS <= x"0B30";
        INSTRUCTION_EN  <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_EN  <= '0';
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        ACTIVATION_BUSY     <= '0';
        -- Test two activation in a row
        INSTRUCTION.CALC_LENGTH <= x"00000500";
        INSTRUCTION.ACC_ADDRESS <= x"0A30";
        INSTRUCTION_EN  <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION.CALC_LENGTH <= x"00095900";
        INSTRUCTION.ACC_ADDRESS <= x"0CD0";
        wait until '1'=CLK and CLK'event;
        ACTIVATION_BUSY     <= '1';
        INSTRUCTION_EN <= '0';
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        ACTIVATION_BUSY     <= '0';
        
        -- Test one after another
        INSTRUCTION.OP_CODE <= "00001000";
        INSTRUCTION.CALC_LENGTH <= x"00300000";
        INSTRUCTION.ACC_ADDRESS <= x"0370";
        INSTRUCTION_EN  <= '1';
        WEIGHT_BUSY     <= '0';
        MATRIX_BUSY     <= '0';
        ACTIVATION_BUSY <= '0';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION.OP_CODE <= "00100000";
        INSTRUCTION.CALC_LENGTH <= x"00000100";
        INSTRUCTION.ACC_ADDRESS <= x"0A70";
        wait until '1'=CLK and CLK'event;
        WEIGHT_BUSY <= '1';
        INSTRUCTION.OP_CODE <= "10000000";
        INSTRUCTION.CALC_LENGTH <= x"34000100";
        INSTRUCTION.ACC_ADDRESS <= x"AFFE";
        wait until '1'=CLK and CLK'event;
        MATRIX_BUSY <= '1';
        INSTRUCTION_EN <= '0';
        wait until '1'=CLK and CLK'event;
        ACTIVATION_BUSY <= '1';
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
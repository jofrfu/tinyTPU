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
    
entity TB_MATRIX_MULTIPLY_CONTROL is
end entity TB_MATRIX_MULTIPLY_CONTROL;

architecture BEH of TB_MATRIX_MULTIPLY_CONTROL is
    component DUT is
        generic(
            MATRIX_WIDTH    : natural := 14
        );
        port(
            CLK, RESET      :  in std_logic;
            ENABLE          :  in std_logic; 
            
            INSTRUCTION     :  in INSTRUCTION_TYPE;
            INSTRUCTION_EN  :  in std_logic;
            
            BUF_TO_SDS_ADDR : out BUFFER_ADDRESS_TYPE;
            BUF_READ_EN     : out std_logic;
            MMU_SDS_EN      : out std_logic;
            MMU_SIGNED      : out std_logic;
            ACTIVATE_WEIGHT : out std_logic;
            
            ACC_ADDR        : out ACCUMULATOR_ADDRESS_TYPE;
            ACCUMULATE      : out std_logic;
            ACC_ENABLE      : out std_logic;
            
            BUSY            : out std_logic
        );
    end component DUT;
    for all : DUT use entity WORK.MATRIX_MULTIPLY_CONTROL(BEH);
    
    signal CLK, RESET   : std_logic;
    signal ENABLE       : std_logic;
    
    signal INSTRUCTION      : INSTRUCTION_TYPE;
    signal INSTRUCTION_EN   : std_logic;
    
    signal BUF_TO_SDS_ADDR  : BUFFER_ADDRESS_TYPE;
    signal BUF_READ_EN      : std_logic;
    signal MMU_SDS_EN       : std_logic;
    signal MMU_SIGNED       : std_logic;
    signal ACTIVATE_WEIGHT  : std_logic;
    
    signal ACC_ADDR     : ACCUMULATOR_ADDRESS_TYPE;
    signal ACCUMULATE   : std_logic;
    signal ACC_ENABLE   : std_logic;
    
    signal BUSY : std_logic;
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean;
begin
    DUT_i : DUT
    port map(
        CLK => CLK,
        RESET => RESET,
        ENABLE => ENABLE,
        INSTRUCTION => INSTRUCTION,
        INSTRUCTION_EN => INSTRUCTION_EN,
        BUF_TO_SDS_ADDR => BUF_TO_SDS_ADDR,
        BUF_READ_EN => BUF_READ_EN,
        MMU_SDS_EN => MMU_SDS_EN,
        MMU_SIGNED => MMU_SIGNED,
        ACTIVATE_WEIGHT => ACTIVATE_WEIGHT,
        ACC_ADDR => ACC_ADDR,
        ACCUMULATE => ACCUMULATE,
        ACC_ENABLE => ACC_ENABLE,
        BUSY => BUSY
    );

    STIMULUS:
    process is
    begin
        stop_the_clock <= false;
        ENABLE <= '0';
        RESET <= '1';
        INSTRUCTION.OP_CODE <= (others => '0');
        INSTRUCTION.CALC_LENGTH <= (others => '0');
        INSTRUCTION.ACC_ADDRESS <= (others => '0');
        INSTRUCTION.BUFFER_ADDRESS <= (others => '0');
        INSTRUCTION_EN <= '0';
        wait until '1'=CLK and CLK'event;
        RESET <= '0';
        wait until '1'=CLK and CLK'event;
        -- Test
        ENABLE <= '1';
        INSTRUCTION.OP_CODE <= "00100011"; -- matrix multiply
        INSTRUCTION.CALC_LENGTH <= std_logic_vector(to_unsigned(29, LENGTH_WIDTH));
        INSTRUCTION.ACC_ADDRESS <= x"0049";
        INSTRUCTION.BUFFER_ADDRESS <= x"009463";
        INSTRUCTION_EN <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_EN <= '0';
        wait until BUSY = '0';
        INSTRUCTION.OP_CODE <= "00100000"; -- matrix multiply
        INSTRUCTION.CALC_LENGTH <= std_logic_vector(to_unsigned(14, LENGTH_WIDTH));
        INSTRUCTION.ACC_ADDRESS <= x"0006";
        INSTRUCTION.BUFFER_ADDRESS <= x"0000AB";
        INSTRUCTION_EN <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_EN <= '0';
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
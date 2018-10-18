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
    
entity TB_ACTIVATION_CONTROL is
end entity TB_ACTIVATION_CONTROL;

architecture BEH of TB_ACTIVATION_CONTROL is
    component DUT is
        port(
            CLK, RESET          :  in std_logic;
            ENABLE              :  in std_logic;
            
            INSTRUCTION         :  in INSTRUCTION_TYPE;
            INSTRUCTION_EN      :  in std_logic;
            
            ACC_TO_ACT_ADDR     : out ACCUMULATOR_ADDRESS_TYPE;
            ACTIVATION_FUNCTION : out ACTIVATION_BIT_TYPE;
            SIGNED_NOT_UNSIGNED : out std_logic;
            
            ACT_TO_BUF_ADDR     : out BUFFER_ADDRESS_TYPE;
            BUF_WRITE_EN        : out std_logic;
            
            BUSY                : out std_logic
        );
    end component DUT;
    for all : DUT use entity WORK.ACTIVATION_CONTROL(BEH);
    
    signal CLK, RESET   : std_logic;
    signal ENABLE       : std_logic;
    
    signal INSTRUCTION      : INSTRUCTION_TYPE;
    signal INSTRUCTION_EN   : std_logic;
    
    signal ACC_TO_ACT_ADDR     : ACCUMULATOR_ADDRESS_TYPE;
    signal ACTIVATION_FUNCTION : ACTIVATION_BIT_TYPE;
    signal SIGNED_NOT_UNSIGNED : std_logic;
    
    signal ACT_TO_BUF_ADDR : BUFFER_ADDRESS_TYPE;
    signal BUF_WRITE_EN    : std_logic;
    
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
        ACC_TO_ACT_ADDR => ACC_TO_ACT_ADDR,
        ACTIVATION_FUNCTION => ACTIVATION_FUNCTION,
        SIGNED_NOT_UNSIGNED => SIGNED_NOT_UNSIGNED,
        ACT_TO_BUF_ADDR => ACT_TO_BUF_ADDR,
        BUF_WRITE_EN => BUF_WRITE_EN,
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
        INSTRUCTION.OP_CODE <= "10011001"; -- signed sigmoid
        INSTRUCTION.CALC_LENGTH <= std_logic_vector(to_unsigned(5, LENGTH_WIDTH));
        INSTRUCTION.ACC_ADDRESS <= x"0946";
        INSTRUCTION.BUFFER_ADDRESS <= x"000084";
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
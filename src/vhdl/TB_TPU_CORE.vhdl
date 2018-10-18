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
    
entity TB_TPU_CORE is
end entity TB_TPU_CORE;

architecture BEH of TB_TPU_CORE is
    component DUT is
        generic(
            MATRIX_WIDTH        : natural := 14
        );
        port(
            CLK, RESET          : in  std_logic;
            ENABLE              : in  std_logic;
        
            WEIGHT_WRITE_PORT   : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            WEIGHT_ADDRESS      : in  WEIGHT_ADDRESS_TYPE;
            WEIGHT_ENABLE       : in  std_logic;
            WEIGHT_WRITE_ENABLE : in  std_logic_vector(0 to MATRIX_WIDTH-1);
            
            BUFFER_WRITE_PORT   : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            BUFFER_READ_PORT    : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            BUFFER_ADDRESS      : in  BUFFER_ADDRESS_TYPE;
            BUFFER_ENABLE       : in  std_logic;
            BUFFER_WRITE_ENABLE : in  std_logic_vector(0 to MATRIX_WIDTH-1);
            
            INSTRUCTION_PORT    : in  INSTRUCTION_TYPE;
            INSTRUCTION_ENABLE  : in  std_logic;
            
            BUSY                : out std_logic;
            SYNCHRONIZE         : out std_logic
        );
    end component DUT;
    for all : DUT use entity WORK.TPU_CORE(BEH);
    
    signal CLK                  : std_logic;
    signal RESET                : std_logic;
    signal ENABLE               : std_logic;
    signal INSTRUCTION_PORT     : INSTRUCTION_TYPE;
    signal INSTRUCTION_ENABLE   : std_logic;
    signal BUSY                 : std_logic;
    signal SYNCHRONIZE          : std_logic;
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean := false;
begin
    DUT_i : DUT
    generic map(
        MATRIX_WIDTH => 14
    )
    port map(
        CLK => CLK,
        RESET => RESET,
        ENABLE => ENABLE,
        INSTRUCTION_PORT => INSTRUCTION_PORT,
        INSTRUCTION_ENABLE => INSTRUCTION_ENABLE,
        
        WEIGHT_WRITE_PORT => (others => (others => '0')),
        WEIGHT_ADDRESS => (others => '0'),
        WEIGHT_ENABLE => '0',
        WEIGHT_WRITE_ENABLE => (others => '0'),
        
        BUFFER_WRITE_PORT => (others => (others => '0')),
        BUFFER_ADDRESS => (others => '0'),
        BUFFER_ENABLE => '0',
        BUFFER_WRITE_ENABLE => (others => '0'),
        
        BUSY => BUSY,
        SYNCHRONIZE => SYNCHRONIZE
    );
    
    STIMULUS:
    process is
    begin
        ENABLE <= '0';
        RESET <= '0';
        INSTRUCTION_PORT <= INIT_INSTRUCTION;
        INSTRUCTION_ENABLE <= '0';
        wait until '1'=CLK and CLK'event;
        RESET <= '1';
        wait until '1'=CLK and CLK'event;
        RESET <= '0';
        wait until '1'=CLK and CLK'event;
        ENABLE <= '1';
        INSTRUCTION_PORT.OP_CODE <= "00001001"; -- load weight
        INSTRUCTION_PORT.CALC_LENGTH <= std_logic_vector(to_unsigned(14, LENGTH_WIDTH));
        INSTRUCTION_PORT.BUFFER_ADDRESS <= x"000000";
        INSTRUCTION_PORT.ACC_ADDRESS <= x"0000";
        
        INSTRUCTION_ENABLE <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_PORT.OP_CODE <= "00100001"; -- matrix multiply
        INSTRUCTION_PORT.CALC_LENGTH <= std_logic_vector(to_unsigned(14, LENGTH_WIDTH));
        INSTRUCTION_PORT.BUFFER_ADDRESS <= x"000000";
        INSTRUCTION_PORT.ACC_ADDRESS <= x"0000";
        
        INSTRUCTION_ENABLE <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_PORT.OP_CODE <= "10011001"; -- unsigned sigmoid activation
        INSTRUCTION_PORT.CALC_LENGTH <= std_logic_vector(to_unsigned(14, LENGTH_WIDTH));
        INSTRUCTION_PORT.BUFFER_ADDRESS <= x"00000E"; -- store to address 14 and up
        INSTRUCTION_PORT.ACC_ADDRESS <= x"0000";
        
        INSTRUCTION_ENABLE <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_PORT.OP_CODE <= "11111111"; -- synchronize
        INSTRUCTION_PORT.CALC_LENGTH <= x"00000000";
        INSTRUCTION_PORT.BUFFER_ADDRESS <= x"000000";
        INSTRUCTION_PORT.ACC_ADDRESS <= x"0000";
        
        INSTRUCTION_ENABLE <= '1';
        wait until '1'=CLK and CLK'event;
        INSTRUCTION_ENABLE <= '0';
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
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
    
entity TB_ACTIVATION is
end entity TB_ACTIVATION;

architecture BEH of TB_ACTIVATION is
    component DUT is
        generic(
            MATRIX_WIDTH        : natural := 14
        );
        port(
            CLK, RESET          : in  std_logic;
            ENABLE              : in  std_logic;
            
            ACTIVATION_FUNCTION : in ACTIVATION_BIT_TYPE;
            SIGNED_NOT_UNSIGNED : in std_logic;
            
            ACTIVATION_INPUT    : in  WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            ACTIVATION_OUTPUT   : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1)
        );
    end component DUT;
    for all : DUT use entity WORK.ACTIVATION(BEH);
    
    constant MATRIX_WIDTH       : natural := 4;
    signal CLK, RESET           : std_logic;
    signal ENABLE               : std_logic;
    signal ACTIVATION_FUNCTION  : ACTIVATION_BIT_TYPE;
    signal SIGNED_NOT_UNSIGNED  : std_logic;
    signal ACTIVATION_INPUT     : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal ACTIVATION_OUTPUT    : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    signal ACTIVATION_FUNCTION_AS_TYPE  : ACTIVATION_TYPE;
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean;
begin
    DUT_i : DUT
    generic map(
        MATRIX_WIDTH => MATRIX_WIDTH
    )
    port map(
        CLK => CLK,
        RESET => RESET,
        ENABLE => ENABLE,
        ACTIVATION_FUNCTION => ACTIVATION_FUNCTION,
        SIGNED_NOT_UNSIGNED => SIGNED_NOT_UNSIGNED,
        ACTIVATION_INPUT => ACTIVATION_INPUT,
        ACTIVATION_OUTPUT => ACTIVATION_OUTPUT
    );
    
    ACTIVATION_FUNCTION <= ACTIVATION_TO_BITS(ACTIVATION_FUNCTION_AS_TYPE);
    
    STIMULUS:
    process is
    begin
        stop_the_clock <= false;
        RESET <= '0';
        ENABLE <= '0';
        SIGNED_NOT_UNSIGNED <= '0';
        ACTIVATION_INPUT <= (others => (others => '0'));
        ACTIVATION_FUNCTION_AS_TYPE <= NO_ACTIVATION;
        -- RESET
        RESET <= '1';
        wait until '1'=CLK and CLK'event;
        RESET <= '0';
        wait until '1'=CLK and CLK'event;
        ENABLE <= '1';
        
        -- TEST: signed Sigmoid
        SIGNED_NOT_UNSIGNED <= '1';
        ACTIVATION_FUNCTION_AS_TYPE <= SIGMOID;
        -- test boundary: −2147483648           - equivalence class 0
        ACTIVATION_INPUT <= (others => std_logic_vector(to_signed(-2147483648, 4*BYTE_WIDTH)));
        wait until '1'=CLK and CLK'event;
        -- test one value in between: -367289   - equivalence class 0
        ACTIVATION_INPUT <= (others => std_logic_vector(to_signed(-367289, 4*BYTE_WIDTH)));
        wait until '1'=CLK and CLK'event;
        -- test boundary: -6                    - equivalence class 0
        ACTIVATION_INPUT <= (others => std_logic_vector(to_signed(-6, 2*BYTE_WIDTH)) & std_logic_vector(to_signed(0, 2*BYTE_WIDTH)));
        wait until '1'=CLK and CLK'event;
        -- test transition values
        for i in -5 to 5 loop
            for j in 0 to 255 loop
                ACTIVATION_INPUT <= (others => std_logic_vector(to_signed(i, 2*BYTE_WIDTH)) & std_logic_vector(to_signed(j, BYTE_WIDTH)) & std_logic_vector(to_signed(0, BYTE_WIDTH)));
                wait until '1'=CLK and CLK'event;
            end loop;
        end loop;
        -- test boundary: 6                     - equivalence class 127
        ACTIVATION_INPUT <= (others => std_logic_vector(to_signed(6, 2*BYTE_WIDTH)) & std_logic_vector(to_unsigned(0, 2*BYTE_WIDTH)));
        wait until '1'=CLK and CLK'event;
        -- test one value in between: 8381865   - equivalence class 127
        ACTIVATION_INPUT <= (others => std_logic_vector(to_signed(8381865, 4*BYTE_WIDTH)));
        wait until '1'=CLK and CLK'event;
        -- test boundary 2147483647:            - equivalence class 127
        ACTIVATION_INPUT <= (others => std_logic_vector(to_signed(2147483647, 4*BYTE_WIDTH)));
        wait until '1'=CLK and CLK'event;
        
        -- TEST: unsigned Sigmoid
        SIGNED_NOT_UNSIGNED <= '0';
        ACTIVATION_FUNCTION_AS_TYPE <= SIGMOID;
        -- test transition values
        for i in 0 to 6 loop
            for j in 0 to 255 loop
                ACTIVATION_INPUT <= (others => std_logic_vector(to_unsigned(i, 2*BYTE_WIDTH)) & std_logic_vector(to_unsigned(j, BYTE_WIDTH)) & std_logic_vector(to_unsigned(0, BYTE_WIDTH)));
                wait until '1'=CLK and CLK'event;
            end loop;
        end loop;
        -- test boundary: 7                     - equivalence class 255
        ACTIVATION_INPUT <= (others => std_logic_vector(to_unsigned(7, 2*BYTE_WIDTH)) & std_logic_vector(to_unsigned(0, 2*BYTE_WIDTH)));
        wait until '1'=CLK and CLK'event;
        -- test one value in between: 98235281  - equivalence class 255
        ACTIVATION_INPUT <= (others => std_logic_vector(to_unsigned(98235281, 4*BYTE_WIDTH)));
        wait until '1'=CLK and CLK'event;
        -- test boundary 4294967295:            - equivalence class 255
        ACTIVATION_INPUT <= (others => (others => '1'));
        wait until '1'=CLK and CLK'event;
        
        -- TEST: signed ReLU
        SIGNED_NOT_UNSIGNED <= '1';
        ACTIVATION_FUNCTION_AS_TYPE <= ReLU;
        for i in -128 to 127 loop
            for j in 0 to 255 loop
                ACTIVATION_INPUT <= (others => std_logic_vector(to_signed(i, 2*BYTE_WIDTH)) & std_logic_vector(to_signed(j, BYTE_WIDTH)) & x"00");
                wait until '1'=CLK and CLK'event;
            end loop;
        end loop;
        
        -- TEST: unsigned ReLU
        SIGNED_NOT_UNSIGNED <= '0';
        ACTIVATION_FUNCTION_AS_TYPE <= ReLU;
        for i in 0 to 255 loop
            for j in 0 to 255 loop
                ACTIVATION_INPUT <= (others => std_logic_vector(to_unsigned(i, 2*BYTE_WIDTH)) & std_logic_vector(to_unsigned(j, BYTE_WIDTH)) & x"00");
                wait until '1'=CLK and CLK'event;
            end loop;
        end loop;
        
        stop_the_clock <= true;
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
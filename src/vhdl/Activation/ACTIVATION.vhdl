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

--! @file ACTIVATION.vhdl
--! @author Jonas Fuhrmann
--! @brief This component calculates the selected activation function for the input array.
--! @details The input is rounded, has some checker logic for ReLU and look-up-tables for the sigmoid function.
--! All functions are quantized.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    
entity ACTIVATION is
    generic(
        MATRIX_WIDTH        : natural := 14
    );
    port(
        CLK, RESET          : in  std_logic;
        ENABLE              : in  std_logic;
        
        ACTIVATION_FUNCTION : in  ACTIVATION_BIT_TYPE;
        SIGNED_NOT_UNSIGNED : in  std_logic;
        
        ACTIVATION_INPUT    : in  WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
        ACTIVATION_OUTPUT   : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1)
    );
end entity ACTIVATION;

--! @brief The architecture of the activation component.
architecture BEH of ACTIVATION is
    
    constant SIGMOID_UNSIGNED   : INTEGER_ARRAY_TYPE(0 to 164)  := (128,130,132,134,136,138,140,142,144,146,148,150,152,154,156,157,159,161,163,165,167,169,170,172,174,176,177,179,181,182,184,186,187,189,190,192,193,195,196,198,199,200,202,203,204,206,207,208,209,210,212,213,214,215,216,217,218,219,220,221,222,223,224,225,225,226,227,228,229,229,230,231,232,232,233,234,234,235,235,236,237,237,238,238,239,239,240,240,241,241,241,242,242,243,243,243,244,244,245,245,245,246,246,246,246,247,247,247,248,248,248,248,248,249,249,249,249,250,250,250,250,250,250,251,251,251,251,251,251,252,252,252,252,252,252,252,252,253,253,253,253,253,253,253,253,253,253,253,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254,254);
    constant SIGMOID_SIGNED     : INTEGER_ARRAY_TYPE(-88 to 70) := (1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,3,3,3,3,3,4,4,4,4,4,5,5,5,6,6,6,7,7,8,8,9,9,10,10,11,12,12,13,14,14,15,16,17,18,19,20,21,22,23,25,26,27,29,30,31,33,34,36,38,39,41,43,45,46,48,50,52,54,56,58,60,62,64,66,68,70,72,74,76,78,80,82,83,85,87,89,90,92,94,95,97,98,99,101,102,103,105,106,107,108,109,110,111,112,113,114,114,115,116,116,117,118,118,119,119,120,120,121,121,122,122,122,123,123,123,124,124,124,124,124,125,125,125,125,125,126,126,126,126,126,126,126,126);

    type SIGMOID_ARRAY_TYPE is array(natural range<>) of std_logic_vector(20 downto 0);
    type RELU_ARRAY_TYPE is array(natural range<>) of std_logic_vector(3*BYTE_WIDTH-1 downto 0);
    
    signal INPUT_REG_cs     : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal INPUT_REG_ns     : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    signal INPUT_PIPE0_cs   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal INPUT_PIPE0_ns   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    signal RELU_ROUND_REG_cs    : RELU_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal RELU_ROUND_REG_ns    : RELU_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    signal SIGMOID_ROUND_REG_cs : SIGMOID_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal SIGMOID_ROUND_REG_ns : SIGMOID_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    signal RELU_OUTPUT      : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal SIGMOID_OUTPUT   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    signal OUTPUT_REG_cs    : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal OUTPUT_REG_ns    : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    signal ACTIVATION_FUNCTION_REG0_cs  : ACTIVATION_BIT_TYPE := (others => '0');
    signal ACTIVATION_FUNCTION_REG0_ns  : ACTIVATION_BIT_TYPE;
    signal ACTIVATION_FUNCTION_REG1_cs  : ACTIVATION_BIT_TYPE := (others => '0');
    signal ACTIVATION_FUNCTION_REG1_ns  : ACTIVATION_BIT_TYPE;
    
    signal SIGNED_NOT_UNSIGNED_REG_cs   : std_logic_vector(0 to 1) := (others => '0');
    signal SIGNED_NOT_UNSIGNED_REG_ns   : std_logic_vector(0 to 1);
begin

    INPUT_REG_ns    <= ACTIVATION_INPUT;
    
    ROUND:
    process(INPUT_REG_cs, SIGNED_NOT_UNSIGNED_REG_cs(0)) is
    begin
        for i in 0 to MATRIX_WIDTH-1 loop
            INPUT_PIPE0_ns(i)       <= INPUT_REG_cs(i)(4*BYTE_WIDTH-1 downto 3*BYTE_WIDTH);
            RELU_ROUND_REG_ns(i)    <= std_logic_vector(unsigned(INPUT_REG_cs(i)(4*BYTE_WIDTH-1 downto 1*BYTE_WIDTH)) + INPUT_REG_cs(i)(1*BYTE_WIDTH-1));
            
            if SIGNED_NOT_UNSIGNED_REG_cs(0) = '0' then
                -- unsigned - Qu3.5 table range
                SIGMOID_ROUND_REG_ns(i) <= std_logic_vector(unsigned(INPUT_REG_cs(i)(4*BYTE_WIDTH-1 downto 2*BYTE_WIDTH-5)) + INPUT_REG_cs(i)(2*BYTE_WIDTH-6));
            else
                -- signed - Q4.4 table range
                SIGMOID_ROUND_REG_ns(i) <= std_logic_vector(unsigned(INPUT_REG_cs(i)(4*BYTE_WIDTH-1 downto 2*BYTE_WIDTH-4)) + INPUT_REG_cs(i)(2*BYTE_WIDTH-5)) & '0';
            end if;
        end loop;
    end process ROUND;
    
    ACTIVATION_FUNCTION_REG0_ns <= ACTIVATION_FUNCTION;
    ACTIVATION_FUNCTION_REG1_ns <= ACTIVATION_FUNCTION_REG0_cs;
    
    SIGNED_NOT_UNSIGNED_REG_ns(0) <= SIGNED_NOT_UNSIGNED;
    SIGNED_NOT_UNSIGNED_REG_ns(1) <= SIGNED_NOT_UNSIGNED_REG_cs(0);
    
    RELU_ACTIVATION:
    process(SIGNED_NOT_UNSIGNED_REG_cs(1), RELU_ROUND_REG_cs) is
        variable SIGNED_NOT_UNSIGNED_v  : std_logic;
        variable RELU_ROUND_v           : RELU_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
        
        variable RELU_OUTPUT_v          : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    begin
        SIGNED_NOT_UNSIGNED_v   := SIGNED_NOT_UNSIGNED_REG_cs(1);
        RELU_ROUND_v            := RELU_ROUND_REG_cs;
        
        for i in 0 to MATRIX_WIDTH-1 loop
            if SIGNED_NOT_UNSIGNED_v = '1' then
                if    signed(RELU_ROUND_v(i)) <   0 then
                    RELU_OUTPUT_v(i) := (others => '0');
                elsif signed(RELU_ROUND_v(i)) > 127 then -- Bounded ReLU
                    RELU_OUTPUT_v(i) := std_logic_vector(to_signed(127, BYTE_WIDTH));
                else
                    RELU_OUTPUT_v(i) := RELU_ROUND_v(i)(BYTE_WIDTH-1 downto 0);
                end if;
            else
                if  unsigned(RELU_ROUND_v(i)) > 255 then -- Bounded ReLU
                    RELU_OUTPUT_v(i) := std_logic_vector(to_unsigned(255, BYTE_WIDTH));
                else
                    RELU_OUTPUT_v(i) := RELU_ROUND_v(i)(BYTE_WIDTH-1 downto 0);
                end if;
            end if;
        end loop;
        
        RELU_OUTPUT <= RELU_OUTPUT_v;
    end process RELU_ACTIVATION;
    
    SIGMOID_ACTIVATION:
    process(SIGNED_NOT_UNSIGNED_REG_cs(1), SIGMOID_ROUND_REG_cs) is
        variable SIGNED_NOT_UNSIGNED_v  : std_logic;
        variable SIGMOID_ROUND_v        : SIGMOID_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
        
        variable SIGMOID_OUTPUT_v       : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    begin
        SIGNED_NOT_UNSIGNED_v   := SIGNED_NOT_UNSIGNED_REG_cs(1);
        SIGMOID_ROUND_v         := SIGMOID_ROUND_REG_cs;
        
        for i in 0 to MATRIX_WIDTH-1 loop
            if SIGNED_NOT_UNSIGNED_v = '1' then -- Signed
                if signed(SIGMOID_ROUND_v(i)(20 downto 1)) < -88 then
                    SIGMOID_OUTPUT_v(i) := (others => '0');
                elsif signed(SIGMOID_ROUND_v(i)(20 downto 1)) > 70 then
                    SIGMOID_OUTPUT_v(i) := std_logic_vector(to_signed(127, BYTE_WIDTH));
                else
                    SIGMOID_OUTPUT_v(i) := std_logic_vector(to_signed(SIGMOID_SIGNED(to_integer(signed(SIGMOID_ROUND_v(i)(20 downto 1)))), BYTE_WIDTH));
                end if;
            else    -- Unsigned
                if unsigned(SIGMOID_ROUND_v(i)) > 164 then
                    SIGMOID_OUTPUT_v(i) := std_logic_vector(to_unsigned(255, BYTE_WIDTH));
                else
                    SIGMOID_OUTPUT_v(i) := std_logic_vector(to_unsigned(SIGMOID_UNSIGNED(to_integer(unsigned(SIGMOID_ROUND_v(i)))), BYTE_WIDTH));
                end if;
            end if;
        end loop;
        
        SIGMOID_OUTPUT <= SIGMOID_OUTPUT_v;
    end process SIGMOID_ACTIVATION;
    
    CHOOSE_ACTIVATION:
    process(ACTIVATION_FUNCTION_REG1_cs, RELU_OUTPUT, SIGMOID_OUTPUT, INPUT_PIPE0_cs) is
        variable ACTIVATION_FUNCTION_v  : ACTIVATION_BIT_TYPE;
        variable RELU_OUTPUT_v          : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
        variable SIGMOID_OUTPUT_v       : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
        variable ACTIVATION_INPUT_v     : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
        
        variable OUTPUT_REG_ns_v        : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    begin
        ACTIVATION_FUNCTION_v   := ACTIVATION_FUNCTION_REG1_cs;
        RELU_OUTPUT_v           := RELU_OUTPUT;
        SIGMOID_OUTPUT_v        := SIGMOID_OUTPUT;
        ACTIVATION_INPUT_v      := INPUT_PIPE0_cs;
        for i in 0 to MATRIX_WIDTH-1 loop            
            case BITS_TO_ACTIVATION(ACTIVATION_FUNCTION_v) is
                when RELU => OUTPUT_REG_ns_v(i) := RELU_OUTPUT_v(i);
                when SIGMOID => OUTPUT_REG_ns_v(i) := SIGMOID_OUTPUT_v(i);
                when NO_ACTIVATION => OUTPUT_REG_ns_v(i) := ACTIVATION_INPUT_v(i);
                when others => 
                    report "Unknown activation function!" severity ERROR;
                    OUTPUT_REG_ns_v(i) := ACTIVATION_INPUT_v(i);
            end case;
        end loop;
        
        OUTPUT_REG_ns <= OUTPUT_REG_ns_v;
    end process CHOOSE_ACTIVATION;
    
    ACTIVATION_OUTPUT <= OUTPUT_REG_cs;
    
    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                OUTPUT_REG_cs   <= (others => (others => '0'));
                INPUT_REG_cs    <= (others => (others => '0'));
                INPUT_PIPE0_cs  <= (others => (others => '0'));
                RELU_ROUND_REG_cs   <= (others => (others => '0'));
                SIGMOID_ROUND_REG_cs<= (others => (others => '0'));
                SIGNED_NOT_UNSIGNED_REG_cs  <= (others => '0');
                ACTIVATION_FUNCTION_REG0_cs <= (others => '0');
                ACTIVATION_FUNCTION_REG1_cs <= (others => '0');
            else
                if ENABLE = '1' then
                    OUTPUT_REG_cs   <= OUTPUT_REG_ns;
                    INPUT_REG_cs    <= INPUT_REG_ns;
                    INPUT_PIPE0_cs  <= INPUT_PIPE0_ns;
                    RELU_ROUND_REG_cs   <= RELU_ROUND_REG_ns;
                    SIGMOID_ROUND_REG_cs<= SIGMOID_ROUND_REG_ns;
                    SIGNED_NOT_UNSIGNED_REG_cs  <= SIGNED_NOT_UNSIGNED_REG_ns;
                    ACTIVATION_FUNCTION_REG0_cs <= ACTIVATION_FUNCTION_REG0_ns;
                    ACTIVATION_FUNCTION_REG1_cs <= ACTIVATION_FUNCTION_REG1_ns;
                end if;
            end if;
        end if;
    end process SEQ_LOG;
    
end architecture BEH;
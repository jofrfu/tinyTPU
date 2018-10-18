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

library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;

package TPU_PACK is
    constant BYTE_WIDTH : natural := 8;
    constant EXTENDED_BYTE_WIDTH : natural := BYTE_WIDTH+1;
    
    subtype BYTE_TYPE is std_logic_vector(BYTE_WIDTH-1 downto 0);
    subtype EXTENDED_BYTE_TYPE is std_logic_vector(EXTENDED_BYTE_WIDTH-1 downto 0);
    subtype MUL_HALFWORD_TYPE is std_logic_vector(2*EXTENDED_BYTE_WIDTH-1 downto 0);
    subtype HALFWORD_TYPE is std_logic_vector(2*BYTE_WIDTH-1 downto 0);
    subtype WORD_TYPE is std_logic_vector(4*BYTE_WIDTH-1 downto 0);
    
    type INTEGER_ARRAY_TYPE is array(integer range <>) of integer;
    type BIT_ARRAY_2D_TYPE is array(natural range <>, natural range <>) of std_logic;
    type BYTE_ARRAY_TYPE is array(natural range <>) of BYTE_TYPE;
    type BYTE_ARRAY_2D_TYPE is array(natural range <>, natural range <>) of BYTE_TYPE;
    type EXTENDED_BYTE_ARRAY is array(natural range <>) of EXTENDED_BYTE_TYPE;
    type HALFWORD_ARRAY_TYPE is array(natural range <>) of HALFWORD_TYPE;
    type WORD_ARRAY_TYPE is array(natural range <>) of WORD_TYPE;
    type WORD_ARRAY_2D_TYPE is array(natural range <>, natural range <>) of WORD_TYPE;
    
    -- Good for readable testbenches
    type INTEGER_ARRAY_2D_TYPE is array(natural range <>, natural range <>) of integer;
    
    -- Type for activation
    subtype ACTIVATION_BIT_TYPE is std_logic_vector(3 downto 0);
    type ACTIVATION_TYPE is (NO_ACTIVATION, RELU, RELU6, CRELU, ELU, SELU, SOFTPLUS, SOFTSIGN, DROPOUT, SIGMOID, TANH);
    -- Conversion functions
    function BITS_TO_ACTIVATION(BITVECTOR : ACTIVATION_BIT_TYPE) return ACTIVATION_TYPE;
    function ACTIVATION_TO_BITS(ACTIVATION_FUNCTION : ACTIVATION_TYPE) return ACTIVATION_BIT_TYPE;
    
    function BITS_TO_BYTE_ARRAY(BITVECTOR : std_logic_vector) return BYTE_ARRAY_TYPE;
    function BYTE_ARRAY_TO_BITS(BYTE_ARRAY : BYTE_ARRAY_TYPE) return std_logic_vector;
    
    function BITS_TO_WORD_ARRAY(BITVECTOR : std_logic_vector) return WORD_ARRAY_TYPE;
    function WORD_ARRAY_TO_BITS(WORD_ARRAY : WORD_ARRAY_TYPE) return std_logic_vector;
    
    -- Control types
    constant BUFFER_ADDRESS_WIDTH : natural := 24;
    constant ACCUMULATOR_ADDRESS_WIDTH : natural := 16;
    constant WEIGHT_ADDRESS_WIDTH : natural := BUFFER_ADDRESS_WIDTH + ACCUMULATOR_ADDRESS_WIDTH;
    constant LENGTH_WIDTH : natural := 32;
    constant OP_CODE_WIDTH : natural := 8;
    constant INSTRUCTION_WIDTH : natural := WEIGHT_ADDRESS_WIDTH + LENGTH_WIDTH + OP_CODE_WIDTH;
    
    subtype BUFFER_ADDRESS_TYPE is std_logic_vector(BUFFER_ADDRESS_WIDTH-1 downto 0);
    subtype ACCUMULATOR_ADDRESS_TYPE is std_logic_vector(ACCUMULATOR_ADDRESS_WIDTH-1 downto 0);
    subtype WEIGHT_ADDRESS_TYPE is std_logic_vector(WEIGHT_ADDRESS_WIDTH-1 downto 0);
    subtype LENGTH_TYPE is std_logic_vector(LENGTH_WIDTH-1 downto 0);
    subtype OP_CODE_TYPE is std_logic_vector(OP_CODE_WIDTH-1 downto 0);
    
    type INSTRUCTION_TYPE is record
        OP_CODE : OP_CODE_TYPE;
        CALC_LENGTH : LENGTH_TYPE;
        ACC_ADDRESS : ACCUMULATOR_ADDRESS_TYPE;
        BUFFER_ADDRESS : BUFFER_ADDRESS_TYPE;
    end record INSTRUCTION_TYPE;
    
    type WEIGHT_INSTRUCTION_TYPE is record
        OP_CODE : OP_CODE_TYPE;
        CALC_LENGTH : LENGTH_TYPE;
        WEIGHT_ADDRESS : WEIGHT_ADDRESS_TYPE;
    end record WEIGHT_INSTRUCTION_TYPE;
    
    function TO_WEIGHT_INSTRUCTION(INSTRUCTION : INSTRUCTION_TYPE) return WEIGHT_INSTRUCTION_TYPE;
    
    function INSTRUCTION_TO_BITS(INSTRUCTION : INSTRUCTION_TYPE) return std_logic_vector;
    
    function BITS_TO_INSTRUCTION(BITVECTOR : std_logic_vector(10*BYTE_WIDTH-1 downto 0)) return INSTRUCTION_TYPE;
    
    function INIT_INSTRUCTION return INSTRUCTION_TYPE;
end TPU_PACK;

package body TPU_PACK is
    function BITS_TO_ACTIVATION(BITVECTOR : ACTIVATION_BIT_TYPE) return ACTIVATION_TYPE is
    begin
        case BITVECTOR is
            when "0000" => return NO_ACTIVATION;
            when "0001" => return RELU;
            when "0010" => return RELU6;
            when "0011" => return CRELU;
            when "0100" => return ELU;
            when "0101" => return SELU;
            when "0110" => return SOFTPLUS;
            when "0111" => return SOFTSIGN;
            when "1000" => return DROPOUT;
            when "1001" => return SIGMOID;
            when "1010" => return TANH;
            when others => 
                report "Unknown activation function!" severity ERROR;
                return NO_ACTIVATION;
        end case;
    end function BITS_TO_ACTIVATION;
    
    function ACTIVATION_TO_BITS(ACTIVATION_FUNCTION : ACTIVATION_TYPE) return ACTIVATION_BIT_TYPE is
    begin
        case ACTIVATION_FUNCTION is
            when NO_ACTIVATION  => return "0000";
            when RELU           => return "0001";
            when RELU6          => return "0010";
            when CRELU          => return "0011";
            when ELU            => return "0100";
            when SELU           => return "0101";
            when SOFTPLUS       => return "0110";
            when SOFTSIGN       => return "0111";
            when DROPOUT        => return "1000";
            when SIGMOID        => return "1001";
            when TANH           => return "1010";
        end case;
    end function ACTIVATION_TO_BITS;
    
    function BITS_TO_BYTE_ARRAY(BITVECTOR : std_logic_vector) return BYTE_ARRAY_TYPE is
        variable BYTE_ARRAY : BYTE_ARRAY_TYPE(0 to ((BITVECTOR'LENGTH / BYTE_WIDTH)-1));
    begin
        for i in BYTE_ARRAY'RANGE loop
                BYTE_ARRAY(i) := BITVECTOR(i*BYTE_WIDTH + BYTE_WIDTH-1 downto i*BYTE_WIDTH);
        end loop;
        
        return BYTE_ARRAY;
    end function BITS_TO_BYTE_ARRAY;
    
    function BYTE_ARRAY_TO_BITS(BYTE_ARRAY : BYTE_ARRAY_TYPE) return std_logic_vector is
        variable BITVECTOR : std_logic_vector(((BYTE_ARRAY'LENGTH * BYTE_WIDTH)-1) downto 0);
    begin
        for i in BYTE_ARRAY'RANGE loop
            BITVECTOR(i*BYTE_WIDTH + BYTE_WIDTH-1 downto i*BYTE_WIDTH) := BYTE_ARRAY(i);
        end loop;
        
        return BITVECTOR;
    end function BYTE_ARRAY_TO_BITS;
    
    function BITS_TO_WORD_ARRAY(BITVECTOR : std_logic_vector) return WORD_ARRAY_TYPE is
        variable WORD_ARRAY : WORD_ARRAY_TYPE(0 to ((BITVECTOR'LENGTH / (4*BYTE_WIDTH))-1));
    begin
        for i in WORD_ARRAY'RANGE loop
                WORD_ARRAY(i) := BITVECTOR(i*4*BYTE_WIDTH + 4*BYTE_WIDTH-1 downto i*4*BYTE_WIDTH);
        end loop;
        
        return WORD_ARRAY;
    end function BITS_TO_WORD_ARRAY;
    
    function WORD_ARRAY_TO_BITS(WORD_ARRAY : WORD_ARRAY_TYPE) return std_logic_vector is
        variable BITVECTOR : std_logic_vector(((WORD_ARRAY'LENGTH * 4*BYTE_WIDTH)-1) downto 0);
    begin
        for i in WORD_ARRAY'RANGE loop
            BITVECTOR(i*4*BYTE_WIDTH + 4*BYTE_WIDTH-1 downto i*4*BYTE_WIDTH) := WORD_ARRAY(i);
        end loop;
        
        return BITVECTOR;
    end function WORD_ARRAY_TO_BITS;
    
    function TO_WEIGHT_INSTRUCTION(INSTRUCTION : INSTRUCTION_TYPE) return WEIGHT_INSTRUCTION_TYPE is
        variable WEIGHT_INSTRUCTION : WEIGHT_INSTRUCTION_TYPE;
    begin
        WEIGHT_INSTRUCTION.OP_CODE := INSTRUCTION.OP_CODE;
        WEIGHT_INSTRUCTION.CALC_LENGTH := INSTRUCTION.CALC_LENGTH;
        WEIGHT_INSTRUCTION.WEIGHT_ADDRESS := INSTRUCTION.BUFFER_ADDRESS & INSTRUCTION.ACC_ADDRESS;
        
        return WEIGHT_INSTRUCTION;
    end function TO_WEIGHT_INSTRUCTION;
    
    function INSTRUCTION_TO_BITS(INSTRUCTION : INSTRUCTION_TYPE) return std_logic_vector is
        variable BITVECTOR : std_logic_vector(10*BYTE_WIDTH-1 downto 0);
    begin
        BITVECTOR(OP_CODE_WIDTH-1 downto 0) := INSTRUCTION.OP_CODE;
        BITVECTOR(LENGTH_WIDTH+OP_CODE_WIDTH-1 downto OP_CODE_WIDTH) := INSTRUCTION.CALC_LENGTH;
        BITVECTOR(ACCUMULATOR_ADDRESS_WIDTH+LENGTH_WIDTH+OP_CODE_WIDTH-1 downto LENGTH_WIDTH+OP_CODE_WIDTH) := INSTRUCTION.ACC_ADDRESS;
        BITVECTOR(BUFFER_ADDRESS_WIDTH+ACCUMULATOR_ADDRESS_WIDTH+LENGTH_WIDTH+OP_CODE_WIDTH-1 downto ACCUMULATOR_ADDRESS_WIDTH+LENGTH_WIDTH+OP_CODE_WIDTH) := INSTRUCTION.BUFFER_ADDRESS;
        
        return BITVECTOR;
    end function INSTRUCTION_TO_BITS;
    
    function BITS_TO_INSTRUCTION(BITVECTOR : std_logic_vector(10*BYTE_WIDTH-1 downto 0)) return INSTRUCTION_TYPE is
        variable INSTRUCTION : INSTRUCTION_TYPE;
    begin
        INSTRUCTION.OP_CODE         := BITVECTOR(OP_CODE_WIDTH-1 downto 0);
        INSTRUCTION.CALC_LENGTH     := BITVECTOR(LENGTH_WIDTH+OP_CODE_WIDTH-1 downto OP_CODE_WIDTH);
        INSTRUCTION.ACC_ADDRESS     := BITVECTOR(ACCUMULATOR_ADDRESS_WIDTH+LENGTH_WIDTH+OP_CODE_WIDTH-1 downto LENGTH_WIDTH+OP_CODE_WIDTH);
        INSTRUCTION.BUFFER_ADDRESS  := BITVECTOR(BUFFER_ADDRESS_WIDTH+ACCUMULATOR_ADDRESS_WIDTH+LENGTH_WIDTH+OP_CODE_WIDTH-1 downto ACCUMULATOR_ADDRESS_WIDTH+LENGTH_WIDTH+OP_CODE_WIDTH);
        
        return INSTRUCTION;
    end function BITS_TO_INSTRUCTION;
    
    function INIT_INSTRUCTION return INSTRUCTION_TYPE is
    begin
        return (
            OP_CODE         => (others => '0'),
            CALC_LENGTH     => (others => '0'),
            ACC_ADDRESS     => (others => '0'),
            BUFFER_ADDRESS  => (others => '0')
        );
    end function INIT_INSTRUCTION;
end package body;
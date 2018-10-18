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

--! @file INSTRUCTION_FIFO.vhdl
--! @author Jonas Fuhrmann
--! @brief This component includes a simple FIFO for the instruction type.
--! @details Instructions are splitted into 32 Bit words, except for the last word, which is 16 Bit.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    use IEEE.math_real.log2;
    use IEEE.math_real.ceil;

entity INSTRUCTION_FIFO is
    generic(
        FIFO_DEPTH  : natural := 32
    );
    port(
        CLK, RESET  : in  std_logic;
        LOWER_WORD  : in  WORD_TYPE; --!< The lower word of the instruction.
        MIDDLE_WORD : in  WORD_TYPE; --!< The middle word of the instruction.
        UPPER_WORD  : in  HALFWORD_TYPE; --!< The upper halfword (16 Bit) of the instruction.
        WRITE_EN    : in  std_logic_vector(0 to 2); --!< Write enable flags for each word.
        
        OUTPUT      : out INSTRUCTION_TYPE; --!< Read port of the FIFO.
        NEXT_EN     : in  std_logic; --!< Read or 'next' enable of the FIFO (clears current value).
        
        EMPTY       : out std_logic; --!< Determines if the FIFO is empty.
        FULL        : out std_logic --!< Determines if the FIFO is full.
    );
end entity INSTRUCTION_FIFO;

--! @brief The architecture of the instruction FIFO component.
architecture BEH of INSTRUCTION_FIFO is
    component FIFO is
        generic(
            FIFO_WIDTH  : natural := 8;
            FIFO_DEPTH  : natural := 32
        );
        port(
            CLK, RESET  : in  std_logic;
            INPUT       : in  std_logic_vector(FIFO_WIDTH-1 downto 0);
            WRITE_EN    : in  std_logic;
            
            OUTPUT      : out std_logic_vector(FIFO_WIDTH-1 downto 0);
            NEXT_EN     : in  std_logic;
            
            EMPTY       : out std_logic;
            FULL        : out std_logic
        );
    end component FIFO;
    for all : FIFO use entity WORK.FIFO(DIST_RAM_FIFO);
    
    signal EMPTY_VECTOR : std_logic_vector(0 to 2);
    signal FULL_VECTOR  : std_logic_vector(0 to 2);
    
    signal LOWER_OUTPUT : WORD_TYPE;
    signal MIDDLE_OUTPUT: WORD_TYPE;
    signal UPPER_OUTPUT : HALFWORD_TYPE;
begin
    
    EMPTY   <= EMPTY_VECTOR(0) or EMPTY_VECTOR(1) or EMPTY_VECTOR(2);
    FULL    <= FULL_VECTOR(0)  or FULL_VECTOR(1)  or FULL_VECTOR(2);
    
    OUTPUT  <= BITS_TO_INSTRUCTION(UPPER_OUTPUT & MIDDLE_OUTPUT & LOWER_OUTPUT);

    FIFO_0 : FIFO
    generic map(
        FIFO_WIDTH  => 4*BYTE_WIDTH,
        FIFO_DEPTH  => FIFO_DEPTH
    )
    port map(
        CLK         => CLK,
        RESET       => RESET,
        INPUT       => LOWER_WORD,
        WRITE_EN    => WRITE_EN(0),
        OUTPUT      => LOWER_OUTPUT,
        NEXT_EN     => NEXT_EN,
        EMPTY       => EMPTY_VECTOR(0),
        FULL        => FULL_VECTOR(0)
    );
    
    FIFO_1 : FIFO
    generic map(
        FIFO_WIDTH  => 4*BYTE_WIDTH,
        FIFO_DEPTH  => FIFO_DEPTH
    )
    port map(
        CLK         => CLK,
        RESET       => RESET,
        INPUT       => MIDDLE_WORD,
        WRITE_EN    => WRITE_EN(1),
        OUTPUT      => MIDDLE_OUTPUT,
        NEXT_EN     => NEXT_EN,
        EMPTY       => EMPTY_VECTOR(1),
        FULL        => FULL_VECTOR(1)
    );
    
    FIFO_2 : FIFO
    generic map(
        FIFO_WIDTH  => 2*BYTE_WIDTH,
        FIFO_DEPTH  => FIFO_DEPTH
    )
    port map(
        CLK         => CLK,
        RESET       => RESET,
        INPUT       => UPPER_WORD,
        WRITE_EN    => WRITE_EN(2),
        OUTPUT      => UPPER_OUTPUT,
        NEXT_EN     => NEXT_EN,
        EMPTY       => EMPTY_VECTOR(2),
        FULL        => FULL_VECTOR(2)
    );
end architecture BEH;
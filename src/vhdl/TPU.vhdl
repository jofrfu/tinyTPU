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

--! @file TPU.vhdl
--! @author Jonas Fuhrmann
--! @brief This component includes the complete Tensor Processing Unit.
--! @details The TPU uses the TPU core and the instruction FIFO.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    
entity TPU is
    generic(
        MATRIX_WIDTH            : natural := 14; --!< The width of the Matrix Multiply Unit and busses.
        WEIGHT_BUFFER_DEPTH     : natural := 32768; --!< The depth of the weight buffer.
        UNIFIED_BUFFER_DEPTH    : natural := 4096 --!< The depth of the unified buffer.
    );  
    port(   
        CLK, RESET              : in  std_logic;
        ENABLE                  : in  std_logic;
        -- For calculation runtime check
        RUNTIME_COUNT           : out WORD_TYPE; --!< Counts the runtime from the first instruction enable until the synchronize signal.
        -- Splitted instruction input
        LOWER_INSTRUCTION_WORD  : in  WORD_TYPE; --!< The lower word of the instruction.
        MIDDLE_INSTRUCTION_WORD : in  WORD_TYPE; --!< The middle word of the instruction.
        UPPER_INSTRUCTION_WORD  : in  HALFWORD_TYPE; --!< The upper halfword (16 Bit) of the instruction.
        INSTRUCTION_WRITE_EN    : in  std_logic_vector(0 to 2); --!< Write enable flags for each word.
        -- Instruction buffer flags for interrupts
        INSTRUCTION_EMPTY       : out std_logic; --!< Determines if the FIFO is empty. Used to interrupt the host system.
        INSTRUCTION_FULL        : out std_logic; --!< Determines if the FIFO is full. Used to interrupt the host system.
    
        WEIGHT_WRITE_PORT       : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Host write port for the weight buffer
        WEIGHT_ADDRESS          : in  WEIGHT_ADDRESS_TYPE; --!< Host address for the weight buffer.
        WEIGHT_ENABLE           : in  std_logic; --!< Host enable for the weight buffer.
        WEIGHT_WRITE_ENABLE     : in  std_logic_vector(0 to MATRIX_WIDTH-1); --!< Host write enable for the weight buffer.
            
        BUFFER_WRITE_PORT       : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Host write port for the unified buffer.
        BUFFER_READ_PORT        : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Host read port for the unified buffer.
        BUFFER_ADDRESS          : in  BUFFER_ADDRESS_TYPE; --!< Host address for the unified buffer.
        BUFFER_ENABLE           : in  std_logic; --!< Host enable for the unified buffer.
        BUFFER_WRITE_ENABLE     : in  std_logic_vector(0 to MATRIX_WIDTH-1); --!< Host write enable for the unified buffer.
        -- Memory synchronization flag for interrupt 
        SYNCHRONIZE             : out std_logic --!< Synchronization interrupt.
    );
end entity TPU;

--! @brief The architecture of the TPU.
architecture BEH of TPU is
    component RUNTIME_COUNTER is
        port(
            CLK, RESET      :  in std_logic;
            
            INSTRUCTION_EN  :  in std_logic;
            SYNCHRONIZE     :  in std_logic;
            COUNTER_VAL     : out WORD_TYPE
        );
    end component RUNTIME_COUNTER;
    for all : RUNTIME_COUNTER use entity WORK.RUNTIME_COUNTER(BEH);

    component INSTRUCTION_FIFO is
        generic(
            FIFO_DEPTH  : natural := 32
        );
        port(
            CLK, RESET  : in  std_logic;
            LOWER_WORD  : in  WORD_TYPE;
            MIDDLE_WORD : in  WORD_TYPE;
            UPPER_WORD  : in  HALFWORD_TYPE;
            WRITE_EN    : in  std_logic_vector(0 to 2);
            
            OUTPUT      : out INSTRUCTION_TYPE;
            NEXT_EN     : in  std_logic;
            
            EMPTY       : out std_logic;
            FULL        : out std_logic
        );
    end component INSTRUCTION_FIFO;
    for all : INSTRUCTION_FIFO use entity WORK.INSTRUCTION_FIFO(BEH);
    
    signal INSTRUCTION      : INSTRUCTION_TYPE;
    signal EMPTY            : std_logic;
    signal FULL             : std_logic;
    
    component TPU_CORE is
        generic(
            MATRIX_WIDTH            : natural := 14;
            WEIGHT_BUFFER_DEPTH     : natural := 32768;
            UNIFIED_BUFFER_DEPTH    : natural := 4096
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
    end component TPU_CORE;
    for all : TPU_CORE use entity WORK.TPU_CORE(BEH);
    
    signal INSTRUCTION_ENABLE   : std_logic;
    signal BUSY                 : std_logic;
    signal SYNCHRONIZE_IN       : std_logic;
begin
    RUNTIME_COUNTER_i : RUNTIME_COUNTER
    port map(
        CLK             => CLK,
        RESET           => RESET,
        INSTRUCTION_EN  => INSTRUCTION_ENABLE,
        SYNCHRONIZE     => SYNCHRONIZE_IN,
        COUNTER_VAL     => RUNTIME_COUNT
    );

    INSTRUCTION_FIFO_i : INSTRUCTION_FIFO
    port map(
        CLK         => CLK,
        RESET       => RESET,
        LOWER_WORD  => LOWER_INSTRUCTION_WORD,
        MIDDLE_WORD => MIDDLE_INSTRUCTION_WORD,
        UPPER_WORD  => UPPER_INSTRUCTION_WORD,
        WRITE_EN    => INSTRUCTION_WRITE_EN,
        OUTPUT      => INSTRUCTION,
        NEXT_EN     => INSTRUCTION_ENABLE,
        EMPTY       => EMPTY,
        FULL        => FULL
    );
    
    INSTRUCTION_EMPTY <= EMPTY;
    INSTRUCTION_FULL  <= FULL;
    
    TPU_CORE_i : TPU_CORE
    generic map(
        MATRIX_WIDTH            => MATRIX_WIDTH,
        WEIGHT_BUFFER_DEPTH     => WEIGHT_BUFFER_DEPTH,
        UNIFIED_BUFFER_DEPTH    => UNIFIED_BUFFER_DEPTH
    )
    port map(
        CLK                 => CLK,
        RESET               => RESET,
        ENABLE              => ENABLE,            
    
        WEIGHT_WRITE_PORT   => WEIGHT_WRITE_PORT,
        WEIGHT_ADDRESS      => WEIGHT_ADDRESS,
        WEIGHT_ENABLE       => WEIGHT_ENABLE, 
        WEIGHT_WRITE_ENABLE => WEIGHT_WRITE_ENABLE,
        
        BUFFER_WRITE_PORT   => BUFFER_WRITE_PORT,
        BUFFER_READ_PORT    => BUFFER_READ_PORT,
        BUFFER_ADDRESS      => BUFFER_ADDRESS,
        BUFFER_ENABLE       => BUFFER_ENABLE,
        BUFFER_WRITE_ENABLE => BUFFER_WRITE_ENABLE,
        
        INSTRUCTION_PORT    => INSTRUCTION,
        INSTRUCTION_ENABLE  => INSTRUCTION_ENABLE,
        
        BUSY                => BUSY,
        SYNCHRONIZE         => SYNCHRONIZE_IN
    );
    
    SYNCHRONIZE <= SYNCHRONIZE_IN;
    
    INSTRUCTION_FEED:
    process(EMPTY, BUSY) is
    begin
        if BUSY = '0' and EMPTY = '0' then
            INSTRUCTION_ENABLE <= '1';
        else
            INSTRUCTION_ENABLE <= '0';
        end if;
    end process INSTRUCTION_FEED;
end architecture BEH;
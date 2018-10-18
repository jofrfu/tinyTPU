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

--! @file MATRIX_MULTIPLY_UNIT.vhdl
--! @author Jonas Fuhrmann
--! @brief This is the matrix multiply unit. It has inputs to load weights to it's MACC components and inputs for the matrix multiply operation.
--! @details The matrix multiply unit is a systolic array consisting of identical MACC components. The MACCs are layed to an 2 dimensional grid.
--! The input has to be feeded diagonally, because of the delays caused by the MACC registers. The partial sums are 'flowing down' the array and the input has to be delayed.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    
entity MATRIX_MULTIPLY_UNIT is
    generic(
        MATRIX_WIDTH    : natural := 14
    );
    port(
        CLK, RESET      : in  std_logic;
        ENABLE          : in  std_logic;
        
        WEIGHT_DATA     : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Input for the weights, connected to the MACC's weight input.
        WEIGHT_SIGNED   : in  std_logic; --!< Determines if the weight input is signed or unsigned.
        SYSTOLIC_DATA   : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< The diagonally feeded input data.
        SYSTOLIC_SIGNED : in  std_logic; --!< Determines if the systolic input is signed or unsigned.
        
        ACTIVATE_WEIGHT : in  std_logic; --!< Activates the loaded weights sequentially.
        LOAD_WEIGHT     : in  std_logic; --!< Preloads one column of weights with WEIGHT_DATA.
        WEIGHT_ADDRESS  : in  BYTE_TYPE; --!< Addresses up to 256 columns of preweights.
        
        RESULT_DATA     : out WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1) --!< The result of the matrix multiply.
    );
end entity MATRIX_MULTIPLY_UNIT;

--! @brief Architecture of the matrix multiply unit.
architecture BEH of MATRIX_MULTIPLY_UNIT is
    component MACC is
        generic(
            -- The width of the last sum input
            LAST_SUM_WIDTH      : natural   := 0;
            -- The width of the output register
            PARTIAL_SUM_WIDTH   : natural   := 2*EXTENDED_BYTE_WIDTH
        );
        port(
            CLK, RESET      : in std_logic;
            ENABLE          : in std_logic;
            -- Weights - current and preload
            WEIGHT_INPUT    : in EXTENDED_BYTE_TYPE;
            PRELOAD_WEIGHT  : in std_logic;
            LOAD_WEIGHT     : in std_logic;
            -- Input
            INPUT           : in EXTENDED_BYTE_TYPE;
            LAST_SUM        : in std_logic_vector(LAST_SUM_WIDTH-1 downto 0);
            -- Output
            PARTIAL_SUM     : out std_logic_vector(PARTIAL_SUM_WIDTH-1 downto 0)
        );
    end component MACC;
    for all : MACC use entity WORK.MACC(BEH);

    signal INTERIM_RESULT   : WORD_ARRAY_2D_TYPE(0 to MATRIX_WIDTH-1, 0 to MATRIX_WIDTH-1) := (others => (others => (others => '0')));
    
    -- For address conversion
    signal LOAD_WEIGHT_MAP  : std_logic_vector(0 to MATRIX_WIDTH-1);
    
    signal ACTIVATE_CONTROL_cs  : std_logic_vector(0 to MATRIX_WIDTH-1-1) := (others => '0');
    signal ACTIVATE_CONTROL_ns  : std_logic_vector(0 to MATRIX_WIDTH-1-1);
    
    signal ACTIVATE_MAP         : std_logic_vector(0 to MATRIX_WIDTH-1);
    
    -- For sign extension
    signal EXTENDED_WEIGHT_DATA     : EXTENDED_BYTE_ARRAY(0 to MATRIX_WIDTH-1);
    signal EXTENDED_SYSTOLIC_DATA   : EXTENDED_BYTE_ARRAY(0 to MATRIX_WIDTH-1);
    
    -- For result sign extension
    signal SIGN_CONTROL_cs  : std_logic_vector(0 to 2+MATRIX_WIDTH-1) := (others => '0'); -- Register delay of 2 caused by MACC
    signal SIGN_CONTROL_ns  : std_logic_vector(0 to 2+MATRIX_WIDTH-1);
begin
    
    -- Linear shift register
    ACTIVATE_CONTROL_ns(1 to MATRIX_WIDTH-1-1) <= ACTIVATE_CONTROL_cs(0 to MATRIX_WIDTH-2-1);
    ACTIVATE_CONTROL_ns(0) <= ACTIVATE_WEIGHT;
    
    SIGN_CONTROL_ns(1 to 2+MATRIX_WIDTH-1) <= SIGN_CONTROL_cs(0 to 2+MATRIX_WIDTH-2);
    SIGN_CONTROL_ns(0) <= SYSTOLIC_SIGNED;
    
    ACTIVATE_MAP <= ACTIVATE_CONTROL_ns(0) & ACTIVATE_CONTROL_cs;
    
    LOAD:   -- Address conversion
    process(LOAD_WEIGHT, WEIGHT_ADDRESS) is
        variable LOAD_WEIGHT_v       : std_logic;
        variable WEIGHT_ADDRESS_v    : BYTE_TYPE;
        
        variable LOAD_WEIGHT_MAP_v   : std_logic_vector(0 to MATRIX_WIDTH-1);
    begin
        LOAD_WEIGHT_v       := LOAD_WEIGHT;
        WEIGHT_ADDRESS_v    := WEIGHT_ADDRESS;
        
        LOAD_WEIGHT_MAP_v := (others => '0');
        if LOAD_WEIGHT_v = '1' then
            LOAD_WEIGHT_MAP_v(to_integer(unsigned(WEIGHT_ADDRESS_v))) := '1';
        end if;
        
        LOAD_WEIGHT_MAP <= LOAD_WEIGHT_MAP_v;
    end process LOAD;
    
    SIGN_EXTEND:
    process(WEIGHT_DATA, SYSTOLIC_DATA, WEIGHT_SIGNED, SIGN_CONTROL_ns) is
    begin
        for i in 0 to MATRIX_WIDTH-1 loop
            if WEIGHT_SIGNED = '1' then
                EXTENDED_WEIGHT_DATA(i) <= WEIGHT_DATA(i)(BYTE_WIDTH-1) & WEIGHT_DATA(i);
            else
                EXTENDED_WEIGHT_DATA(i) <= '0' & WEIGHT_DATA(i);
            end if;
            
            if SIGN_CONTROL_ns(i) = '1' then
                EXTENDED_SYSTOLIC_DATA(i) <= SYSTOLIC_DATA(i)(BYTE_WIDTH-1) & SYSTOLIC_DATA(i);
            else
                EXTENDED_SYSTOLIC_DATA(i) <= '0' & SYSTOLIC_DATA(i);
            end if;
        end loop;
    end process SIGN_EXTEND;

    MACC_GEN:
    for i in 0 to MATRIX_WIDTH-1 generate
        MACC_2D:
        for j in 0 to MATRIX_WIDTH-1 generate
            UPPER_LEFT_ELEMENT:
            if i = 0 and j = 0 generate
                MACC_i0 : MACC
                generic map(
                    LAST_SUM_WIDTH      => 0,
                    PARTIAL_SUM_WIDTH   => 2*EXTENDED_BYTE_WIDTH
                )
                port map(
                    CLK             => CLK,
                    RESET           => RESET,
                    ENABLE          => ENABLE,
                    WEIGHT_INPUT    => EXTENDED_WEIGHT_DATA(j),
                    PRELOAD_WEIGHT  => LOAD_WEIGHT_MAP(i),
                    LOAD_WEIGHT     => ACTIVATE_MAP(i),
                    INPUT           => EXTENDED_SYSTOLIC_DATA(i),
                    LAST_SUM        => (others => '0'),
                    PARTIAL_SUM     => INTERIM_RESULT(i, j)(2*EXTENDED_BYTE_WIDTH-1 downto 0)
                );
            end generate UPPER_LEFT_ELEMENT;
            
            FIRST_COLUMN:
            if i = 0 and j > 0 generate
                MACC_i1 : MACC
                generic map(
                    LAST_SUM_WIDTH      => 0,
                    PARTIAL_SUM_WIDTH   => 2*EXTENDED_BYTE_WIDTH
                )
                port map(
                    CLK             => CLK,
                    RESET           => RESET,
                    ENABLE          => ENABLE,
                    WEIGHT_INPUT    => EXTENDED_WEIGHT_DATA(j),
                    PRELOAD_WEIGHT  => LOAD_WEIGHT_MAP(i),
                    LOAD_WEIGHT     => ACTIVATE_MAP(i),
                    INPUT           => EXTENDED_SYSTOLIC_DATA(i),
                    LAST_SUM        => (others => '0'),
                    PARTIAL_SUM     => INTERIM_RESULT(i, j)(2*EXTENDED_BYTE_WIDTH-1 downto 0)
                );
            end generate FIRST_COLUMN;
            
            LEFT_FULL_ELEMENTS:
            if i > 0 and i <= 2*(BYTE_WIDTH-1) and j = 0 generate
                MACC_i2 : MACC
                generic map(
                    LAST_SUM_WIDTH      => 2*EXTENDED_BYTE_WIDTH + i-1,
                    PARTIAL_SUM_WIDTH   => 2*EXTENDED_BYTE_WIDTH + i
                )
                port map(
                    CLK             => CLK,
                    RESET           => RESET,
                    ENABLE          => ENABLE,
                    WEIGHT_INPUT    => EXTENDED_WEIGHT_DATA(j),
                    PRELOAD_WEIGHT  => LOAD_WEIGHT_MAP(i),
                    LOAD_WEIGHT     => ACTIVATE_MAP(i),
                    INPUT           => EXTENDED_SYSTOLIC_DATA(i),
                    LAST_SUM        => INTERIM_RESULT(i-1, j)(2*EXTENDED_BYTE_WIDTH + i-2 downto 0),
                    PARTIAL_SUM     => INTERIM_RESULT(i, j)(2*EXTENDED_BYTE_WIDTH + i-1 downto 0)
                );
            end generate LEFT_FULL_ELEMENTS;
            
            FULL_COLUMNS:
            if i > 0 and i <= 2*(BYTE_WIDTH-1) and j > 0 generate
                MACC_i3 : MACC
                generic map(
                    LAST_SUM_WIDTH      => 2*EXTENDED_BYTE_WIDTH + i-1,
                    PARTIAL_SUM_WIDTH   => 2*EXTENDED_BYTE_WIDTH + i
                )
                port map(
                    CLK             => CLK,
                    RESET           => RESET,
                    ENABLE          => ENABLE,
                    WEIGHT_INPUT    => EXTENDED_WEIGHT_DATA(j),
                    PRELOAD_WEIGHT  => LOAD_WEIGHT_MAP(i),
                    LOAD_WEIGHT     => ACTIVATE_MAP(i),
                    INPUT           => EXTENDED_SYSTOLIC_DATA(i),
                    LAST_SUM        => INTERIM_RESULT(i-1, j)(2*EXTENDED_BYTE_WIDTH + i-2 downto 0),
                    PARTIAL_SUM     => INTERIM_RESULT(i, j)(2*EXTENDED_BYTE_WIDTH + i-1 downto 0)
                );
            end generate FULL_COLUMNS;
            
            LEFT_CUTTED_ELEMENT:
            if i > 2*BYTE_WIDTH and j = 0 generate
                MACC_i4 : MACC
                generic map(
                    LAST_SUM_WIDTH      => 4*BYTE_WIDTH,
                    PARTIAL_SUM_WIDTH   => 4*BYTE_WIDTH
                )
                port map(
                    CLK             => CLK,
                    RESET           => RESET,
                    ENABLE          => ENABLE,
                    WEIGHT_INPUT    => EXTENDED_WEIGHT_DATA(j),
                    PRELOAD_WEIGHT  => LOAD_WEIGHT_MAP(i),
                    LOAD_WEIGHT     => ACTIVATE_MAP(i),
                    INPUT           => EXTENDED_SYSTOLIC_DATA(i),
                    LAST_SUM        => INTERIM_RESULT(i-1, j),
                    PARTIAL_SUM     => INTERIM_RESULT(i, j)
                );
            end generate LEFT_CUTTED_ELEMENT;
            
            CUTTED_COLUMNS:
            if i > 2*BYTE_WIDTH and j > 0 generate
                MACC_i5 : MACC
                generic map(
                    LAST_SUM_WIDTH      => 4*BYTE_WIDTH,
                    PARTIAL_SUM_WIDTH   => 4*BYTE_WIDTH
                )
                port map(
                    CLK             => CLK,
                    RESET           => RESET,
                    ENABLE          => ENABLE,
                    WEIGHT_INPUT    => EXTENDED_WEIGHT_DATA(j),
                    PRELOAD_WEIGHT  => LOAD_WEIGHT_MAP(i),
                    LOAD_WEIGHT     => ACTIVATE_MAP(i),
                    INPUT           => EXTENDED_SYSTOLIC_DATA(i),
                    LAST_SUM        => INTERIM_RESULT(i-1, j),
                    PARTIAL_SUM     => INTERIM_RESULT(i, j)
                );
            end generate CUTTED_COLUMNS;
        end generate MACC_2D;
    end generate MACC_GEN;
    
    RESULT_ASSIGNMENT:
    process(INTERIM_RESULT, SIGN_CONTROL_cs(2+MATRIX_WIDTH-1)) is
        variable RESULT_DATA_v  : std_logic_vector(2*EXTENDED_BYTE_WIDTH+MATRIX_WIDTH-2 downto 0);
        variable EXTEND_v       : std_logic_vector(4*BYTE_WIDTH-1 downto 2*EXTENDED_BYTE_WIDTH+MATRIX_WIDTH-1);
    begin
        for i in MATRIX_WIDTH-1 downto 0 loop
            RESULT_DATA_v := INTERIM_RESULT(MATRIX_WIDTH-1, i)(2*EXTENDED_BYTE_WIDTH+MATRIX_WIDTH-2 downto 0);
            if SIGN_CONTROL_cs(2+MATRIX_WIDTH-1) = '1' then
                EXTEND_v := (others => INTERIM_RESULT(MATRIX_WIDTH-1, i)(2*EXTENDED_BYTE_WIDTH+MATRIX_WIDTH-2));
            else
                EXTEND_v := (others => '0');
            end if;
            
            RESULT_DATA(i) <= EXTEND_v & RESULT_DATA_v;
        end loop;
    end process RESULT_ASSIGNMENT;
    
    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                ACTIVATE_CONTROL_cs <= (others => '0');
                SIGN_CONTROL_cs     <= (others => '0');
            else
                ACTIVATE_CONTROL_cs <= ACTIVATE_CONTROL_ns;
                SIGN_CONTROL_cs     <= SIGN_CONTROL_ns;
            end if;
        end if;
    end process SEQ_LOG;
end architecture BEH;
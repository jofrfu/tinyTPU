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

entity TB_MATRIX_MULTIPLY_UNIT is
end entity TB_MATRIX_MULTIPLY_UNIT;

architecture BEH of TB_MATRIX_MULTIPLY_UNIT is
    component DUT is
        generic(
        MATRIX_WIDTH    : natural := 14
        );
        port(
            CLK, RESET      : in  std_logic;
            ENABLE          : in  std_logic;
            
            WEIGHT_DATA     : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            WEIGHT_SIGNED   : in  std_logic;
            SYSTOLIC_DATA   : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            SYSTOLIC_SIGNED : in  std_logic;
            
            ACTIVATE_WEIGHT : in  std_logic; -- Activates the loaded weights sequentially
            LOAD_WEIGHT     : in  std_logic; -- Preloads one column of weights with WEIGHT_DATA
            WEIGHT_ADDRESS  : in  BYTE_TYPE; -- Addresses up to 256 columns of preweights
            
            RESULT_DATA     : out WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1)
        );
    end component DUT;
    for all : DUT use entity WORK.MATRIX_MULTIPLY_UNIT(BEH);
    
    constant MATRIX_WIDTH   : natural := 4;
    
    signal CLK, RESET       : std_logic;
    signal ENABLE           : std_logic;
    
    signal WEIGHT_DATA      : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal WEIGHT_SIGNED    : std_logic;
    signal SYSTOLIC_DATA    : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal SYSTOLIC_SIGNED  : std_logic;
    
    signal ACTIVATE_WEIGHT  : std_logic;
    signal LOAD_WEIGHT      : std_logic;
    signal WEIGHT_ADDRESS   : BYTE_TYPE;
    
    signal RESULT_DATA      : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean := false;
    
    signal START            : boolean;
    signal EVALUATE         : boolean;
    
    -- Unsigned
    -- Tested input data
    constant INPUT_MATRIX   : INTEGER_ARRAY_2D_TYPE :=
        (
            ( 40,  76,  19, 192),
            (  3,  84,  12,   8),
            ( 54,  18, 255, 120),
            ( 30,  84, 122,   2)
        );
    
    -- Tested weight data
    constant WEIGHT_MATRIX  : INTEGER_ARRAY_2D_TYPE :=
        (
            ( 13,  89, 178,   9),
            ( 84, 184, 245,  18),
            (255,  73,  14,   3),
            ( 98, 212,  78,  29)
        );
    
    -- Result of matrix multiply
    constant RESULT_MATRIX  : INTEGER_ARRAY_2D_TYPE :=
        (
            (30565, 59635, 40982, 7353),
            (10939, 18295, 21906, 1807),
            (78999, 52173, 26952, 5055),
            (38752, 27456, 27784, 2206)
        );
        
        
    -- Signed
    -- Tested input data
    constant INPUT_MATRIX_SIGNED    : INTEGER_ARRAY_2D_TYPE :=
        (
            ( 74,  91,  64,  10),
            (  5,  28,  26,   9),
            ( 56,   9,  72, 127),
            ( 94,  26,  92,   8)
        );
    
    -- Tested weight data
    constant WEIGHT_MATRIX_SIGNED   : INTEGER_ARRAY_2D_TYPE :=
        (
            (- 13,  89,  92,   9),
            (- 84, 104,  86,  18),
            (-128,  73,  14,   3),
            (- 98, 127,  78,  29)
        );
    
    -- Result of matrix multiply
    constant RESULT_MATRIX_SIGNED   : INTEGER_ARRAY_2D_TYPE :=
        (
            (-17778, 21992, 16310, 2786),
            (- 6627,  6398,  3934,  888),
            (-23146, 27305, 16840, 4565),
            (-15966, 18802, 12796, 1822)
        );
        
    signal CURRENT_INPUT    : INTEGER_ARRAY_2D_TYPE(0 to MATRIX_WIDTH-1, 0 to MATRIX_WIDTH-1);
    signal CURRENT_RESULT   : INTEGER_ARRAY_2D_TYPE(0 to MATRIX_WIDTH-1, 0 to MATRIX_WIDTH-1);
    signal CURRENT_SIGN     : std_logic;
    
    signal QUIT_CLOCK0 : boolean;
    signal QUIT_CLOCK1 : boolean;
begin
    DUT_i : DUT
    generic map(
        MATRIX_WIDTH => MATRIX_WIDTH
    )
    port map(
        CLK             => CLK,
        RESET           => RESET,
        ENABLE          => ENABLE,
        WEIGHT_DATA     => WEIGHT_DATA,
        WEIGHT_SIGNED   => WEIGHT_SIGNED,
        SYSTOLIC_DATA   => SYSTOLIC_DATA,
        SYSTOLIC_SIGNED => SYSTOLIC_SIGNED,
        ACTIVATE_WEIGHT => ACTIVATE_WEIGHT,
        LOAD_WEIGHT     => LOAD_WEIGHT,
        WEIGHT_ADDRESS  => WEIGHT_ADDRESS,
        RESULT_DATA     => RESULT_DATA
    );
    
    STIMULUS:
    process is
        procedure LOAD_WEIGHTS(
            MATRIX : in INTEGER_ARRAY_2D_TYPE;
            SIGNED_NOT_UNSIGNED : in std_logic
        ) is
        begin
            START <= false;
            RESET <= '0';
            ENABLE <= '0';
            WEIGHT_DATA <= (others => (others => '0'));
            ACTIVATE_WEIGHT <= '0';
            LOAD_WEIGHT <= '0';
            WEIGHT_ADDRESS <= (others => '0');
            WEIGHT_SIGNED <= '0';
            wait until '1'=CLK and CLK'event;
            -- RESET
            RESET <= '1';
            wait until '1'=CLK and CLk'event;
            RESET <= '0';
            WEIGHT_SIGNED <= SIGNED_NOT_UNSIGNED;
            -- Load weight 0
            WEIGHT_ADDRESS <= std_logic_vector(to_unsigned(0, BYTE_WIDTH));
            for i in 0 to MATRIX_WIDTH-1 loop
                WEIGHT_DATA(i) <= std_logic_vector(to_signed(MATRIX(0, i), BYTE_WIDTH));
            end loop;
            LOAD_WEIGHT <= '1';
            wait until '1'=CLK and CLK'event;
            -- Load weight 1
            WEIGHT_ADDRESS <= std_logic_vector(to_unsigned(1, BYTE_WIDTH));
            for i in 0 to MATRIX_WIDTH-1 loop
                WEIGHT_DATA(i) <= std_logic_vector(to_signed(MATRIX(1, i), BYTE_WIDTH));
            end loop;
            LOAD_WEIGHT <= '1';
            wait until '1'=CLK and CLK'event;
            -- Load weight 2
            WEIGHT_ADDRESS <= std_logic_vector(to_unsigned(2, BYTE_WIDTH));
            for i in 0 to MATRIX_WIDTH-1 loop
                WEIGHT_DATA(i) <= std_logic_vector(to_signed(MATRIX(2, i), BYTE_WIDTH));
            end loop;
            LOAD_WEIGHT <= '1';
            wait until '1'=CLK and CLK'event;
            -- Load weight 3
            WEIGHT_ADDRESS <= std_logic_vector(to_unsigned(3, BYTE_WIDTH));
            for i in 0 to MATRIX_WIDTH-1 loop
                WEIGHT_DATA(i) <= std_logic_vector(to_signed(MATRIX(3, i), BYTE_WIDTH));
            end loop;
            LOAD_WEIGHT <= '1';
            wait until '1'=CLK and CLK'event;
            --
            LOAD_WEIGHT <= '0';
            WEIGHT_SIGNED <= '0';
            ACTIVATE_WEIGHT <= '1';
            ENABLE <= '1';
            --
            START <= true;
            wait until '1'=CLK and CLK'event;
            START <= false;
            ACTIVATE_WEIGHT <= '0';
            for i in 0 to 3*MATRIX_WIDTH-1 loop
                wait until '1'=CLK and CLK'event;
            end loop;
        end procedure LOAD_WEIGHTS;
    begin
        QUIT_CLOCK0 <= false;
        CURRENT_SIGN <= '0';
        CURRENT_INPUT <= INPUT_MATRIX;
        CURRENT_RESULT <= RESULT_MATRIX;
        LOAD_WEIGHTS(WEIGHT_MATRIX, '0');
        CURRENT_SIGN <= '1';
        CURRENT_INPUT <= INPUT_MATRIX_SIGNED;
        CURRENT_RESULT <= RESULT_MATRIX_SIGNED;
        LOAD_WEIGHTS(WEIGHT_MATRIX_SIGNED, '1');
        QUIT_CLOCK0 <= true;
        wait;
    end process STIMULUS;
    
    PROCESS_INPUT0:
    process is
    begin
        EVALUATE <= false;
        wait until START = true;
        for i in 0 to MATRIX_WIDTH-1 loop
            SYSTOLIC_DATA(0) <= std_logic_vector(to_signed(CURRENT_INPUT(i, 0), BYTE_WIDTH));
            wait until '1'=CLK and CLK'event;
        end loop;
        SYSTOLIC_DATA(0) <= (others => '0');
        EVALUATE <= true;
        wait until '1'=CLK and CLK'event;
        EVALUATE <= false;
    end process;
    
    PROCESS_INPUT1:
    process is
    begin
        wait until START = true;
        wait until '1'=CLK and CLK'event;
        for i in 0 to MATRIX_WIDTH-1 loop
            SYSTOLIC_DATA(1) <= std_logic_vector(to_signed(CURRENT_INPUT(i, 1), BYTE_WIDTH));
            wait until '1'=CLK and CLK'event;
        end loop;
        SYSTOLIC_DATA(1) <= (others => '0');
    end process;
    
    PROCESS_INPUT2:
    process is
    begin
        wait until START = true;
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        for i in 0 to MATRIX_WIDTH-1 loop
            SYSTOLIC_DATA(2) <= std_logic_vector(to_signed(CURRENT_INPUT(i, 2), BYTE_WIDTH));
            wait until '1'=CLK and CLK'event;
        end loop;
        SYSTOLIC_DATA(2) <= (others => '0');
    end process;
    
    PROCESS_INPUT3:
    process is
    begin
        SYSTOLIC_SIGNED <= '0';
        wait until START = true;
        SYSTOLIC_SIGNED <= CURRENT_SIGN;
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        for i in 0 to MATRIX_WIDTH-1 loop
            SYSTOLIC_DATA(3) <= std_logic_vector(to_signed(CURRENT_INPUT(i, 3), BYTE_WIDTH));
            wait until '1'=CLK and CLK'event;
            SYSTOLIC_SIGNED <= '0';
        end loop;
        SYSTOLIC_DATA(3) <= (others => '0');
    end process;
    
    EVALUATE_RESULT:
    process is
    begin
        QUIT_CLOCK1 <= false;
        wait until EVALUATE = true;
        wait until '1'=CLK and CLK'event;
        wait until '1'=CLK and CLK'event;
        for i in 0 to MATRIX_WIDTH-1 loop
            wait until '1'=CLK and CLK'event;
        
            if RESULT_DATA(0) /= std_logic_vector(to_signed(CURRENT_RESULT(i, 0), 4*BYTE_WIDTH)) then
                report "Test failed! Result should be " & to_hstring(to_signed(CURRENT_RESULT(0, i), 4*BYTE_WIDTH)) & " but was " & to_hstring(RESULT_DATA(0)) & "." severity ERROR;
                QUIT_CLOCK1 <= true;
                wait;
            end if;
        
            if RESULT_DATA(1) /= std_logic_vector(to_signed(CURRENT_RESULT(i, 1), 4*BYTE_WIDTH)) then
                report "Test failed! Result should be " & to_hstring(to_signed(CURRENT_RESULT(1, i), 4*BYTE_WIDTH)) & " but was " & to_hstring(RESULT_DATA(1)) & "." severity ERROR;
                QUIT_CLOCK1 <= true;
                wait;
            end if;
        
            if RESULT_DATA(2) /= std_logic_vector(to_signed(CURRENT_RESULT(i, 2), 4*BYTE_WIDTH)) then
                report "Test failed! Result should be " & to_hstring(to_signed(CURRENT_RESULT(2, i), 4*BYTE_WIDTH)) & " but was " & to_hstring(RESULT_DATA(2)) & "." severity ERROR;
                QUIT_CLOCK1 <= true;
                wait;
            end if;
        
            if RESULT_DATA(3) /= std_logic_vector(to_signed(CURRENT_RESULT(i, 3), 4*BYTE_WIDTH)) then
                report "Test failed! Result should be " & to_hstring(to_signed(CURRENT_RESULT(3, i), 4*BYTE_WIDTH)) & " but was " & to_hstring(RESULT_DATA(3)) & "." severity ERROR;
                QUIT_CLOCK1 <= true;
                wait;
            end if;
        end loop;
        report "Test was successful!" severity NOTE;
    end process EVALUATE_RESULT;
        
        
    stop_the_clock <= QUIT_CLOCK0 or QUIT_CLOCK1;
    
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
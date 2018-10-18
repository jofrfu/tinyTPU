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
    
entity TB_SYSTOLIC_DATA_SETUP is
end entity TB_SYSTOLIC_DATA_SETUP;

architecture BEH of TB_SYSTOLIC_DATA_SETUP is
    component DUT is
        generic(
            MATRIX_WIDTH  : natural := 14
        );
        port(
            CLK, RESET      : in  std_logic;
            ENABLE          : in  std_logic;
            DATA_INPUT      : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            SYSTOLIC_OUTPUT : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1)
        );
    end component DUT;    
    for all : DUT use entity WORK.SYSTOLIC_DATA_SETUP(BEH);
    
    constant MATRIX_WIDTH     : natural := 10;
    signal CLK, RESET       : std_logic;
    signal ENABLE           : std_logic;
    signal DATA_INPUT       : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal SYSTOLIC_OUTPUT  : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean := false;
    signal evaluate         : boolean;
    
    constant INPUT_MATRIX   : NATURAL_ARRAY_2D_TYPE :=
        (   
            ( 1,  2,  3,  4,  5),
            ( 6,  7,  8,  9, 10),
            (11, 12, 13, 14, 15),
            (16, 17, 18, 19, 20),
            (21, 22, 23, 24, 25),
            (26, 27, 28, 29, 30),
            (31, 32, 33, 34, 35),
            (36, 37, 38, 39, 40),
            (41, 42, 43, 44, 45),
            (46, 47, 48, 49, 50)
        );
    
begin
    DUT_i : DUT
    generic map(
        MATRIX_WIDTH => MATRIX_WIDTH
    )
    port map(
        CLK => CLK,
        RESET => RESET,
        ENABLE => ENABLE,
        DATA_INPUT => DATA_INPUT,
        SYSTOLIC_OUTPUT => SYSTOLIC_OUTPUT
    );
    
    STIMULUS:
    process is
    begin
        evaluate <= false;
        RESET <= '0';
        ENABLE <= '0';
        DATA_INPUT <= (others => (others => '0'));
        wait until '1'=CLK and CLK'event;
        RESET <= '1';
        wait until '1'=CLK and CLK'event;
        RESET <= '0';
        wait until '1'=CLK and CLK'event;
        ENABLE <= '1';
        for i in 0 to 4 loop
            for j in 0 to 9 loop
                DATA_INPUT(j) <= std_logic_vector(to_unsigned(INPUT_MATRIX(j, i), BYTE_WIDTH)); 
            end loop;
            evaluate <= true;
            wait until '1'=CLK and CLK'event;
        end loop;
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
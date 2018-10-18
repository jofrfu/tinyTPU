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
    
entity TB_REGISTER_FILE is
end entity TB_REGISTER_FILE;

architecture BEH of TB_REGISTER_FILE is
    component DUT is
        generic(
            MATRIX_WIDTH    : natural := 256;
            REGISTER_DEPTH  : natural := 4096
        );
        port(
            CLK, RESET          : in  std_logic;
            ENABLE              : in  std_logic;
            
            WRITE_ADDRESS       : in  HALFWORD_TYPE;
            WRITE_PORT          : in  WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            WRITE_ENABLE        : in  std_logic;
            
            ACCUMULATE          : in  std_logic;
            
            READ_ADDRESS        : in  HALFWORD_TYPE;
            READ_PORT           : out WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1)
        );
    end component DUT;
    for all : DUT use entity WORK.REGISTER_FILE(BEH);
    
    constant MATRIX_WIDTH   : natural := 4;
    signal CLK, RESET       : std_logic;
    signal ENABLE           : std_logic;
    signal WRITE_ADDRESS    : HALFWORD_TYPE;
    signal WRITE_PORT       : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal WRITE_ENABLE     : std_logic;
    signal ACCUMULATE       : std_logic;
    signal READ_ADDRESS     : HALFWORD_TYPE;
    signal READ_PORT        : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean;
begin
    DUT_i : DUT
    generic map(
        MATRIX_WIDTH => MATRIX_WIDTH,
        REGISTER_DEPTH => MATRIX_WIDTH
    )
    port map(
        CLK             => CLK,
        RESET           => RESET,
        ENABLE          => ENABLE,
        WRITE_ADDRESS   => WRITE_ADDRESS,
        WRITE_PORT      => WRITE_PORT,
        WRITE_ENABLE    => WRITE_ENABLE,
        ACCUMULATE      => ACCUMULATE,
        READ_ADDRESS    => READ_ADDRESS,
        READ_PORT       => READ_PORT
    );
    
    STIMULUS:
    process is
    begin
        stop_the_clock <= false;
        RESET <= '0';
        ENABLE <= '0';
        WRITE_ADDRESS <= (others => '0');
        WRITE_PORT <= (others => (others => '0'));
        WRITE_ENABLE <= '1';
        ACCUMULATE <= '0';
        READ_ADDRESS <= (others => '0');
        wait until '1'=CLK and CLK'event;
        -- RESET
        RESET <= '1';
        wait until '1'=CLK and CLK'event;
        RESET <= '0';
        wait until '1'=CLK and CLK'event;
        ENABLE <= '1';
        -- TEST - hold values
        for i in 0 to MATRIX_WIDTH-1 loop
            for j in 0 to MATRIX_WIDTH-1 loop
                WRITE_PORT(j) <= std_logic_vector(to_unsigned(i, 4*BYTE_WIDTH));
            end loop;
            WRITE_ADDRESS <= std_logic_vector(to_unsigned(i, 2*BYTE_WIDTH));
            WRITE_ENABLE <= '1';
            wait until '1'=CLK and CLK'event;
        end loop;
        
        WRITE_ENABLE <= '0';
        
        for i in 0 to MATRIX_WIDTH-1 loop
            READ_ADDRESS <= std_logic_vector(to_unsigned(i, 2*BYTE_WIDTH));
            for j in 0 to MATRIX_WIDTH-1 loop
                wait for 1 ns;
                if READ_PORT(j) /= std_logic_vector(to_unsigned(i, 4*BYTE_WIDTH)) then
                    report "Test failed at saving!" severity ERROR;
                    --stop_the_clock <= true;
                    --wait;
                end if;
            end loop;
            wait until '1'=CLK and CLK'event;
        end loop;
        
        -- TEST - accumulate values
        ACCUMULATE <= '1';
        for i in 0 to MATRIX_WIDTH-1 loop
            for j in 0 to MATRIX_WIDTH-1 loop
                WRITE_PORT(j) <= std_logic_vector(to_unsigned(j, 4*BYTE_WIDTH));
            end loop;
            WRITE_ADDRESS <= std_logic_vector(to_unsigned(i, 2*BYTE_WIDTH));
            WRITE_ENABLE <= '1';
            wait until '1'=CLK and CLK'event;
            --WRITE_PORT <= (others => (others => '0')); -- accumulate 0 - register will count up on checking otherwise
        end loop;
        WRITE_ENABLE <= '0';
        
        for i in 0 to MATRIX_WIDTH-1 loop
            READ_ADDRESS <= std_logic_vector(to_unsigned(i, 2*BYTE_WIDTH));
            for j in 0 to MATRIX_WIDTH-1 loop
                wait for 1 ns;
                if READ_PORT(j) /= std_logic_vector(to_unsigned(i+j, 4*BYTE_WIDTH)) then
                    report "Test failed at accumulation!" severity ERROR;
                    --stop_the_clock <= true;
                    --wait;
                end if;
            end loop;
            wait until '1'=CLK and CLK'event;
        end loop;
                
        report "Test was successful!" severity NOTE;
        
        --stop_the_clock <= true;
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
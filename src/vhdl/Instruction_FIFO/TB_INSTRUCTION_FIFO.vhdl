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
    use IEEE.math_real.log2;
    use IEEE.math_real.ceil;

entity TB_INSTRUCTION_FIFO is
end entity TB_INSTRUCTION_FIFO;

architecture BEH of TB_INSTRUCTION_FIFO is
    component DUT is
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
    end component DUT;
    for all : DUT use entity WORK.INSTRUCTION_FIFO(BEH);
    
    constant FIFO_DEPTH : natural := 32;
    
    signal CLK, RESET   : std_logic;
    signal LOWER_WORD   : WORD_TYPE;
    signal MIDDLE_WORD  : WORD_TYPE;
    signal UPPER_WORD   : HALFWORD_TYPE;
    signal WRITE_EN     : std_logic_vector(0 to 2);
    
    signal OUTPUT       : INSTRUCTION_TYPE;
    signal NEXT_EN      : std_logic;
    
    signal EMPTY        : std_logic;
    signal FULL         : std_logic;
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean;
begin
    DUT_i : DUT
    generic map(
        FIFO_DEPTH  => FIFO_DEPTH
    )
    port map(
        CLK         => CLK,
        RESET       => RESET,
        LOWER_WORD  => LOWER_WORD,
        MIDDLE_WORD => MIDDLE_WORD,
        UPPER_WORD  => UPPER_WORD,
        WRITE_EN    => WRITE_EN,
        OUTPUT      => OUTPUT,
        NEXT_EN     => NEXT_EN,
        EMPTY       => EMPTY,
        FULL        => FULL
    );
    
    STIMULUS:
    process is
    begin
        stop_the_clock <= false;
        RESET <= '0';
        LOWER_WORD <= (others => '0');
        MIDDLE_WORD <= (others => '0');
        UPPER_WORD <= (others => '0');
        WRITE_EN <= (others => '0');
        NEXT_EN <= '0';
        -- RESET
        RESET <= '1';
        wait until '1'=CLK and CLK'event;
        RESET <= '0';
        wait until '1'=CLK and CLK'event;
        -- Put in lower word
        LOWER_WORD <= x"AFFEDEAD";
        WRITE_EN(0) <= '1';
        wait until '1'=CLK and CLK'event;
        LOWER_WORD <= (others => '0');
        WRITE_EN(0) <= '0';
        -- FIFO should still be empty
        wait for 1 ns;
        if EMPTY /= '1' then
            report "FIFO should be empty!" severity ERROR;
            stop_the_clock <= true;
            wait;
        end if;
        wait until '1'=CLK and CLK'event;
        -- Put in middle word
        MIDDLE_WORD <= x"B00BEEEE";
        WRITE_EN(1) <= '1';
        wait until '1'=CLK and CLK'event;
        MIDDLE_WORD <= (others => '0');
        WRITE_EN(1) <= '0';
        -- FIFO should still be empty
        wait for 1 ns;
        if EMPTY /= '1' then
            report "FIFO should be empty!" severity ERROR;
            stop_the_clock <= true;
            wait;
        end if;
        wait until '1'=CLK and CLK'event;
        -- Put in uppper word
        UPPER_WORD <= x"BEEB";
        WRITE_EN(2) <= '1';
        wait until '1'=CLK and CLK'event;
        UPPER_WORD <= (others => '0');
        WRITE_EN(2) <= '0';
        -- FIFO shouldn't be empty anymore
        wait for 1 ns;
        if EMPTY /= '0' then
            report "FIFO shouldn't be empty!" severity ERROR;
            stop_the_clock <= true;
            wait;
        end if;
        wait until '1'=CLK and CLK'event;
        -- Poll the written value
        NEXT_EN <= '1';
        wait for 1 ns;
        if OUTPUT /= BITS_TO_INSTRUCTION(x"BEEBB00BEEEEAFFEDEAD") then
            report "Wrong value in FIFO!" severity ERROR;
        end if;
        
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
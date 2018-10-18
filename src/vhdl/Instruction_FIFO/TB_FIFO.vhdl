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
    
entity TB_FIFO is
end entity TB_FIFO;

architecture BEH of TB_FIFO is
    component DUT is
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
    end component DUT;
    for all : DUT use entity WORK.FIFO(DIST_RAM_FIFO);
    
    constant FIFO_WIDTH : natural := 8;
    constant FIFO_DEPTH : natural := 32;
    
    signal CLK, RESET   : std_logic;
    signal INPUT        : std_logic_vector(FIFO_WIDTH-1 downto 0);
    signal WRITE_EN     : std_logic;
    signal OUTPUT       : std_logic_vector(FIFO_WIDTH-1 downto 0);
    signal NEXT_EN      : std_logic;
    signal EMPTY        : std_logic;
    signal FULL         : std_logic;
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean;
begin
    DUT_i : DUT
    generic map(
        FIFO_WIDTH  => FIFO_WIDTH,
        FIFO_DEPTH  => FIFO_DEPTH
    )
    port map(
        CLK         => CLK,
        RESET       => RESET,
        INPUT       => INPUT,
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
        INPUT <= (others => '0');
        WRITE_EN <= '0';
        NEXT_EN <= '0';
        -- RESET
        RESET <= '1';
        wait until '1'=CLK and CLK'event;
        RESET <= '0';
        wait until '1'=CLK and CLK'event;
        -- Fill FIFO
        for i in 0 to FIFO_DEPTH-1 loop
            INPUT <= std_logic_vector(to_unsigned(i, FIFO_WIDTH));
            WRITE_EN <= '1';
            wait until '1'=CLK and CLK'event;
        end loop;
        WRITE_EN <= '0';
        -- FIFO should be full
        wait for 1 ns;
        if FULL /= '1' then
            report "Test failed! FIFO should be full!" severity ERROR;
            stop_the_clock <= true;
            wait;
        end if;
        -- Check FIFO
        for i in 0 to FIFO_DEPTH-1 loop
            NEXT_EN <= '1';
            wait for 1 ns;
            if OUTPUT /= std_logic_vector(to_unsigned(i, FIFO_WIDTH)) then
                report "Test failed! Error on reading the FIFO!" severity ERROR;
                stop_the_clock <= true;
                wait;
            end if;
            wait until '1'=CLK and CLK'event;
        end loop;
        NEXT_EN <= '0';
        -- FIFO should be empty
        wait for 1 ns;
        if EMPTY /= '1' then
            report "Test failed! FIFO should be empty!" severity ERROR;
            stop_the_clock <= true;
            wait;
        end if;
        
        
        wait until '1'=CLK and CLK'event;
        -- Fill FIFO
        for i in 0 to FIFO_DEPTH-1 loop
            INPUT <= std_logic_vector(to_unsigned(i, FIFO_WIDTH));
            WRITE_EN <= '1';
            wait until '1'=CLK and CLK'event;
        end loop;
        WRITE_EN <= '0';
        -- FIFO should be full
        wait for 1 ns;
        if FULL /= '1' then
            report "Test failed! FIFO should be full!" severity ERROR;
            stop_the_clock <= true;
            wait;
        end if;
        -- Check half FIFO
        for i in 0 to FIFO_DEPTH/2-1 loop
            NEXT_EN <= '1';
            wait for 1 ns;
            if OUTPUT /= std_logic_vector(to_unsigned(i, FIFO_WIDTH)) then
                report "Test failed! Error on reading the FIFO!" severity ERROR;
                stop_the_clock <= true;
                wait;
            end if;
            wait until '1'=CLK and CLK'event;
        end loop;
        NEXT_EN <= '0';
        -- Fill FIFO for overflow check
        for i in 0 to FIFO_DEPTH/2-1 loop
            INPUT <= std_logic_vector(to_unsigned(i, FIFO_WIDTH));
            WRITE_EN <= '1';
            wait until '1'=CLK and CLK'event;
        end loop;
        WRITE_EN <= '0';
        -- FIFO should be full
        wait for 1 ns;
        if FULL /= '1' then
            report "Test failed! FIFO should be full!" severity ERROR;
            stop_the_clock <= true;
            wait;
        end if;
        -- Check half FIFO
        for i in FIFO_DEPTH/2 to FIFO_DEPTH-1 loop
            NEXT_EN <= '1';
            wait for 1 ns;
            if OUTPUT /= std_logic_vector(to_unsigned(i, FIFO_WIDTH)) then
                report "Test failed! Error on reading the FIFO!" severity ERROR;
                stop_the_clock <= true;
                wait;
            end if;
            wait until '1'=CLK and CLK'event;
        end loop;
        NEXT_EN <= '0';
        -- Check half FIFO
        for i in 0 to FIFO_DEPTH/2-1 loop
            NEXT_EN <= '1';
            wait for 1 ns;
            if OUTPUT /= std_logic_vector(to_unsigned(i, FIFO_WIDTH)) then
                report "Test failed! Error on reading the FIFO!" severity ERROR;
                stop_the_clock <= true;
                wait;
            end if;
            wait until '1'=CLK and CLK'event;
        end loop;
        -- FIFO should be empty
        wait for 1 ns;
        if EMPTY /= '1' then
            report "Test failed! FIFO should be empty!" severity ERROR;
            stop_the_clock <= true;
            wait;
        end if;
        
        report "Test was successful!" severity NOTE;
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
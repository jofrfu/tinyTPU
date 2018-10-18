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

entity TB_tinyTPU_AXI is
end entity TB_tinyTPU_AXI;

architecture BEH of TB_tinyTPU_AXI is
    component DUT is
        port(
            clk : in STD_LOGIC;
            done_0 : out STD_LOGIC;
            nres : in STD_LOGIC;
            pc_asserted_0 : out STD_LOGIC;
            pc_status_0 : out STD_LOGIC_VECTOR ( 159 downto 0 );
            status_0 : out STD_LOGIC_VECTOR ( 31 downto 0 )
        );
    end component DUT;
    for all : DUT use entity WORK.test_design_wrapper(STRUCTURE);

    signal clk : STD_LOGIC;
    signal done_0 : STD_LOGIC;
    signal nres : STD_LOGIC;
    signal pc_asserted_0 : STD_LOGIC;
    signal pc_status_0 : STD_LOGIC_VECTOR ( 159 downto 0 );
    signal status_0 : STD_LOGIC_VECTOR ( 31 downto 0 );
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean;
    
begin
    DUT_i : DUT
    port map(
        clk            => clk          ,
        done_0         => done_0       ,
        nres           => nres         ,
        pc_asserted_0  => pc_asserted_0,
        pc_status_0    => pc_status_0  ,
        status_0       => status_0     
    );
    
    RESET:
    process is
    begin
        nres <= '1';
        wait until '1'=clk and clk'event;
        nres <= '0';
        wait until '1'=clk and clk'event;
        nres <= '1';
        wait; 
    end process RESET;
    
    CLOCK_GEN: 
    process
    begin
        while not stop_the_clock loop
          clk <= '0', '1' after clock_period / 2;
          wait for clock_period;
        end loop;
        wait;
    end process CLOCK_GEN;
end architecture BEH;
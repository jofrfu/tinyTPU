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
    
entity TB_UNIFIED_BUFFER is
end entity TB_UNIFIED_BUFFER;

architecture BEH of TB_UNIFIED_BUFFER is
    component DUT is
        generic(
            MATRIX_WIDTH    : natural := 14;
            -- How many tiles(MATRIX_WIDTH^2) can be saved
            TILE_WIDTH      : natural := 1024
        );
        port(
            CLK             : in  std_logic;
            -- Port0
            ADDRESS0        : in  BUFFER_ADDRESS_TYPE;
            EN0             : in  std_logic;
            WRITE_EN0       : in  std_logic;
            WRITE_PORT0     : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            READ_PORT0      : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            -- Port1
            ADDRESS1        : in  BUFFER_ADDRESS_TYPE;
            EN1             : in  std_logic;
            WRITE_EN1       : in  std_logic;
            WRITE_PORT1     : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            READ_PORT1      : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1)
        );
    end component DUT;
    for all : DUT use entity WORK.UNIFIED_BUFFER(BEH);
    
    constant MATRIX_WIDTH   : natural := 4;
    constant TILE_WIDTH     : natural := 2;
    
    signal CLK          : std_logic;
    signal ADDRESS0     : BUFFER_ADDRESS_TYPE;
    signal EN0          : std_logic;
    signal WRITE_EN0    : std_logic;
    signal WRITE_PORT0  : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal READ_PORT0   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal ADDRESS1     : BUFFER_ADDRESS_TYPE;
    signal EN1          : std_logic;
    signal WRITE_EN1    : std_logic;
    signal WRITE_PORT1  : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal READ_PORT1   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean;
begin

    DUT_i : DUT
    generic map(
        MATRIX_WIDTH => MATRIX_WIDTH,
        TILE_WIDTH => TILE_WIDTH
    )
    port map(
        CLK => CLK,
        ADDRESS0 => ADDRESS0,
        EN0 => EN0,
        WRITE_EN0 => WRITE_EN0,
        WRITE_PORT0 => WRITE_PORT0,
        READ_PORT0 => READ_PORT0,
        ADDRESS1 => ADDRESS1,
        EN1 => EN1,
        WRITE_EN1 => WRITE_EN1,
        WRITE_PORT1 => WRITE_PORT1,
        READ_PORT1 => READ_PORT1
    );
    
    STIMULUS:
    process is
    begin
        ADDRESS0 <= (others => '0');
        EN0 <= '0';
        WRITE_EN0 <= '0';
        WRITE_PORT0 <= (others => (others => '0'));
        ADDRESS1 <= (others => '0');
        EN1 <= '0';
        WRITE_EN1 <= '0';
        WRITE_PORT1 <= (others => (others => '0'));
        wait until '1'=CLK and CLK'event;
        -- TEST write to memory through port0
        for i in 0 to TILE_WIDTH*MATRIX_WIDTH-1 loop
            ADDRESS0 <= std_logic_vector(to_unsigned(i, 3*BYTE_WIDTH));
            EN0 <= '1';
            WRITE_EN0 <= '1';
            for j in 0 to MATRIX_WIDTH-1 loop
                WRITE_PORT0(j) <= std_logic_vector(to_unsigned(i*j, BYTE_WIDTH));
            end loop;
            wait until '1'=CLK and CLK'event;
        end loop;
        EN0 <= '0';
        WRITE_EN0 <= '0';
        
        -- TEST read from memory through port0
        for i in 0 to TILE_WIDTH*MATRIX_WIDTH-1 loop
            ADDRESS0 <= std_logic_vector(to_unsigned(i, 3*BYTE_WIDTH));
            EN0 <= '1';
            wait until '1'=CLK and CLK'event;
            for j in 0 to MATRIX_WIDTH-1 loop
                wait for 1 ns;
                if READ_PORT0(j) /= std_logic_vector(to_unsigned(i*j, BYTE_WIDTH)) then
                    report "Error reading memory through port0!" severity ERROR;
                    stop_the_clock <= true;
                    wait;
                end if;
            end loop;
        end loop;
        EN0 <= '0';
        
        wait until '1'=CLK and CLK'event;
        -- TEST write to memory through port1
        for i in 0 to TILE_WIDTH*MATRIX_WIDTH-1 loop
            ADDRESS1 <= std_logic_vector(to_unsigned(i, 3*BYTE_WIDTH));
            EN1 <= '1';
            WRITE_EN1 <= '1';
            for j in 0 to MATRIX_WIDTH-1 loop
                WRITE_PORT1(j) <= std_logic_vector(to_unsigned(i*j+128, BYTE_WIDTH));
            end loop;
            wait until '1'=CLK and CLK'event;
        end loop;
        EN1 <= '0';
        WRITE_EN1 <= '0';
        
        -- TEST read from memory through port1
        for i in 0 to TILE_WIDTH*MATRIX_WIDTH-1 loop
            ADDRESS1 <= std_logic_vector(to_unsigned(i, 3*BYTE_WIDTH));
            EN1 <= '1';
            wait until '1'=CLK and CLK'event;
            for j in 0 to MATRIX_WIDTH-1 loop
                wait for 1 ns;
                if READ_PORT1(j) /= std_logic_vector(to_unsigned(i*j+128, BYTE_WIDTH)) then
                    report "Error reading memory through port1!" severity ERROR;
                    stop_the_clock <= true;
                    wait;
                end if;
            end loop;
        end loop;
        EN1 <= '0';
        
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
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

--! @file WEIGHT_BUFFER.vhdl
--! @author Jonas Fuhrmann
--! @brief This component includes the weight buffer, a buffer used for neural net weights.
--! @details The buffer can store data from the master (host system). The stored data can then be used for matrix multiplies.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    
entity WEIGHT_BUFFER is
    generic(
        MATRIX_WIDTH    : natural := 14;
        -- How many tiles can be saved
        TILE_WIDTH      : natural := 32768  --!< The depth of the buffer.
    );
    port(
        CLK, RESET      : in  std_logic;
        ENABLE          : in  std_logic;
        
        -- Port0
        ADDRESS0        : in  WEIGHT_ADDRESS_TYPE; --!< Address of port 0.
        EN0             : in  std_logic; --!< Enable of port 0.
        WRITE_EN0       : in  std_logic; --!< Write enable of port 0.
        WRITE_PORT0     : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Write port of port 0.
        READ_PORT0      : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Read port of port 0.
        -- Port1
        ADDRESS1        : in  WEIGHT_ADDRESS_TYPE; --!< Address of port 1.
        EN1             : in  std_logic; --!< Enable of port 1.
        WRITE_EN1       : in  std_logic_vector(0 to MATRIX_WIDTH-1); --!< Write enable of port 1.
        WRITE_PORT1     : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Write port of port 1.
        READ_PORT1      : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) --!< Read port of port 1.
    );
end entity WEIGHT_BUFFER;

--! @brief The architecture of the weight buffer component.
architecture BEH of WEIGHT_BUFFER is
    signal READ_PORT0_REG0_cs   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal READ_PORT0_REG0_ns   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal READ_PORT0_REG1_cs   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal READ_PORT0_REG1_ns   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    signal READ_PORT1_REG0_cs   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal READ_PORT1_REG0_ns   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal READ_PORT1_REG1_cs   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal READ_PORT1_REG1_ns   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);

    signal WRITE_PORT0_BITS : std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);
    signal WRITE_PORT1_BITS : std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);
    signal READ_PORT0_BITS  : std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);
    signal READ_PORT1_BITS  : std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);

    type RAM_TYPE is array(0 to TILE_WIDTH-1) of std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);
    shared variable RAM  : RAM_TYPE
    --synthesis translate_off
        :=
        -- Test values - Identity
        (
            BYTE_ARRAY_TO_BITS((x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80", x"00")),
            BYTE_ARRAY_TO_BITS((x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"80")),
            others => (others => '0')
        )
    --synthesis translate_on
    ;
    
    attribute ram_style        : string;
    attribute ram_style of RAM : variable is "block";
begin
    WRITE_PORT0_BITS    <= BYTE_ARRAY_TO_BITS(WRITE_PORT0);
    WRITE_PORT1_BITS    <= BYTE_ARRAY_TO_BITS(WRITE_PORT1);
    
    READ_PORT0_REG0_ns  <= BITS_TO_BYTE_ARRAY(READ_PORT0_BITS);
    READ_PORT1_REG0_ns  <= BITS_TO_BYTE_ARRAY(READ_PORT1_BITS);
    READ_PORT0_REG1_ns  <= READ_PORT0_REG0_cs;
    READ_PORT1_REG1_ns  <= READ_PORT1_REG0_cs;
    READ_PORT0          <= READ_PORT0_REG1_cs;
    READ_PORT1          <= READ_PORT1_REG1_cs;

    PORT0:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if EN0 = '1' then
                --synthesis translate_off
                if to_integer(unsigned(ADDRESS0)) < TILE_WIDTH then
                --synthesis translate_on
                    if WRITE_EN0 = '1' then
                        RAM(to_integer(unsigned(ADDRESS0))) := WRITE_PORT0_BITS;
                    end if;
                    READ_PORT0_BITS <= RAM(to_integer(unsigned(ADDRESS0)));
                --synthesis translate_off
                end if;
                --synthesis translate_on
            end if;
        end if;
    end process PORT0;
    
    PORT1:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if EN1 = '1' then
                --synthesis translate_off
                if to_integer(unsigned(ADDRESS1)) < TILE_WIDTH then
                --synthesis translate_on
                    for i in 0 to MATRIX_WIDTH-1 loop
                        if WRITE_EN1(i) = '1' then
                            RAM(to_integer(unsigned(ADDRESS1)))((i + 1) * BYTE_WIDTH - 1 downto i * BYTE_WIDTH) := WRITE_PORT1_BITS((i + 1) * BYTE_WIDTH - 1 downto i * BYTE_WIDTH);
                        end if;
                    end loop;
                    READ_PORT1_BITS <= RAM(to_integer(unsigned(ADDRESS1)));
                --synthesis translate_off
                end if;
                --synthesis translate_on
            end if;
        end if;
    end process PORT1;
    
    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                READ_PORT0_REG0_cs <= (others => (others => '0'));
                READ_PORT0_REG1_cs <= (others => (others => '0'));
                READ_PORT1_REG0_cs <= (others => (others => '0'));
                READ_PORT1_REG1_cs <= (others => (others => '0'));
            else
                if ENABLE = '1' then
                    READ_PORT0_REG0_cs <= READ_PORT0_REG0_ns;
                    READ_PORT0_REG1_cs <= READ_PORT0_REG1_ns;
                    READ_PORT1_REG0_cs <= READ_PORT1_REG0_ns;
                    READ_PORT1_REG1_cs <= READ_PORT1_REG1_ns;
                end if;
            end if;
        end if;
    end process SEQ_LOG;
end architecture BEH;
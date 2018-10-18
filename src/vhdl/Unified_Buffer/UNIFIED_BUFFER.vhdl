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

--! @file UNIFIED_BUFFER.vhdl
--! @author Jonas Fuhrmann
--! @brief This component includes the unified buffer, a buffer used for neural net layer inputs.
--! @details The buffer can store data from the master (host system). The stored data can then be used for matrix multiplies.
--! After activation, the calculated data can be stored back for the next neural net layer.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    
entity UNIFIED_BUFFER is
    generic(
        MATRIX_WIDTH    : natural := 14;
        -- How many tiles can be saved
        TILE_WIDTH      : natural := 4096 --!< The depth of the buffer.
    );
    port(
        CLK, RESET      : in  std_logic;
        ENABLE          : in  std_logic;
        
        -- Master port - overrides other ports
        MASTER_ADDRESS      : in  BUFFER_ADDRESS_TYPE; --!< Master (host) address, overrides other addresses.
        MASTER_EN           : in  std_logic; --!< Master (host) enable, overrides other enables.
        MASTER_WRITE_EN     : in  std_logic_vector(0 to MATRIX_WIDTH-1); --!< Master (host) write enable, overrides other write enables.
        MASTER_WRITE_PORT   : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Master (host) write port, overrides other write ports.
        MASTER_READ_PORT    : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Master (host) read port, overrides other read ports.
        -- Port0
        ADDRESS0        : in  BUFFER_ADDRESS_TYPE; --!< Address of port 0.
        EN0             : in  std_logic; --!< Enable of port 0.
        READ_PORT0      : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Read port of port 0.
        -- Port1
        ADDRESS1        : in  BUFFER_ADDRESS_TYPE; --!< Address of port 1.
        EN1             : in  std_logic; --!< Enable of port 1.
        WRITE_EN1       : in  std_logic; --!< Write enable of port 1.
        WRITE_PORT1     : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) --!< Write port of port 1.
    );
end entity UNIFIED_BUFFER;

--! @brief The architecture of the unified buffer component.
architecture BEH of UNIFIED_BUFFER is
    signal READ_PORT0_REG0_cs   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal READ_PORT0_REG0_ns   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal READ_PORT0_REG1_cs   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal READ_PORT0_REG1_ns   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    signal MASTER_READ_PORT_REG0_cs : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal MASTER_READ_PORT_REG0_ns : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    signal MASTER_READ_PORT_REG1_cs : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1) := (others => (others => '0'));
    signal MASTER_READ_PORT_REG1_ns : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);

    signal WRITE_PORT1_BITS : std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);
    signal READ_PORT0_BITS  : std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);

    signal MASTER_WRITE_PORT_BITS   : std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);
    signal MASTER_READ_PORT_BITS    : std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);
    
    signal ADDRESS0_OVERRIDE    : BUFFER_ADDRESS_TYPE;
    signal ADDRESS1_OVERRIDE    : BUFFER_ADDRESS_TYPE;
    
    signal EN0_OVERRIDE : std_logic;
    signal EN1_OVERRIDE : std_logic;
    
    type RAM_TYPE is array(0 to TILE_WIDTH-1) of std_logic_vector(MATRIX_WIDTH*BYTE_WIDTH-1 downto 0);
    shared variable RAM  : RAM_TYPE
    --synthesis translate_off
        :=
        -- Test values
        (
            BYTE_ARRAY_TO_BITS((x"7F", x"7E", x"7D", x"7C", x"7B", x"7A", x"79", x"78", x"77", x"76", x"75", x"74", x"73", x"72")),
            BYTE_ARRAY_TO_BITS((x"71", x"70", x"6F", x"6E", x"6D", x"6C", x"6B", x"6A", x"69", x"68", x"67", x"66", x"65", x"64")),
            BYTE_ARRAY_TO_BITS((x"63", x"62", x"61", x"60", x"5F", x"5E", x"5D", x"5C", x"5B", x"5A", x"59", x"58", x"57", x"56")),
            BYTE_ARRAY_TO_BITS((x"55", x"54", x"53", x"52", x"51", x"50", x"4F", x"4E", x"4D", x"4C", x"4B", x"4A", x"49", x"48")),
            BYTE_ARRAY_TO_BITS((x"47", x"46", x"45", x"44", x"43", x"42", x"41", x"40", x"3F", x"3E", x"3D", x"3C", x"3B", x"3A")),
            BYTE_ARRAY_TO_BITS((x"39", x"38", x"37", x"36", x"35", x"34", x"33", x"32", x"31", x"30", x"2F", x"2E", x"2D", x"2C")),
            BYTE_ARRAY_TO_BITS((x"2B", x"2A", x"29", x"28", x"27", x"26", x"25", x"24", x"23", x"22", x"21", x"20", x"1F", x"1E")),
            BYTE_ARRAY_TO_BITS((x"1D", x"1C", x"1B", x"1A", x"19", x"18", x"17", x"16", x"15", x"14", x"13", x"12", x"11", x"10")),
            BYTE_ARRAY_TO_BITS((x"0F", x"0E", x"0D", x"0C", x"0B", x"0A", x"09", x"08", x"07", x"06", x"05", x"04", x"03", x"02")),
            BYTE_ARRAY_TO_BITS((x"01", x"00", x"FF", x"FE", x"FD", x"FC", x"FB", x"FA", x"F9", x"F8", x"F7", x"F6", x"F5", x"F4")),
            BYTE_ARRAY_TO_BITS((x"F3", x"F2", x"F1", x"F0", x"EF", x"EE", x"ED", x"EC", x"EB", x"EA", x"E9", x"E8", x"E7", x"E6")),
            BYTE_ARRAY_TO_BITS((x"E5", x"E4", x"E3", x"E2", x"E1", x"E0", x"DF", x"DE", x"DD", x"DC", x"DB", x"DA", x"D9", x"D8")),
            BYTE_ARRAY_TO_BITS((x"D7", x"D6", x"D5", x"D4", x"D3", x"D2", x"D1", x"D0", x"CF", x"CE", x"CD", x"CC", x"CB", x"CA")),
            BYTE_ARRAY_TO_BITS((x"C9", x"C8", x"C7", x"C6", x"C5", x"C4", x"C3", x"C2", x"C1", x"C0", x"BF", x"BE", x"BD", x"BC")),
            others => (others => '0')
        )
    --synthesis translate_on
    ;
    
    attribute ram_style        : string;
    attribute ram_style of RAM : variable is "block";
begin
    WRITE_PORT1_BITS        <= BYTE_ARRAY_TO_BITS(WRITE_PORT1);
    MASTER_WRITE_PORT_BITS  <= BYTE_ARRAY_TO_BITS(MASTER_WRITE_PORT);
    
    READ_PORT0_REG0_ns  <= BITS_TO_BYTE_ARRAY(READ_PORT0_BITS);
    READ_PORT0_REG1_ns  <= READ_PORT0_REG0_cs;
    READ_PORT0          <= READ_PORT0_REG1_cs;

    MASTER_READ_PORT_REG0_ns    <= BITS_TO_BYTE_ARRAY(MASTER_READ_PORT_BITS);
    MASTER_READ_PORT_REG1_ns    <= MASTER_READ_PORT_REG0_cs;
    MASTER_READ_PORT            <= MASTER_READ_PORT_REG1_cs;
    
    OVERRIDE:
    process(MASTER_EN, EN0, EN1, MASTER_ADDRESS, ADDRESS0, ADDRESS1) is
    begin
        if MASTER_EN = '1' then
            EN0_OVERRIDE <= MASTER_EN;
            EN1_OVERRIDE <= MASTER_EN;
            ADDRESS0_OVERRIDE <= MASTER_ADDRESS;
            ADDRESS1_OVERRIDE <= MASTER_ADDRESS;
        else
            EN0_OVERRIDE <= EN0;
            EN1_OVERRIDE <= EN1;
            ADDRESS0_OVERRIDE <= ADDRESS0;
            ADDRESS1_OVERRIDE <= ADDRESS1;
        end if;
    end process OVERRIDE;
    
    PORT0:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if EN0_OVERRIDE = '1' then
                --synthesis translate_off
                if to_integer(unsigned(ADDRESS0_OVERRIDE)) < TILE_WIDTH then
                --synthesis translate_on
                    for i in 0 to MATRIX_WIDTH-1 loop
                        if MASTER_WRITE_EN(i) = '1' then
                            RAM(to_integer(unsigned(ADDRESS0_OVERRIDE)))((i + 1) * BYTE_WIDTH - 1 downto i * BYTE_WIDTH) := MASTER_WRITE_PORT_BITS((i + 1) * BYTE_WIDTH - 1 downto i * BYTE_WIDTH);
                        end if;
                    end loop;
                    READ_PORT0_BITS <= RAM(to_integer(unsigned(ADDRESS0_OVERRIDE)));
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
            if EN1_OVERRIDE = '1' then
                --synthesis translate_off
                if to_integer(unsigned(ADDRESS1_OVERRIDE)) < TILE_WIDTH then
                --synthesis translate_on
                    if WRITE_EN1 = '1' then
                        RAM(to_integer(unsigned(ADDRESS1_OVERRIDE))) := WRITE_PORT1_BITS;
                    end if;
                    MASTER_READ_PORT_BITS <= RAM(to_integer(unsigned(ADDRESS1_OVERRIDE)));
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
                MASTER_READ_PORT_REG0_cs <= (others => (others => '0'));
                MASTER_READ_PORT_REG1_cs <= (others => (others => '0'));
            else
                if ENABLE = '1' then
                    READ_PORT0_REG0_cs <= READ_PORT0_REG0_ns;
                    READ_PORT0_REG1_cs <= READ_PORT0_REG1_ns;
                    MASTER_READ_PORT_REG0_cs <= MASTER_READ_PORT_REG0_ns;
                    MASTER_READ_PORT_REG1_cs <= MASTER_READ_PORT_REG1_ns;
                end if;
            end if;
        end if;
    end process SEQ_LOG;
end architecture BEH;
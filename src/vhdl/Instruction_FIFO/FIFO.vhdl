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

--! @file FIFO.vhdl
--! @author Jonas Fuhrmann
--! @brief This component includes a simple FIFO.
--! @details The FIFO uses distributed RAM.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    use IEEE.math_real.log2;
    use IEEE.math_real.ceil;

entity FIFO is
    generic(
        FIFO_WIDTH  : natural := 8;
        FIFO_DEPTH  : natural := 32
    );
    port(
        CLK, RESET  : in  std_logic;
        INPUT       : in  std_logic_vector(FIFO_WIDTH-1 downto 0); --!< Write port of the FIFO.
        WRITE_EN    : in  std_logic; --!< Write enable flag for the FIFO.
        
        OUTPUT      : out std_logic_vector(FIFO_WIDTH-1 downto 0); --!< Read port of the FIFO.
        NEXT_EN     : in  std_logic; --!< Read or 'next' enable of the FIFO (clears the current value).
        
        EMPTY       : out std_logic; --!< Determines if the FIFo is empty.
        FULL        : out std_logic --!< Determines if the FIFO is full.
    );
end entity FIFO;

architecture FF_FIFO of FIFO is
    type FIFO_TYPE is array(0 to FIFO_DEPTH-1) of std_logic_vector(FIFO_WIDTH-1 downto 0);
    
    signal FIFO_DATA    : FIFO_TYPE := (others => (others => '0'));
    signal SIZE         : natural range 0 to FIFO_DEPTH := 0;
begin

    OUTPUT <= FIFO_DATA(0);
    
    FIFO_PROC:
    process(CLK, INPUT, WRITE_EN, NEXT_EN, FIFO_DATA, SIZE) is
        variable INPUT_v        : std_logic_vector(FIFO_WIDTH-1 downto 0);
        variable WRITE_EN_v     : std_logic;
        variable NEXT_EN_v      : std_logic;
    
        variable FIFO_DATA_v    : FIFO_TYPE;
        variable SIZE_v         : natural range 0 to FIFO_DEPTH;
        
        -- output
        variable EMPTY_v        : std_logic := '1';
        variable FULL_v         : std_logic := '0';
    begin
        INPUT_v     := INPUT;
        WRITE_EN_v  := WRITE_EN;
        NEXT_EN_v   := NEXT_EN;
        
        FIFO_DATA_v := FIFO_DATA;
        SIZE_v      := SIZE;
        
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                SIZE_v      := 0;
                FIFO_DATA_v := (others => (others => '0'));
                EMPTY_v     := '1';
                FULL_v      := '0';
            else
                if NEXT_EN_v = '1' then
                    for i in 1 to FIFO_DEPTH-1 loop
                        FIFO_DATA_v(i-1) := FIFO_DATA_v(i);
                    end loop;
                    
                    SIZE_v := SIZE_v - 1;
                    FULL_v := '0';
                end if;
                
                if WRITE_EN_v = '1' then
                    FIFO_DATA_v(SIZE_v) := INPUT_v;
                    SIZE_v := SIZE_v + 1;
                    EMPTY_v := '0';
                end if;
                    
                case SIZE_v is
                    when FIFO_DEPTH =>
                        EMPTY_v := '0';
                        FULL_v  := '1';
                    when 0 =>
                        EMPTY_v := '1';
                        FULL_v  := '0';
                    when others =>
                        EMPTY_v := EMPTY_v;
                        FULL_v  := FULL_v;
                end case;
                       
            end if;
        end if;
        
        FIFO_DATA   <= FIFO_DATA_v;
        SIZE        <= SIZE_v;
        EMPTY       <= EMPTY_v;
        FULL        <= FULL_v;
    end process FIFO_PROC;
end architecture FF_FIFO;

architecture DIST_RAM_FIFO of FIFO is
    component DIST_RAM is
        generic(
            DATA_WIDTH      : natural := 8;
            DATA_DEPTH      : natural := 32;
            ADDRESS_WIDTH   : natural := 5
        );
        port(
            CLK     : in  std_logic;
            IN_ADDR : in  std_logic_vector(ADDRESS_WIDTH-1 downto 0);
            INPUT   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
            WRITE_EN: in  std_logic;
            OUT_ADDR: in std_logic_vector(ADDRESS_WIDTH-1 downto 0);
            OUTPUT  : out std_logic_vector(DATA_WIDTH-1 downto 0)
        );
    end component DIST_RAM;
    for all : DIST_RAM use entity WORK.DIST_RAM(BEH);
    
    -- Calculate the minimum address width
    constant ADDRESS_WIDTH  : natural := natural(ceil(log2(real(FIFO_DEPTH))));
    signal WRITE_PTR_cs     : std_logic_vector(ADDRESS_WIDTH-1 downto 0) := (others => '0');
    signal WRITE_PTR_ns     : std_logic_vector(ADDRESS_WIDTH-1 downto 0);
    signal READ_PTR_cs      : std_logic_vector(ADDRESS_WIDTH-1 downto 0) := (others => '0');
    signal READ_PTR_ns      : std_logic_vector(ADDRESS_WIDTH-1 downto 0);
    signal LOOPED_cs        : std_logic := '0';
    signal LOOPED_ns        : std_logic;
    signal EMPTY_cs         : std_logic := '1';
    signal EMPTY_ns         : std_logic;
    signal FULL_cs          : std_logic := '0';
    signal FULL_ns          : std_logic;
begin
    RAM_i : DIST_RAM
    generic map(
        DATA_WIDTH      => FIFO_WIDTH,
        DATA_DEPTH      => FIFO_DEPTH,
        ADDRESS_WIDTH   => ADDRESS_WIDTH
    )
    port map(
        CLK         => CLK,
        IN_ADDR     => WRITE_PTR_cs,
        INPUT       => INPUT,
        WRITE_EN    => WRITE_EN,
        OUT_ADDR    => READ_PTR_cs,
        OUTPUT      => OUTPUT
    );
    
    EMPTY <= EMPTY_cs;
    FULL  <= FULL_cs;
    
    FIFO_PROC:
    process(WRITE_PTR_cs, READ_PTR_cs, LOOPED_cs, EMPTY_cs, FULL_cs, WRITE_EN, NEXT_EN) is
        variable WRITE_PTR_v    : std_logic_vector(ADDRESS_WIDTH-1 downto 0);
        variable READ_PTR_v     : std_logic_vector(ADDRESS_WIDTH-1 downto 0);
        variable LOOPED_v       : std_logic;
        variable EMPTY_v        : std_logic;
        variable FULL_v         : std_logic;
        variable WRITE_EN_v     : std_logic;
        variable NEXT_EN_v      : std_logic;
    begin
        WRITE_PTR_v := WRITE_PTR_cs;
        READ_PTR_v  := READ_PTR_cs;
        LOOPED_v    := LOOPED_cs;
        EMPTY_v     := EMPTY_cs;
        FULL_v      := FULL_cs;
        WRITE_EN_v  := WRITE_EN;
        NEXT_EN_v   := NEXT_EN;
        
        if NEXT_EN_v = '1' and (WRITE_PTR_v /= READ_PTR_v or LOOPED_v = '1') then
            if READ_PTR_v = std_logic_vector(to_unsigned(FIFO_DEPTH-1, ADDRESS_WIDTH)) then
                READ_PTR_v := (others => '0');
                LOOPED_v := '0';
            else
                READ_PTR_v := std_logic_vector(unsigned(READ_PTR_v) + 1);
            end if;
        end if;
        
        if WRITE_EN_v = '1' and (WRITE_PTR_v /= READ_PTR_v or LOOPED_v = '0') then
            if WRITE_PTR_v = std_logic_vector(to_unsigned(FIFO_DEPTH-1, ADDRESS_WIDTH)) then
                WRITE_PTR_v := (others => '0');
                LOOPED_v := '1';
            else
                WRITE_PTR_v := std_logic_vector(unsigned(WRITE_PTR_v) + 1);
            end if;
        end if;
        
        if WRITE_PTR_v = READ_PTR_v then
            if LOOPED_v = '1' then
                EMPTY_v := EMPTY_v;
                FULL_v  := '1';
            else
                EMPTY_v := '1';
                FULL_v  := FULL_v;
            end if;
        else
            EMPTY_v := '0';
            FULL_v  := '0';
        end if;
        
        WRITE_PTR_ns    <= WRITE_PTR_v;
        READ_PTR_ns     <= READ_PTR_v;
        LOOPED_ns       <= LOOPED_v;
        EMPTY_ns        <= EMPTY_v;
        FULL_ns         <= FULL_v;
    end process FIFO_PROC;
    
    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                WRITE_PTR_cs <= (others => '0');
                READ_PTR_cs  <= (others => '0');
                LOOPED_cs    <= '0';
                EMPTY_cs     <= '1';
                FULL_cs      <= '0';
            else
                WRITE_PTR_cs <= WRITE_PTR_ns;
                READ_PTR_cs  <= READ_PTR_ns;
                LOOPED_cs    <= LOOPED_ns;
                EMPTY_cs     <= EMPTY_ns;
                FULL_cs      <= FULL_ns;
            end if;
        end if;
    end process SEQ_LOG;
end architecture DIST_RAM_FIFO;
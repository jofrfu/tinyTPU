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

--! @file MACC.vhdl
--! @author Jonas Fuhrmann
--! @brief Component which does a multiply-add operation with double buffered weights.
--! @details This component has two weight registers, which are configured as gated clock registers with seperate enable flags.
--! The second register is used for multiplication with the input register. The product is added to the LAST_SUM input, which defines the PARTIAL_SUM output register.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    
entity MACC is
    generic(
        -- The width of the last sum input
        LAST_SUM_WIDTH      : natural   := 0;
        -- The width of the output register
        PARTIAL_SUM_WIDTH   : natural   := 2*EXTENDED_BYTE_WIDTH
    );
    port(
        CLK, RESET      : in std_logic;
        ENABLE          : in std_logic;
        -- Weights - current and preload
        WEIGHT_INPUT    : in EXTENDED_BYTE_TYPE; --!< Input of the first weight register.
        PRELOAD_WEIGHT  : in std_logic; --!< First weight register enable or 'preload'.
        LOAD_WEIGHT     : in std_logic; --!< Second weight register enable or 'load'.
        -- Input
        INPUT           : in EXTENDED_BYTE_TYPE; --!< Input for the multiply-add operation.
        LAST_SUM        : in std_logic_vector(LAST_SUM_WIDTH-1 downto 0); --!< Input for accumulation.
        -- Output
        PARTIAL_SUM     : out std_logic_vector(PARTIAL_SUM_WIDTH-1 downto 0) --!< Output of partial sum register.
    );
end entity MACC;

--! @brief Architecture of the MACC component.
architecture BEH of MACC is

    -- Alternating weight registers
    signal PREWEIGHT_cs     : EXTENDED_BYTE_TYPE := (others => '0');
    signal PREWEIGHT_ns     : EXTENDED_BYTE_TYPE;
    
    signal WEIGHT_cs        : EXTENDED_BYTE_TYPE := (others => '0');
    signal WEIGHT_ns        : EXTENDED_BYTE_TYPE;
    
    -- Input register
    signal INPUT_cs         : EXTENDED_BYTE_TYPE := (others => '0');
    signal INPUT_ns         : EXTENDED_BYTE_TYPE;
    
    signal PIPELINE_cs      : MUL_HALFWORD_TYPE := (others => '0');
    signal PIPELINE_ns      : MUL_HALFWORD_TYPE;
    
    -- Result register
    signal PARTIAL_SUM_cs   : std_logic_vector(PARTIAL_SUM_WIDTH-1 downto 0) := (others => '0');
    signal PARTIAL_SUM_ns   : std_logic_vector(PARTIAL_SUM_WIDTH-1 downto 0);
    
    attribute use_dsp : string;
    attribute use_dsp of PARTIAL_SUM_ns : signal is "yes";

begin

    INPUT_ns        <= INPUT;
    
    PREWEIGHT_ns    <= WEIGHT_INPUT;
    WEIGHT_ns       <= PREWEIGHT_cs;
    
    MUL_ADD:
    process(INPUT_cs, WEIGHT_cs, PIPELINE_cs, LAST_SUM) is
        variable INPUT_v        : EXTENDED_BYTE_TYPE;
        variable WEIGHT_v       : EXTENDED_BYTE_TYPE;
        variable PIPELINE_cs_v  : MUL_HALFWORD_TYPE;
        variable PIPELINE_ns_v  : MUL_HALFWORD_TYPE;
        variable LAST_SUM_v     : std_logic_vector(LAST_SUM_WIDTH-1 downto 0);
        variable PARTIAL_SUM_v  : std_logic_vector(PARTIAL_SUM_WIDTH-1 downto 0);
    begin
        INPUT_v         := INPUT_cs;
        WEIGHT_v        := WEIGHT_cs;
        PIPELINE_cs_v   := PIPELINE_cs;
        LAST_SUM_v      := LAST_SUM;
        
        PIPELINE_ns_v := std_logic_vector(signed(INPUT_v) * signed(WEIGHT_v));
        
        -- Only ONE case will get synthesized!
        if LAST_SUM_WIDTH > 0 and LAST_SUM_WIDTH < PARTIAL_SUM_WIDTH then
            PARTIAL_SUM_v := std_logic_vector(signed(PIPELINE_cs_v(PIPELINE_cs_v'HIGH) & PIPELINE_cs_v) + signed(LAST_SUM_v(LAST_SUM_v'HIGH) & LAST_SUM_v));
        elsif LAST_SUM_WIDTH > 0 and LAST_SUM_WIDTH = PARTIAL_SUM_WIDTH then
            PARTIAL_SUM_v := std_logic_vector(signed(PIPELINE_cs_v) + signed(LAST_SUM_v));
        else -- LAST_SUM_WIDTH = 0
            PARTIAL_SUM_v := PIPELINE_cs_v;
        end if;
        
        PIPELINE_ns     <= PIPELINE_ns_v;
        PARTIAL_SUM_ns  <= PARTIAL_SUM_v;
    end process MUL_ADD;
    
    PARTIAL_SUM <= PARTIAL_SUM_cs;

    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                PREWEIGHT_cs    <= (others => '0');
                WEIGHT_cs       <= (others => '0');
                INPUT_cs        <= (others => '0');
                PIPELINE_cs     <= (others => '0');
                PARTIAL_SUM_cs  <= (others => '0');
            else
                if PRELOAD_WEIGHT = '1' then
                    PREWEIGHT_cs    <= PREWEIGHT_ns;
                end if;
                
                if LOAD_WEIGHT = '1' then
                    WEIGHT_cs       <= WEIGHT_ns;
                end if;
                
                if ENABLE = '1' then
                    INPUT_cs        <= INPUT_ns;
                    PIPELINE_cs     <= PIPELINE_ns;
                    PARTIAL_SUM_cs  <= PARTIAL_SUM_ns;
                end if;
            end if;
        end if;
    end process SEQ_LOG;
end architecture BEH;
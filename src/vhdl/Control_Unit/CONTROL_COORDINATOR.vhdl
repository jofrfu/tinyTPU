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

--! @file CONTROL_COORDINATOR.vhdl
--! @author Jonas Fuhrmann
--! @brief This component coordinates all control units.
--! @details The control coordinator dispatches instructions to the appropriate control unit at the right time
--! and waits for each unit to be finished before feeding new instructions.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    
entity CONTROL_COORDINATOR is
    port(
        CLK, RESET                  :  in std_logic;
        ENABLE                      :  in std_logic;
            
        INSTRUCTION                 :  in INSTRUCTION_TYPE; --!< The instruction to be dispatched.
        INSTRUCTION_EN              :  in std_logic; --!< Enable for instruction.
        
        BUSY                        : out std_logic; --!< One unit is still busy while a new instruction was feeded for this exact unit.
        
        WEIGHT_BUSY                 :  in std_logic; --!< Busy input for the weight control unit.
        WEIGHT_RESOURCE_BUSY        :  in std_logic; --!< Resource busy input for the weight control unit.
        WEIGHT_INSTRUCTION          : out WEIGHT_INSTRUCTION_TYPE; --!< Instruction output for the weight control unit.
        WEIGHT_INSTRUCTION_EN       : out std_logic; --!< Instruction enable for the weight control unit.
        
        MATRIX_BUSY                 :  in std_logic; --!< Busy input for the matrix multiply control unit.
        MATRIX_RESOURCE_BUSY        :  in std_logic; --!< Resource busy input for the matrix multiply control unit.
        MATRIX_INSTRUCTION          : out INSTRUCTION_TYPE; --!< Instruction output for the matrix multiply control unit.
        MATRIX_INSTRUCTION_EN       : out std_logic; --!< Instruction enable for the matrix multiply control unit.
        
        ACTIVATION_BUSY             :  in std_logic; --!< Busy input for the activation control unit.
        ACTIVATION_RESOURCE_BUSY    :  in std_logic; --!< Resource busy input for the activation control unit.
        ACTIVATION_INSTRUCTION      : out INSTRUCTION_TYPE; --!< Instruction output for the activation control unit.
        ACTIVATION_INSTRUCTION_EN   : out std_logic; --!< Instruction enable for the activation control unit.
        
        SYNCHRONIZE                 : out std_logic --!< Will be asserted, when a synchronize instruction was feeded and all units are finished.
    );
end entity CONTROL_COORDINATOR;

--! @brief The architecture of the control coordinator component.
architecture BEH of CONTROL_COORDINATOR is    
    signal EN_FLAGS_cs : std_logic_vector(0 to 3) := (others => '0'); -- Decoded enable - 0: WEIGHT 1: MATRIX 2: ACTIVATION 3: SYNCHRONIZE
    signal EN_FLAGS_ns : std_logic_vector(0 to 3);
    
    signal INSTRUCTION_cs : INSTRUCTION_TYPE := INIT_INSTRUCTION;
    signal INSTRUCTION_ns : INSTRUCTION_TYPE;
    
    signal INSTRUCTION_EN_cs : std_logic := '0';
    signal INSTRUCTION_EN_ns : std_logic;
    
    signal INSTRUCTION_RUNNING : std_logic;
begin
    INSTRUCTION_ns <= INSTRUCTION;
    INSTRUCTION_EN_ns <= INSTRUCTION_EN;
    BUSY <= INSTRUCTION_RUNNING;
    
    DECODE:
    process(INSTRUCTION) is
        variable INSTRUCTION_v : INSTRUCTION_TYPE;
        
        variable EN_FLAGS_ns_v : std_logic_vector(0 to 3);
        variable SET_SYNCHRONIZE_v : std_logic;
    begin
        INSTRUCTION_v := INSTRUCTION;

        if    INSTRUCTION_v.OP_CODE  = x"FF" then -- synchronize
            EN_FLAGS_ns_v := "0001";
        elsif INSTRUCTION_v.OP_CODE(7) = '1' then -- activate
            EN_FLAGS_ns_v := "0010";
        elsif INSTRUCTION_v.OP_CODE(5) = '1' then -- matrix_multiply
            EN_FLAGS_ns_v := "0100";
        elsif INSTRUCTION_v.OP_CODE(3) = '1' then -- load_weight
            EN_FLAGS_ns_v := "1000";
        else -- probably nop
            EN_FLAGS_ns_v := "0000";
        end if;
        
        EN_FLAGS_ns <= EN_FLAGS_ns_v;
    end process DECODE;
    
    RUNNING_DETECT:
    process(INSTRUCTION_cs, INSTRUCTION_EN_cs, EN_FLAGS_cs, WEIGHT_BUSY, MATRIX_BUSY, ACTIVATION_BUSY, WEIGHT_RESOURCE_BUSY, MATRIX_RESOURCE_BUSY, ACTIVATION_RESOURCE_BUSY) is
        variable INSTRUCTION_v      : INSTRUCTION_TYPE;
        variable INSTRUCTION_EN_v   : std_logic;
        variable EN_FLAGS_v         : std_logic_vector(0 to 3);
        variable WEIGHT_BUSY_v      : std_logic;
        variable MATRIX_BUSY_v      : std_logic;
        variable ACTIVATION_BUSY_v  : std_logic;
        variable WEIGHT_RESOURCE_BUSY_v     : std_logic;
        variable MATRIX_RESOURCE_BUSY_v     : std_logic;
        variable ACTIVATION_RESOURCE_BUSY_v : std_logic;
        
        variable WEIGHT_INSTRUCTION_EN_v        : std_logic;
        variable MATRIX_INSTRUCTION_EN_v        : std_logic;
        variable ACTIVATION_INSTRUCTION_EN_v    : std_logic;
        variable INSTRUCTION_RUNNING_v          : std_logic;
        variable SYNCHRONIZE_v                  : std_logic;
    begin
        INSTRUCTION_v       := INSTRUCTION_cs;
        INSTRUCTION_EN_v    := INSTRUCTION_EN_cs;
        EN_FLAGS_v          := EN_FLAGS_cs;
        WEIGHT_BUSY_v       := WEIGHT_BUSY;
        MATRIX_BUSY_v       := MATRIX_BUSY;
        ACTIVATION_BUSY_v   := ACTIVATION_BUSY;
        WEIGHT_RESOURCE_BUSY_v     := WEIGHT_RESOURCE_BUSY;
        MATRIX_RESOURCE_BUSY_v     := MATRIX_RESOURCE_BUSY;
        ACTIVATION_RESOURCE_BUSY_v := ACTIVATION_RESOURCE_BUSY;
        
        if INSTRUCTION_EN_v = '1' then
            if EN_FLAGS_v(3) = '1' then
                if WEIGHT_RESOURCE_BUSY_v     = '1'
                or MATRIX_RESOURCE_BUSY_v     = '1'
                or ACTIVATION_RESOURCE_BUSY_v = '1' then
                    INSTRUCTION_RUNNING_v       := '1';
                    WEIGHT_INSTRUCTION_EN_v     := '0';
                    MATRIX_INSTRUCTION_EN_v     := '0';
                    ACTIVATION_INSTRUCTION_EN_v := '0';
                    SYNCHRONIZE_v               := '0';
                else
                    INSTRUCTION_RUNNING_v       := '0';
                    WEIGHT_INSTRUCTION_EN_v     := '0';
                    MATRIX_INSTRUCTION_EN_v     := '0';
                    ACTIVATION_INSTRUCTION_EN_v := '0';
                    SYNCHRONIZE_v               := '1';
                end if;
            else
                if (WEIGHT_BUSY_v     = '1' and  EN_FLAGS_v(0) = '1')
                or (MATRIX_BUSY_v     = '1' and (EN_FLAGS_v(1) = '1' or EN_FLAGS_v(2) = '1')) -- Activation waits for matrix multiply to finish
                or (ACTIVATION_BUSY_v = '1' and  EN_FLAGS_v(2) = '1') then
                    INSTRUCTION_RUNNING_v       := '1';
                    WEIGHT_INSTRUCTION_EN_v     := '0';
                    MATRIX_INSTRUCTION_EN_v     := '0';
                    ACTIVATION_INSTRUCTION_EN_v := '0';
                    SYNCHRONIZE_v               := '0';
                else
                    INSTRUCTION_RUNNING_v       := '0';
                    WEIGHT_INSTRUCTION_EN_v     := EN_FLAGS_v(0);
                    MATRIX_INSTRUCTION_EN_v     := EN_FLAGS_v(1);
                    ACTIVATION_INSTRUCTION_EN_v := EN_FLAGS_v(2);
                    SYNCHRONIZE_v               := '0';
                end if;
            end if;
        else
            INSTRUCTION_RUNNING_v       := '0';
            WEIGHT_INSTRUCTION_EN_v     := '0';
            MATRIX_INSTRUCTION_EN_v     := '0';
            ACTIVATION_INSTRUCTION_EN_v := '0';
            SYNCHRONIZE_v               := '0';
        end if;
        
        INSTRUCTION_RUNNING         <= INSTRUCTION_RUNNING_v;
        WEIGHT_INSTRUCTION_EN       <= WEIGHT_INSTRUCTION_EN_v;
        MATRIX_INSTRUCTION_EN       <= MATRIX_INSTRUCTION_EN_v;
        ACTIVATION_INSTRUCTION_EN   <= ACTIVATION_INSTRUCTION_EN_v;
        SYNCHRONIZE                 <= SYNCHRONIZE_v;
    end process RUNNING_DETECT;
        
    WEIGHT_INSTRUCTION      <= TO_WEIGHT_INSTRUCTION(INSTRUCTION_cs);
    MATRIX_INSTRUCTION      <= INSTRUCTION_cs;
    ACTIVATION_INSTRUCTION  <= INSTRUCTION_cs;

    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                EN_FLAGS_cs <= (others => '0');
                INSTRUCTION_cs <= INIT_INSTRUCTION;
                INSTRUCTION_EN_cs <= '0';
            else
                if INSTRUCTION_RUNNING = '0' and ENABLE = '1' then
                    EN_FLAGS_cs <= EN_FLAGS_ns;
                    INSTRUCTION_cs <= INSTRUCTION_ns;
                    INSTRUCTION_EN_cs <= INSTRUCTION_EN_ns;
                end if;
            end if;
        end if;
    end process SEQ_LOG;
end architecture BEH;
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

--! @file ACTIVATION_CONTROL.vhdl
--! @author Jonas Fuhrmann
--! @brief This component includes the control unit for the activation operation.
--! @details This unit controls the data flow from the accumulaotrs, pipes it through the activation component and stores the results back in the unified buffer.
--! Instructions will be executed delayed, so a previous matrix multiply can be finished just in time.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    
entity ACTIVATION_CONTROL is
    generic(
        MATRIX_WIDTH        : natural := 14
    );
    port(
        CLK, RESET          :  in std_logic;
        ENABLE              :  in std_logic;
        
        INSTRUCTION         :  in INSTRUCTION_TYPE; --!< The activation instruction to be executed.
        INSTRUCTION_EN      :  in std_logic; --!< Enable for instruction.
        
        ACC_TO_ACT_ADDR     : out ACCUMULATOR_ADDRESS_TYPE; --!< Address for the accumulators
        ACTIVATION_FUNCTION : out ACTIVATION_BIT_TYPE; --!< The type of activation function to be calculated.
        SIGNED_NOT_UNSIGNED : out std_logic; --!< Determines if the input and output is signed or unsigned.
        
        ACT_TO_BUF_ADDR     : out BUFFER_ADDRESS_TYPE; --!< Address for the unified buffer.
        BUF_WRITE_EN        : out std_logic; --!< Write enable flag for the unified buffer.
        
        BUSY                : out std_logic;  --!< If the control unit is busy, a new instruction shouldn't be feeded.
        RESOURCE_BUSY       : out std_logic --!< The resources are in use and the instruction is not fully finished yet.
    );
end entity ACTIVATION_CONTROL;

--! @brief The architecture of the activation control unit.
architecture BEH of ACTIVATION_CONTROL is

    -- CONTROL: 3 clock cylces
    -- MATRIX_MULTPLY_UNIT: MATRIX_WIDTH+2 clock cycles
    -- REGISTER_FILE: 7 clock cycles
    -- ACTIVATION: 3 clock cycles

    type ACCUMULATOR_ADDRESS_ARRAY_TYPE is array(0 to 3+MATRIX_WIDTH+2-1) of ACCUMULATOR_ADDRESS_TYPE;
    type ACTIVATION_BIT_ARRAY_TYPE is array(0 to 3+MATRIX_WIDTH+2+7-1) of ACTIVATION_BIT_TYPE;
    type BUFFER_ADDRESS_ARRAY_TYPE is array(0 to 3+MATRIX_WIDTH+2+7+3-1) of BUFFER_ADDRESS_TYPE;

    component COUNTER is
        generic(
            COUNTER_WIDTH   : natural := 32
        );
        port(
            CLK, RESET  : in  std_logic;
            ENABLE      : in  std_logic;
            
            END_VAL     : in  std_logic_vector(COUNTER_WIDTH-1 downto 0);
            LOAD        : in  std_logic;
            
            COUNT_VAL   : out std_logic_vector(COUNTER_WIDTH-1 downto 0);
            
            COUNT_EVENT : out std_logic
        );
    end component COUNTER;
    for all : COUNTER use entity WORK.DSP_COUNTER(BEH);
    
    component LOAD_COUNTER is
        generic(
            COUNTER_WIDTH   : natural := 32
        );
        port(
            CLK, RESET  : in  std_logic;
            ENABLE      : in  std_logic;
            
            START_VAL   : in  std_logic_vector(COUNTER_WIDTH-1 downto 0);
            LOAD        : in  std_logic;
            
            COUNT_VAL   : out std_logic_vector(COUNTER_WIDTH-1 downto 0)
        );
    end component LOAD_COUNTER;
    for all : LOAD_COUNTER use entity WORK.DSP_LOAD_COUNTER(BEH);
    
    signal ACC_TO_ACT_ADDR_cs : ACCUMULATOR_ADDRESS_TYPE := (others => '0');
    signal ACC_TO_ACT_ADDR_ns : ACCUMULATOR_ADDRESS_TYPE;
    
    signal ACT_TO_BUF_ADDR_cs : BUFFER_ADDRESS_TYPE := (others => '0');
    signal ACT_TO_BUF_ADDR_ns : BUFFER_ADDRESS_TYPE;
    
    signal ACTIVATION_FUNCTION_cs : ACTIVATION_BIT_TYPE := (others => '0');
    signal ACTIVATION_FUNCTION_ns : ACTIVATION_BIT_TYPE;
    
    signal SIGNED_NOT_UNSIGNED_cs : std_logic := '0';
    signal SIGNED_NOT_UNSIGNED_ns : std_logic;

    signal BUF_WRITE_EN_cs : std_logic := '0';
    signal BUF_WRITE_EN_ns : std_logic;
    
    signal RUNNING_cs : std_logic := '0';
    signal RUNNING_ns : std_logic;
    
    signal RUNNING_PIPE_cs : std_logic_vector(0 to 3+MATRIX_WIDTH+2+7+3-1) := (others => '0');
    signal RUNNING_PIPE_ns : std_logic_vector(0 to 3+MATRIX_WIDTH+2+7+3-1);
    
    signal ACT_LOAD  : std_logic;
    signal ACT_RESET : std_logic;
    
    --
    signal BUF_WRITE_EN_DELAY_cs : std_logic_vector(0 to 2) := (others => '0');
    signal BUF_WRITE_EN_DELAY_ns : std_logic_vector(0 to 2);
    
    signal SIGNED_DELAY_cs : std_logic_vector(0 to 2) := (others => '0');
    signal SIGNED_DELAY_ns : std_logic_vector(0 to 2);
    
    signal ACTIVATION_PIPE0_cs : ACTIVATION_BIT_TYPE := (others => '0');
    signal ACTIVATION_PIPE0_ns : ACTIVATION_BIT_TYPE;
    
    signal ACTIVATION_PIPE1_cs : ACTIVATION_BIT_TYPE := (others => '0');
    signal ACTIVATION_PIPE1_ns : ACTIVATION_BIT_TYPE;
    
    signal ACTIVATION_PIPE2_cs : ACTIVATION_BIT_TYPE := (others => '0');
    signal ACTIVATION_PIPE2_ns : ACTIVATION_BIT_TYPE;
    
    -- LENGTH_COUNTER signals
    signal LENGTH_RESET     : std_logic;
    signal LENGTH_END_VAL   : LENGTH_TYPE;
    signal LENGTH_LOAD      : std_logic;
    signal LENGTH_EVENT     : std_logic;
    
    -- ADDRESS_COUNTER signals
    signal ADDRESS_LOAD     : std_logic;
    
    -- delay register
    signal ACC_ADDRESS_DELAY_cs : ACCUMULATOR_ADDRESS_ARRAY_TYPE := (others => (others => '0'));
    signal ACC_ADDRESS_DELAY_ns : ACCUMULATOR_ADDRESS_ARRAY_TYPE;
    
    signal ACTIVATION_DELAY_cs  : ACTIVATION_BIT_ARRAY_TYPE := (others => (others => '0'));
    signal ACTIVATION_DELAY_ns  : ACTIVATION_BIT_ARRAY_TYPE;
    
    signal S_NOT_U_DELAY_cs     : std_logic_vector(0 to 3+MATRIX_WIDTH+2+7-1) := (others => '0');
    signal S_NOT_U_DELAY_ns     : std_logic_vector(0 to 3+MATRIX_WIDTH+2+7-1);
    
    signal ACT_TO_BUF_DELAY_cs  : BUFFER_ADDRESS_ARRAY_TYPE := (others => (others => '0'));
    signal ACT_TO_BUF_DELAY_ns  : BUFFER_ADDRESS_ARRAY_TYPE;
    
    signal WRITE_EN_DELAY_cs    : std_logic_vector(0 to 3+MATRIX_WIDTH+2+7+3-1) := (others => '0');
    signal WRITE_EN_DELAY_ns    : std_logic_vector(0 to 3+MATRIX_WIDTH+2+7+3-1);
begin
    
    ACC_ADDRESS_DELAY_ns(1 to 3+MATRIX_WIDTH+2-1) <= ACC_ADDRESS_DELAY_cs(0 to 3+MATRIX_WIDTH+2-2);
    ACTIVATION_DELAY_ns(1 to 3+MATRIX_WIDTH+2+7-1) <= ACTIVATION_DELAY_cs(0 to 3+MATRIX_WIDTH+2+7-2);
    S_NOT_U_DELAY_ns(1 to 3+MATRIX_WIDTH+2+7-1) <= S_NOT_U_DELAY_cs(0 to 3+MATRIX_WIDTH+2+7-2);
    ACT_TO_BUF_DELAY_ns(1 to 3+MATRIX_WIDTH+2+7+3-1) <= ACT_TO_BUF_DELAY_cs(0 to 3+MATRIX_WIDTH+2+7+3-2);
    WRITE_EN_DELAY_ns(1 to 3+MATRIX_WIDTH+2+7+3-1) <= WRITE_EN_DELAY_cs(0 to 3+MATRIX_WIDTH+2+7+3-2);
    
    ACC_TO_ACT_ADDR <= ACC_ADDRESS_DELAY_cs(3+MATRIX_WIDTH+2-1);
    ACTIVATION_FUNCTION <=ACTIVATION_DELAY_cs(3+MATRIX_WIDTH+2+7-1);
    SIGNED_NOT_UNSIGNED <= S_NOT_U_DELAY_cs(3+MATRIX_WIDTH+2+7-1);
    ACT_TO_BUF_ADDR <= ACT_TO_BUF_DELAY_cs(3+MATRIX_WIDTH+2+7+3-1);
    BUF_WRITE_EN <= WRITE_EN_DELAY_cs(3+MATRIX_WIDTH+2+7+3-1);

    LENGTH_COUNTER_i : COUNTER
    generic map(
        COUNTER_WIDTH => LENGTH_WIDTH
    )
    port map(
        CLK         => CLK,
        RESET       => LENGTH_RESET,
        ENABLE      => ENABLE,
        END_VAL     => INSTRUCTION.CALC_LENGTH,
        LOAD        => LENGTH_LOAD,
        COUNT_EVENT => LENGTH_EVENT
    );
    
    ADDRESS_COUNTER0_i : LOAD_COUNTER
    generic map(
        COUNTER_WIDTH => ACCUMULATOR_ADDRESS_WIDTH
    )
    port map(
        CLK         => CLK,
        RESET       => RESET,
        ENABLE      => ENABLE,
        START_VAL   => INSTRUCTION.ACC_ADDRESS,
        LOAD        => ADDRESS_LOAD,
        COUNT_VAL   => ACC_TO_ACT_ADDR_ns
    );
    
    ADDRESS_COUNTER1_i : LOAD_COUNTER
    generic map(
        COUNTER_WIDTH => BUFFER_ADDRESS_WIDTH
    )
    port map(
        CLK         => CLK,
        RESET       => RESET,
        ENABLE      => ENABLE,
        START_VAL   => INSTRUCTION.BUFFER_ADDRESS,
        LOAD        => ADDRESS_LOAD,
        COUNT_VAL   => ACT_TO_BUF_ADDR_ns
    );
    
    SIGNED_NOT_UNSIGNED_ns <= INSTRUCTION.OP_CODE(4);
    ACTIVATION_FUNCTION_ns <= INSTRUCTION.OP_CODE(3 downto 0);
    
    ACTIVATION_DELAY_ns(0)  <= "0000" when ACTIVATION_FUNCTION_cs = "0000" else ACTIVATION_PIPE2_cs;
    S_NOT_U_DELAY_ns(0)     <= '0' when SIGNED_NOT_UNSIGNED_cs = '0' else SIGNED_DELAY_cs(2);
    WRITE_EN_DELAY_ns(0)    <= '0' when BUF_WRITE_EN_cs = '0' else BUF_WRITE_EN_DELAY_cs(2);
    
    BUSY <= RUNNING_cs;
    RUNNING_PIPE_ns(0) <= RUNNING_cs;
    RUNNING_PIPE_ns(1 to 3+MATRIX_WIDTH+2+7+3-1) <= RUNNING_PIPE_cs(0 to 3+MATRIX_WIDTH+2+7+2-1);
    
    ACC_ADDRESS_DELAY_ns(0) <= ACC_TO_ACT_ADDR_cs;
    ACT_TO_BUF_DELAY_ns(0) <= ACT_TO_BUF_ADDR_cs;
    
    BUF_WRITE_EN_DELAY_ns(0)        <= BUF_WRITE_EN_cs;
    SIGNED_DELAY_ns(0)              <= SIGNED_NOT_UNSIGNED_cs;
    ACTIVATION_PIPE0_ns             <= ACTIVATION_FUNCTION_cs;
    BUF_WRITE_EN_DELAY_ns(1 to 2)   <= BUF_WRITE_EN_DELAY_cs(0 to 1);
    SIGNED_DELAY_ns(1 to 2)         <= SIGNED_DELAY_cs(0 to 1);
    ACTIVATION_PIPE1_ns             <= ACTIVATION_PIPE0_cs;
    ACTIVATION_PIPE2_ns             <= ACTIVATION_PIPE1_cs;
    
    RESOURCE:
    process(RUNNING_cs, RUNNING_PIPE_cs) is
        variable RESOURCE_BUSY_v : std_logic;
    begin
        RESOURCE_BUSY_v := RUNNING_cs;
        for i in 0 to 3+MATRIX_WIDTH+2+7+3-1 loop
            RESOURCE_BUSY_v := RESOURCE_BUSY_v or RUNNING_PIPE_cs(i);
        end loop;
        RESOURCE_BUSY <= RESOURCE_BUSY_v;
    end process RESOURCE;
    
    CONTROL:
    process(INSTRUCTION, INSTRUCTION_EN, RUNNING_cs, LENGTH_EVENT) is
        variable INSTRUCTION_v      : INSTRUCTION_TYPE;
        variable INSTRUCTION_EN_v   : std_logic;
        variable RUNNING_cs_v       : std_logic;
        variable LENGTH_EVENT_v     : std_logic;
        
        variable RUNNING_ns_v       : std_logic;
        variable ADDRESS_LOAD_v     : std_logic;
        variable BUF_WRITE_EN_ns_v  : std_logic;
        variable LENGTH_LOAD_v      : std_logic;
        variable LENGTH_RESET_v     : std_logic;
        variable ACT_LOAD_v         : std_logic;
        variable ACT_RESET_v        : std_logic;
    begin
        INSTRUCTION_v       := INSTRUCTION;
        INSTRUCTION_EN_v    := INSTRUCTION_EN;
        RUNNING_cs_v        := RUNNING_cs;
        LENGTH_EVENT_v      := LENGTH_EVENT;
    
        if RUNNING_cs_v = '0' then
            if INSTRUCTION_EN_v = '1' then
                RUNNING_ns_v        := '1';
                ADDRESS_LOAD_v      := '1';
                BUF_WRITE_EN_ns_v   := '1';
                LENGTH_LOAD_v       := '1';
                LENGTH_RESET_v      := '1';
                ACT_LOAD_v          := '1';
                ACT_RESET_v         := '0';
            else
                RUNNING_ns_v        := '0';
                ADDRESS_LOAD_v      := '0';
                BUF_WRITE_EN_ns_v   := '0';
                LENGTH_LOAD_v       := '0';
                LENGTH_RESET_v      := '0';
                ACT_LOAD_v          := '0';
                ACT_RESET_v         := '0';
            end if;
        else
            if LENGTH_EVENT_v = '1' then
                RUNNING_ns_v        := '0';
                ADDRESS_LOAD_v      := '0';
                BUF_WRITE_EN_ns_v   := '0';
                LENGTH_LOAD_v       := '0';
                LENGTH_RESET_v      := '0';
                ACT_LOAD_v          := '0';
                ACT_RESET_v         := '1';
            else
                RUNNING_ns_v        := '1';
                ADDRESS_LOAD_v      := '0';
                BUF_WRITE_EN_ns_v   := '1';
                LENGTH_LOAD_v       := '0';
                LENGTH_RESET_v      := '0';
                ACT_LOAD_v          := '0';
                ACT_RESET_v         := '0';
            end if;
        end if;
        
        RUNNING_ns          <=  RUNNING_ns_v;
        ADDRESS_LOAD        <=  ADDRESS_LOAD_v;
        BUF_WRITE_EN_ns     <=  BUF_WRITE_EN_ns_v;
        LENGTH_LOAD         <=  LENGTH_LOAD_v;
        LENGTH_RESET        <=  LENGTH_RESET_v;
        ACT_LOAD            <=  ACT_LOAD_v;
        ACT_RESET           <=  ACT_RESET_v;
    end process CONTROL;

    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                BUF_WRITE_EN_cs <= '0';
                RUNNING_cs      <= '0';
                RUNNING_PIPE_cs <= (others => '0');
                ACC_TO_ACT_ADDR_cs <= (others => '0');
                ACT_TO_BUF_ADDR_cs <= (others => '0');
                BUF_WRITE_EN_DELAY_cs   <= (others => '0');
                SIGNED_DELAY_cs         <= (others => '0');
                ACTIVATION_PIPE0_cs     <= (others => '0');
                ACTIVATION_PIPE1_cs     <= (others => '0');
                ACTIVATION_PIPE2_cs     <= (others => '0');
                -- delay register
                ACC_ADDRESS_DELAY_cs    <= (others => (others => '0'));
                ACTIVATION_DELAY_cs     <= (others => (others => '0'));
                S_NOT_U_DELAY_cs        <= (others => '0');
                ACT_TO_BUF_DELAY_cs     <= (others => (others => '0'));
                WRITE_EN_DELAY_cs       <= (others => '0');
            else
                if ENABLE = '1' then
                    BUF_WRITE_EN_cs <= BUF_WRITE_EN_ns;
                    RUNNING_cs      <= RUNNING_ns;
                    RUNNING_PIPE_cs <= RUNNING_PIPE_ns;
                    ACC_TO_ACT_ADDR_cs <= ACC_TO_ACT_ADDR_ns;
                    ACT_TO_BUF_ADDR_cs <= ACT_TO_BUF_ADDR_ns;
                    BUF_WRITE_EN_DELAY_cs   <= BUF_WRITE_EN_DELAY_ns;
                    SIGNED_DELAY_cs         <= SIGNED_DELAY_ns;
                    ACTIVATION_PIPE0_cs     <= ACTIVATION_PIPE0_ns;
                    ACTIVATION_PIPE1_cs     <= ACTIVATION_PIPE1_ns;
                    ACTIVATION_PIPE2_cs     <= ACTIVATION_PIPE2_ns;
                    -- delay register
                    ACC_ADDRESS_DELAY_cs    <= ACC_ADDRESS_DELAY_ns;
                    ACTIVATION_DELAY_cs     <= ACTIVATION_DELAY_ns;
                    S_NOT_U_DELAY_cs        <= S_NOT_U_DELAY_ns;
                    ACT_TO_BUF_DELAY_cs     <= ACT_TO_BUF_DELAY_ns;
                    WRITE_EN_DELAY_cs       <= WRITE_EN_DELAY_ns;
                end if;
            end if;
            
            if ACT_RESET = '1' then
                ACTIVATION_FUNCTION_cs  <= (others => '0');
                SIGNED_NOT_UNSIGNED_cs  <= '0';
            else
                if ACT_LOAD = '1' then
                    ACTIVATION_FUNCTION_cs  <= ACTIVATION_FUNCTION_ns;
                    SIGNED_NOT_UNSIGNED_cs  <= SIGNED_NOT_UNSIGNED_ns;
                end if;
            end if;
        end if;
    end process SEQ_LOG;
end architecture BEH;

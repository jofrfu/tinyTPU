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

--! @file WEIGHT_CONTROL.vhdl
--! @author Jonas Fuhrmann
--! @brief This component includes the control unit for weight loading.
--! @details Weights are read from the weight buffer and get stored sequentially in the matrix multiply unit.
--! If the control unit gets to the end of the preweight registers of the matrix multiply unit, it restarts loading the next batch of values.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    use IEEE.math_real.log2;
    use IEEE.math_real.ceil;
    
entity WEIGHT_CONTROL is
    generic(
        MATRIX_WIDTH            : natural := 14
    );
    port(
        CLK, RESET              :  in std_logic;
        ENABLE                  :  in std_logic;
    
        INSTRUCTION             :  in WEIGHT_INSTRUCTION_TYPE; --!< The weight instruction to be executed.
        INSTRUCTION_EN          :  in std_logic; --!< Enable for instruction.
        
        WEIGHT_READ_EN          : out std_logic; --!< Read enable flag for weight buffer.
        WEIGHT_BUFFER_ADDRESS   : out WEIGHT_ADDRESS_TYPE; --!< Address for weight buffer read.
        
        LOAD_WEIGHT             : out std_logic; --!< Load weight flag for matrix multiply unit.
        WEIGHT_ADDRESS          : out BYTE_TYPE; --!< Address of the weight for matrix multiply unit.
        
        WEIGHT_SIGNED           : out std_logic; --!< Determines if the weights are signed or unsigned.
                
        BUSY                    : out std_logic; --!< If the control unit is busy, a new instruction shouldn't be feeded.
        RESOURCE_BUSY           : out std_logic --!< The resources are in use and the instruction is not fully finished yet.
    );
end entity WEIGHT_CONTROL;

--! @brief The architecture of the weight control unit.
architecture BEH of WEIGHT_CONTROL is
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

    signal WEIGHT_READ_EN_cs        : std_logic := '0';
    signal WEIGHT_READ_EN_ns        : std_logic;
    
    signal LOAD_WEIGHT_cs           : std_logic_vector(0 to 2) := (others => '0');
    signal LOAD_WEIGHT_ns           : std_logic_vector(0 to 2);
    
    signal WEIGHT_SIGNED_cs         : std_logic := '0';
    signal WEIGHT_SIGNED_ns         : std_logic;
    
    signal SIGNED_PIPE_cs           : std_logic_vector(0 to 2) := (others => '0');
    signal SIGNED_PIPE_ns           : std_logic_vector(0 to 2);
    
    signal SIGNED_LOAD              : std_logic;
    signal SIGNED_RESET             : std_logic;

    constant WEIGHT_COUNTER_WIDTH   : natural := natural(ceil(log2(real(MATRIX_WIDTH-1))));
    signal WEIGHT_ADDRESS_cs        : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal WEIGHT_ADDRESS_ns        : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0);
    
    signal WEIGHT_PIPE0_cs          : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal WEIGHT_PIPE0_ns          : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0);
    
    signal WEIGHT_PIPE1_cs          : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal WEIGHT_PIPE1_ns          : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0);
    
    signal WEIGHT_PIPE2_cs          : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal WEIGHT_PIPE2_ns          : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0);
    
    signal WEIGHT_PIPE3_cs          : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal WEIGHT_PIPE3_ns          : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0);
    
    signal WEIGHT_PIPE4_cs          : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal WEIGHT_PIPE4_ns          : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0);
    
    signal WEIGHT_PIPE5_cs          : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal WEIGHT_PIPE5_ns          : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0);
    
    signal BUFFER_PIPE_cs           : WEIGHT_ADDRESS_TYPE := (others => '0');
    signal BUFFER_PIPE_ns           : WEIGHT_ADDRESS_TYPE;
    
    signal READ_PIPE0_cs            : std_logic := '0';
    signal READ_PIPE0_ns            : std_logic;
    
    signal READ_PIPE1_cs            : std_logic := '0';
    signal READ_PIPE1_ns            : std_logic;
    
    signal READ_PIPE2_cs            : std_logic := '0';
    signal READ_PIPE2_ns            : std_logic;
        
    signal RUNNING_cs : std_logic := '0';
    signal RUNNING_ns : std_logic;
    
    signal RUNNING_PIPE_cs : std_logic_vector(0 to 2) := (others => '0');
    signal RUNNING_PIPE_ns : std_logic_vector(0 to 2);
    
    -- LENGTH_COUNTER signals
    signal LENGTH_RESET     : std_logic;
    signal LENGTH_LOAD      : std_logic;
    signal LENGTH_EVENT     : std_logic;
    
    -- ADDRESS_COUNTER signals
    signal ADDRESS_LOAD     : std_logic;
begin
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
    
    ADDRESS_COUNTER_i : LOAD_COUNTER
    generic map(
        COUNTER_WIDTH => WEIGHT_ADDRESS_WIDTH
    )
    port map(
        CLK         => CLK,
        RESET       => RESET,
        ENABLE      => ENABLE,
        START_VAL   => INSTRUCTION.WEIGHT_ADDRESS,
        LOAD        => ADDRESS_LOAD,
        COUNT_VAL   => BUFFER_PIPE_ns
    );

    READ_PIPE0_ns   <= WEIGHT_READ_EN_cs;
    READ_PIPE1_ns   <= READ_PIPE0_cs;
    READ_PIPE2_ns   <= READ_PIPE1_cs;
    WEIGHT_READ_EN  <= '0' when WEIGHT_READ_EN_cs = '0' else READ_PIPE2_cs;
    
    -- Weight buffer read takes 3 clock cycles
    LOAD_WEIGHT_ns(0)       <= '0' when WEIGHT_READ_EN_cs = '0' else READ_PIPE2_cs;
    LOAD_WEIGHT_ns(1 to 2)  <= LOAD_WEIGHT_cs(0 to 1);
    LOAD_WEIGHT             <= LOAD_WEIGHT_cs(2);
    
    WEIGHT_SIGNED_ns    <= INSTRUCTION.OP_CODE(0);
    SIGNED_PIPE_ns(0)   <= WEIGHT_SIGNED_cs;
    SIGNED_PIPE_ns(1)   <= SIGNED_PIPE_cs(0);
    SIGNED_PIPE_ns(2)   <= SIGNED_PIPE_cs(1);
    WEIGHT_SIGNED       <= '0' when LOAD_WEIGHT_cs(2) = '0' else SIGNED_PIPE_cs(2);
    
    WEIGHT_PIPE0_ns <= WEIGHT_ADDRESS_cs;
    WEIGHT_PIPE1_ns <= WEIGHT_PIPE0_cs;
    WEIGHT_PIPE2_ns <= WEIGHT_PIPE1_cs;
    WEIGHT_PIPE3_ns <= WEIGHT_PIPE2_cs;
    WEIGHT_PIPE4_ns <= WEIGHT_PIPE3_cs;
    WEIGHT_PIPE5_ns <= WEIGHT_PIPE4_cs;
    WEIGHT_ADDRESS(WEIGHT_COUNTER_WIDTH-1 downto 0) <= WEIGHT_PIPE5_cs;
    WEIGHT_ADDRESS(BYTE_WIDTH-1 downto WEIGHT_COUNTER_WIDTH) <= (others => '0');
    
    WEIGHT_BUFFER_ADDRESS <= BUFFER_PIPE_cs;

    BUSY <= RUNNING_cs;
    RUNNING_PIPE_ns(0) <= RUNNING_cs;
    RUNNING_PIPE_ns(1 to 2) <= RUNNING_PIPE_cs(0 to 1);
    
    RESOURCE:
    process(RUNNING_cs, RUNNING_PIPE_cs) is
        variable RESOURCE_BUSY_v : std_logic;
    begin
        RESOURCE_BUSY_v := RUNNING_cs;
        for i in 0 to 2 loop
            RESOURCE_BUSY_v := RESOURCE_BUSY_v or RUNNING_PIPE_cs(i);
        end loop;
        RESOURCE_BUSY <= RESOURCE_BUSY_v;
    end process RESOURCE;
    
    WEIGHT_ADDRESS_COUNTER:
    process(WEIGHT_ADDRESS_cs) is
    begin
        if WEIGHT_ADDRESS_cs = std_logic_vector(to_unsigned(MATRIX_WIDTH-1, WEIGHT_COUNTER_WIDTH)) then
            WEIGHT_ADDRESS_ns <= (others => '0');
        else
            WEIGHT_ADDRESS_ns <= std_logic_vector(unsigned(WEIGHT_ADDRESS_cs) + '1');
        end if;
    end process WEIGHT_ADDRESS_COUNTER;
        
    CONTROL:
    process(INSTRUCTION_EN, RUNNING_cs, LENGTH_EVENT) is
        variable INSTRUCTION_EN_v           : std_logic;
        variable RUNNING_cs_v               : std_logic;
        variable LENGTH_EVENT_v             : std_logic;
        
        variable RUNNING_ns_v               : std_logic;
        variable ADDRESS_LOAD_v             : std_logic;
        variable WEIGHT_ADDRESS_ns_v        : BYTE_TYPE;
        variable WEIGHT_READ_EN_ns_v        : std_logic;
        variable LENGTH_LOAD_v              : std_logic;
        variable LENGTH_RESET_v             : std_logic;
        variable SIGNED_LOAD_v              : std_logic;
        variable SIGNED_RESET_v             : std_logic;
    begin
        INSTRUCTION_EN_v    := INSTRUCTION_EN;
        RUNNING_cs_v        := RUNNING_cs;
        LENGTH_EVENT_v      := LENGTH_EVENT;
        
        --synthesis translate_off
        if INSTRUCTION_EN_v = '1' and RUNNING_cs_v = '1' then
            report "New Instruction shouldn't be feeded while processing! WEIGHT_CONTROL.vhdl" severity warning;
        end if;
        --synthesis translate_on
    
        if RUNNING_cs_v = '0' then
            if INSTRUCTION_EN_v = '1' then
                RUNNING_ns_v        := '1';
                ADDRESS_LOAD_v      := '1';
                WEIGHT_READ_EN_ns_v := '1';
                LENGTH_LOAD_v       := '1';
                LENGTH_RESET_v      := '1';
                SIGNED_LOAD_v       := '1';
                SIGNED_RESET_v      := '0';
            else
                RUNNING_ns_v        := '0';
                ADDRESS_LOAD_v      := '0';            
                WEIGHT_READ_EN_ns_v := '0';
                LENGTH_LOAD_v       := '0';
                LENGTH_RESET_v      := '0';
                SIGNED_LOAD_v       := '0';
                SIGNED_RESET_v      := '0';
            end if;
        else
            if LENGTH_EVENT_v = '1' then
                RUNNING_ns_v        := '0';
                ADDRESS_LOAD_v      := '0';
                WEIGHT_READ_EN_ns_v := '0';
                LENGTH_LOAD_v       := '0';
                LENGTH_RESET_v      := '0';
                SIGNED_LOAD_v       := '0';
                SIGNED_RESET_v      := '1';
            else
                RUNNING_ns_v        := '1';
                ADDRESS_LOAD_v      := '0';            
                WEIGHT_READ_EN_ns_v := '1';
                LENGTH_LOAD_v       := '0';
                LENGTH_RESET_v      := '0';
                SIGNED_LOAD_v       := '0';
                SIGNED_RESET_v      := '0';
            end if;
        end if;
        
        RUNNING_ns <= RUNNING_ns_v;
        ADDRESS_LOAD <= ADDRESS_LOAD_v;
        WEIGHT_READ_EN_ns <= WEIGHT_READ_EN_ns_v;
        LENGTH_LOAD <= LENGTH_LOAD_v;
        LENGTH_RESET <= LENGTH_RESET_v;
        SIGNED_LOAD <= SIGNED_LOAD_v;
        SIGNED_RESET <= SIGNED_RESET_v;
    end process CONTROL;
    
    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                WEIGHT_READ_EN_cs   <= '0';
                LOAD_WEIGHT_cs      <= (others => '0');
                RUNNING_cs          <= '0';
                RUNNING_PIPE_cs     <= (others => '0');
                WEIGHT_PIPE0_cs     <= (others => '0');
                WEIGHT_PIPE1_cs     <= (others => '0');
                WEIGHT_PIPE2_cs     <= (others => '0');
                WEIGHT_PIPE3_cs     <= (others => '0');
                WEIGHT_PIPE4_cs     <= (others => '0');
                WEIGHT_PIPE5_cs     <= (others => '0');
                BUFFER_PIPE_cs      <= (others => '0');
                SIGNED_PIPE_cs      <= (others => '0');
            else
                if ENABLE = '1' then
                    WEIGHT_READ_EN_cs   <= WEIGHT_READ_EN_ns;
                    LOAD_WEIGHT_cs      <= LOAD_WEIGHT_ns;
                    RUNNING_cs          <= RUNNING_ns;
                    RUNNING_PIPE_cs     <= RUNNING_PIPE_ns;
                    WEIGHT_PIPE0_cs     <= WEIGHT_PIPE0_ns;
                    WEIGHT_PIPE1_cs     <= WEIGHT_PIPE1_ns;
                    WEIGHT_PIPE2_cs     <= WEIGHT_PIPE2_ns;
                    WEIGHT_PIPE3_cs     <= WEIGHT_PIPE3_ns;
                    WEIGHT_PIPE4_cs     <= WEIGHT_PIPE4_ns;
                    WEIGHT_PIPE5_cs     <= WEIGHT_PIPE5_ns;
                    BUFFER_PIPE_cs      <= BUFFER_PIPE_ns;
                    SIGNED_PIPE_cs      <= SIGNED_PIPE_ns;
                end if;
            end if;
            
            if LENGTH_RESET = '1' then
                WEIGHT_ADDRESS_cs <= (others => '0');
            else
                if ENABLE = '1' then
                    WEIGHT_ADDRESS_cs <= WEIGHT_ADDRESS_ns;
                end if;
            end if;
            
            if SIGNED_RESET = '1' then
                WEIGHT_SIGNED_cs    <= '0';
                READ_PIPE0_cs       <= '0';
                READ_PIPE1_cs       <= '0';
                READ_PIPE2_cs       <= '0';
            else
                if SIGNED_LOAD = '1' then
                    WEIGHT_SIGNED_cs    <= WEIGHT_SIGNED_ns;
                end if;
                
                if ENABLE = '1' then
                    READ_PIPE0_cs       <= READ_PIPE0_ns;
                    READ_PIPE1_cs       <= READ_PIPE1_ns;
                    READ_PIPE2_cs       <= READ_PIPE2_ns;
                end if;
            end if;
        end if;
    end process SEQ_LOG;
end architecture BEH;
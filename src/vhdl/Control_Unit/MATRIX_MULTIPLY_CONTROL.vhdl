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

--! @file MATRIX_MULTIPLY_CONTROL.vhdl
--! @author Jonas Fuhrmann
--! @brief This component includes the control unit for the matrix multipy operation.
--! @details Systolic data from the systolic data setupt is read and piped through the matrix multiply unit. Weights are activated (preweights are loaded in weights registers).
--! Weights are activated in a round trip. So weight instructions and matrix multiply instructions can be executed in parallel to calculate a sequence of data.
--! Data is stored in the accumulators (register file) and can be accumulated to consisting data or overwritten.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    use IEEE.math_real.log2;
    use IEEE.math_real.ceil;
    
entity MATRIX_MULTIPLY_CONTROL is
    generic(
        MATRIX_WIDTH    : natural := 14
    );
    port(
        CLK, RESET      :  in std_logic;
        ENABLE          :  in std_logic; 
        
        INSTRUCTION     :  in INSTRUCTION_TYPE; --!< The matrix multiply instruction to be executed.
        INSTRUCTION_EN  :  in std_logic; --!< Enable for instruction.
        
        BUF_TO_SDS_ADDR : out BUFFER_ADDRESS_TYPE; --!< Address for unified buffer read.
        BUF_READ_EN     : out std_logic; --!< Read enable flag for unified buffer.
        MMU_SDS_EN      : out std_logic; --!< Enable flag for matrix multiply unit and systolic data setup.
        MMU_SIGNED      : out std_logic; --!< Determines if the data is signed or unsigned.
        ACTIVATE_WEIGHT : out std_logic; --!< Activate flag for the preweights in the matrix multiply unit.
        
        ACC_ADDR        : out ACCUMULATOR_ADDRESS_TYPE; --!< Address of the accumulators.
        ACCUMULATE      : out std_logic; --!< Determines if data should be accumulated or overwritten.
        ACC_ENABLE      : out std_logic; --!< Enable flag for accumulators.
        
        BUSY            : out std_logic; --!< If the control unit is busy, a new instruction shouldn't be feeded.
        RESOURCE_BUSY   : out std_logic --!< The resources are in use and the instruction is not fully finished yet.
    );
end entity MATRIX_MULTIPLY_CONTROL;

--! @brief The architecture of the matric multiply unit.
architecture BEH of MATRIX_MULTIPLY_CONTROL is
    type ACCUMULATOR_ADDRESS_ARRAY_TYPE is array(0 to MATRIX_WIDTH-1 + 2 + 3) of ACCUMULATOR_ADDRESS_TYPE;

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
            COUNTER_WIDTH   : natural := 32;
            MATRIX_WIDTH    : natural := 14
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
    
    signal BUF_READ_EN_cs   : std_logic := '0';
    signal BUF_READ_EN_ns   : std_logic;
    
    signal MMU_SDS_EN_cs    : std_logic := '0';
    signal MMU_SDS_EN_ns    : std_logic;
    
    signal MMU_SDS_DELAY_cs : std_logic_vector(0 to 2) := (others => '0');
    signal MMU_SDS_DELAY_ns : std_logic_vector(0 to 2);
    
    signal MMU_SIGNED_cs    : std_logic := '0';
    signal MMU_SIGNED_ns    : std_logic;
    
    signal SIGNED_PIPE_cs   : std_logic_vector(0 to 2) := (others => '0');
    signal SIGNED_PIPE_ns   : std_logic_vector(0 to 2);
    
    constant WEIGHT_COUNTER_WIDTH   : natural := natural(ceil(log2(real(MATRIX_WIDTH-1))));
    signal WEIGHT_COUNTER_cs        : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0) := (others => '0');
    signal WEIGHT_COUNTER_ns        : std_logic_vector(WEIGHT_COUNTER_WIDTH-1 downto 0);
    
    signal WEIGHT_PIPE_cs   : std_logic_vector(0 to 2) := (others => '0');
    signal WEIGHT_PIPE_ns   : std_logic_vector(0 to 2);
    
    signal ACTIVATE_WEIGHT_DELAY_cs : std_logic_vector(0 to 2) := (others => '0');
    signal ACTIVATE_WEIGHT_DELAY_ns : std_logic_vector(0 to 2);
    
    signal ACC_ENABLE_cs    : std_logic := '0';
    signal ACC_ENABLE_ns    : std_logic;
    
    signal RUNNING_cs       : std_logic := '0';
    signal RUNNING_ns       : std_logic;
    
    signal RUNNING_PIPE_cs : std_logic_vector(0 to MATRIX_WIDTH+2+3-1) := (others => '0');
    signal RUNNING_PIPE_ns : std_logic_vector(0 to MATRIX_WIDTH+2+3-1);
    
    signal ACCUMULATE_cs    : std_logic := '0';
    signal ACCUMULATE_ns    : std_logic;
        
    signal BUF_ADDR_PIPE_cs : BUFFER_ADDRESS_TYPE := (others => '0');
    signal BUF_ADDR_PIPE_ns : BUFFER_ADDRESS_TYPE;
    
    signal ACC_ADDR_PIPE_cs : ACCUMULATOR_ADDRESS_TYPE := (others => '0');
    signal ACC_ADDR_PIPE_ns : ACCUMULATOR_ADDRESS_TYPE;
    
    signal BUF_READ_PIPE_cs : std_logic_vector(0 to 2) := (others => '0');
    signal BUF_READ_PIPE_ns : std_logic_vector(0 to 2);
    
    signal MMU_SDS_EN_PIPE_cs : std_logic_vector(0 to 2) := (others => '0');
    signal MMU_SDS_EN_PIPE_ns : std_logic_vector(0 to 2);
    
    signal ACC_EN_PIPE_cs : std_logic_vector(0 to 2) := (others => '0');
    signal ACC_EN_PIPE_ns : std_logic_vector(0 to 2);
    
    signal ACCUMULATE_PIPE_cs : std_logic_vector(0 to 2) := (others => '0');
    signal ACCUMULATE_PIPE_ns : std_logic_vector(0 to 2);
    
    signal ACC_LOAD  : std_logic;
    signal ACC_RESET : std_logic;
    
    signal ACC_ADDR_DELAY_cs : ACCUMULATOR_ADDRESS_ARRAY_TYPE := (others => (others => '0'));
    signal ACC_ADDR_DELAY_ns : ACCUMULATOR_ADDRESS_ARRAY_TYPE;
    
    signal ACCUMULATE_DELAY_cs : std_logic_vector(0 to MATRIX_WIDTH-1 + 2 + 3) := (others => '0');
    signal ACCUMULATE_DELAY_ns : std_logic_vector(0 to MATRIX_WIDTH-1 + 2 + 3);
    
    signal ACC_EN_DELAY_cs : std_logic_vector(0 to MATRIX_WIDTH-1 + 2 + 3) := (others => '0');
    signal ACC_EN_DELAY_ns : std_logic_vector(0 to MATRIX_WIDTH-1 + 2 + 3);
    
    -- LENGTH_COUNTER signals
    signal LENGTH_RESET     : std_logic;
    signal LENGTH_END_VAL   : LENGTH_TYPE;
    signal LENGTH_LOAD      : std_logic;
    signal LENGTH_EVENT     : std_logic;
    
    -- ADDRESS_COUNTER signals
    signal ADDRESS_LOAD     : std_logic;
    
    -- WEIGHT_COUNTER reset
    signal WEIGHT_RESET     : std_logic;
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
    
    ADDRESS_COUNTER0_i : entity work.DSP_LOAD_COUNTER(ACC_COUNTER)
    generic map(
        COUNTER_WIDTH => ACCUMULATOR_ADDRESS_WIDTH,
        MATRIX_WIDTH  => MATRIX_WIDTH
    )
    port map(
        CLK         => CLK,
        RESET       => RESET,
        ENABLE      => ENABLE,
        START_VAL   => INSTRUCTION.ACC_ADDRESS,
        LOAD        => ADDRESS_LOAD,
        COUNT_VAL   => ACC_ADDR_PIPE_ns
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
        COUNT_VAL   => BUF_ADDR_PIPE_ns
    );
    
    ACCUMULATE_ns <= INSTRUCTION.OP_CODE(1);
    
    BUF_TO_SDS_ADDR         <= BUF_ADDR_PIPE_cs;
    ACC_ADDR_DELAY_ns(0)    <= ACC_ADDR_PIPE_cs;
    
    ACC_ADDR <= ACC_ADDR_DELAY_cs(MATRIX_WIDTH-1 + 2 + 3);
  
    BUF_READ_PIPE_ns(1 to 2)    <= BUF_READ_PIPE_cs(0 to 1);
    MMU_SDS_EN_PIPE_ns(1 to 2)  <= MMU_SDS_EN_PIPE_cs(0 to 1);
    ACC_EN_PIPE_ns(1 to 2)      <= ACC_EN_PIPE_cs(0 to 1);
    ACCUMULATE_PIPE_ns(1 to 2)  <= ACCUMULATE_PIPE_cs(0 to 1);
    SIGNED_PIPE_ns(1 to 2)      <= SIGNED_PIPE_cs(0 to 1);
    WEIGHT_PIPE_ns(1 to 2)      <= WEIGHT_PIPE_cs(0 to 1);
    
    BUF_READ_PIPE_ns(0)    <= BUF_READ_EN_cs;
    MMU_SDS_EN_PIPE_ns(0)  <= MMU_SDS_EN_cs;
    ACC_EN_PIPE_ns(0)      <= ACC_ENABLE_cs;
    ACCUMULATE_PIPE_ns(0)  <= ACCUMULATE_cs;
    SIGNED_PIPE_ns(0)      <= MMU_SIGNED_cs;
    WEIGHT_PIPE_ns(0)      <= '1' when WEIGHT_COUNTER_cs = std_logic_vector(to_unsigned(0, WEIGHT_COUNTER_WIDTH)) else '0'; 
    
    MMU_SIGNED_ns <= INSTRUCTION.OP_CODE(0);
    
    BUF_READ_EN             <= '0' when BUF_READ_EN_cs = '0' else BUF_READ_PIPE_cs(2);
    MMU_SDS_DELAY_ns(0)     <= '0' when MMU_SDS_EN_cs = '0' else MMU_SDS_EN_PIPE_cs(2);
    ACC_EN_DELAY_ns(0)      <= '0' when ACC_ENABLE_cs = '0' else ACC_EN_PIPE_cs(2);
    ACCUMULATE_DELAY_ns(0)  <= '0' when ACCUMULATE_cs = '0' else ACCUMULATE_PIPE_cs(2);
    
    MMU_SIGNED <= '0' when MMU_SDS_DELAY_cs(2) = '0' else SIGNED_PIPE_cs(2);
    
    ACTIVATE_WEIGHT_DELAY_ns(0) <= WEIGHT_PIPE_cs(2);
    ACTIVATE_WEIGHT_DELAY_ns(1 to 2) <= ACTIVATE_WEIGHT_DELAY_cs(0 to 1);
    ACTIVATE_WEIGHT <= '0' when MMU_SDS_DELAY_cs(2) = '0' else ACTIVATE_WEIGHT_DELAY_cs(2);
    
    ACC_ENABLE <= ACC_EN_DELAY_cs(MATRIX_WIDTH-1 + 2 + 3);
    ACCUMULATE <= ACCUMULATE_DELAY_cs(MATRIX_WIDTH-1 + 2 + 3);
    MMU_SDS_EN <= MMU_SDS_DELAY_cs(2);
    
    BUSY <= RUNNING_cs;
    RUNNING_PIPE_ns(0) <= RUNNING_cs;
    RUNNING_PIPE_ns(1 to MATRIX_WIDTH+2+3-1) <= RUNNING_PIPE_cs(0 to MATRIX_WIDTH+2+2-1);
    
    --
    ACC_ADDR_DELAY_ns(1 to MATRIX_WIDTH-1 + 2 + 3)      <= ACC_ADDR_DELAY_cs(0 to MATRIX_WIDTH-1 + 2 +2);
    ACCUMULATE_DELAY_ns(1 to MATRIX_WIDTH-1 + 2 + 3)    <= ACCUMULATE_DELAY_cs(0 to MATRIX_WIDTH-1 + 2 + 2);
    ACC_EN_DELAY_ns(1 to MATRIX_WIDTH-1 + 2 + 3)        <= ACC_EN_DELAY_cs(0 to MATRIX_WIDTH-1 + 2 + 2);
    MMU_SDS_DELAY_ns(1 to 2)                            <= MMU_SDS_DELAY_cs(0 to 1);
    
    RESOURCE:
    process(RUNNING_cs, RUNNING_PIPE_cs) is
        variable RESOURCE_BUSY_v : std_logic;
    begin
        RESOURCE_BUSY_v := RUNNING_cs;
        for i in 0 to MATRIX_WIDTH+2+3-1 loop
            RESOURCE_BUSY_v := RESOURCE_BUSY_v or RUNNING_PIPE_cs(i);
        end loop;
        RESOURCE_BUSY <= RESOURCE_BUSY_v;
    end process RESOURCE;
    
    WEIGHT_COUNTER:
    process(WEIGHT_COUNTER_cs) is
    begin
        if WEIGHT_COUNTER_cs = std_logic_vector(to_unsigned(MATRIX_WIDTH-1, WEIGHT_COUNTER_WIDTH)) then
            WEIGHT_COUNTER_ns <= (others => '0');
        else
            WEIGHT_COUNTER_ns <= std_logic_vector(unsigned(WEIGHT_COUNTER_cs) + '1');
        end if;
    end process WEIGHT_COUNTER;
    
    CONTROL:
    process(INSTRUCTION, INSTRUCTION_EN, RUNNING_cs, LENGTH_EVENT) is
        variable INSTRUCTION_v      : INSTRUCTION_TYPE;
        variable INSTRUCTION_EN_v   : std_logic;
        variable RUNNING_cs_v       : std_logic;
        variable LENGTH_EVENT_v     : std_logic;
        
        variable RUNNING_ns_v       : std_logic;
        variable ADDRESS_LOAD_v     : std_logic;
        variable BUF_READ_EN_ns_v   : std_logic;
        variable MMU_SDS_EN_ns_v    : std_logic;      
        variable ACC_ENABLE_ns_v    : std_logic;
        variable LENGTH_LOAD_v      : std_logic;
        variable LENGTH_RESET_v     : std_logic;
        variable ACC_LOAD_v         : std_logic;
        variable ACC_RESET_v        : std_logic;
        variable WEIGHT_RESET_v     : std_logic;
    begin
        INSTRUCTION_v       := INSTRUCTION;
        INSTRUCTION_EN_v    := INSTRUCTION_EN;
        RUNNING_cs_v        := RUNNING_cs;
        LENGTH_EVENT_v      := LENGTH_EVENT;
    
        if RUNNING_cs_v = '0' then
            if INSTRUCTION_EN_v = '1' then
                RUNNING_ns_v    := '1';
                ADDRESS_LOAD_v  := '1';
                BUF_READ_EN_ns_v:= '1';
                MMU_SDS_EN_ns_v := '1';
                ACC_ENABLE_ns_v := '1';
                LENGTH_LOAD_v   := '1';
                LENGTH_RESET_v  := '1';
                ACC_LOAD_v      := '1';
                ACC_RESET_v     := '0';
                WEIGHT_RESET_v  := '1';
            else
                RUNNING_ns_v    := '0';
                ADDRESS_LOAD_v  := '0';
                BUF_READ_EN_ns_v:= '0';
                MMU_SDS_EN_ns_v := '0';
                ACC_ENABLE_ns_v := '0';
                LENGTH_LOAD_v   := '0';
                LENGTH_RESET_v  := '0';
                ACC_LOAD_v      := '0';
                ACC_RESET_v     := '0'; 
                WEIGHT_RESET_v  := '0';                
            end if;
        else
            if LENGTH_EVENT_v = '1' then
                RUNNING_ns_v    := '0';
                ADDRESS_LOAD_v  := '0';
                BUF_READ_EN_ns_v:= '0';
                MMU_SDS_EN_ns_v := '0';
                ACC_ENABLE_ns_v := '0';
                LENGTH_LOAD_v   := '0';
                LENGTH_RESET_v  := '0';
                ACC_LOAD_v      := '0'; 
                ACC_RESET_v     := '1';
                WEIGHT_RESET_v  := '0';
            else
                RUNNING_ns_v    := '1';
                ADDRESS_LOAD_v  := '0';
                BUF_READ_EN_ns_v:= '1';
                MMU_SDS_EN_ns_v := '1';
                ACC_ENABLE_ns_v := '1';
                LENGTH_LOAD_v   := '0';
                LENGTH_RESET_v  := '0';
                ACC_LOAD_v      := '0';
                ACC_RESET_v     := '0';
                WEIGHT_RESET_v  := '0';
            end if;
        end if;
        
        RUNNING_ns      <= RUNNING_ns_v;
        ADDRESS_LOAD    <= ADDRESS_LOAD_v;
        BUF_READ_EN_ns  <= BUF_READ_EN_ns_v;
        MMU_SDS_EN_ns   <= MMU_SDS_EN_ns_v;
        ACC_ENABLE_ns   <= ACC_ENABLE_ns_v;
        LENGTH_LOAD     <= LENGTH_LOAD_v;
        LENGTH_RESET    <= LENGTH_RESET_v;
        ACC_LOAD        <= ACC_LOAD_v;
        ACC_RESET       <= ACC_RESET_v;
        WEIGHT_RESET    <= WEIGHT_RESET_v;
    end process CONTROL;
    
    SEQ_LOG:
    process(CLK) is
    begin
        if CLK'event and CLK = '1' then
            if RESET = '1' then
                BUF_READ_EN_cs  <= '0';
                MMU_SDS_EN_cs   <= '0';
                ACC_ENABLE_cs   <= '0';
                RUNNING_cs      <= '0';
                RUNNING_PIPE_cs <= (others => '0');
                BUF_ADDR_PIPE_cs    <= (others => '0');
                ACC_ADDR_PIPE_cs    <= (others => '0');
                ACC_ADDR_DELAY_cs   <= (others => (others => '0'));
                ACCUMULATE_DELAY_cs <= (others => '0');
                ACC_EN_DELAY_cs     <= (others => '0');
                MMU_SDS_DELAY_cs    <= (others => '0');
                SIGNED_PIPE_cs      <= (others => '0');
                WEIGHT_PIPE_cs      <= (others => '0');
                ACTIVATE_WEIGHT_DELAY_cs <= (others => '0');
            else
                if ENABLE = '1' then
                    BUF_READ_EN_cs  <= BUF_READ_EN_ns;
                    MMU_SDS_EN_cs   <= MMU_SDS_EN_ns;
                    ACC_ENABLE_cs   <= ACC_ENABLE_ns;
                    RUNNING_cs      <= RUNNING_ns;
                    RUNNING_PIPE_cs <= RUNNING_PIPE_ns;
                    BUF_ADDR_PIPE_cs    <= BUF_ADDR_PIPE_ns;
                    ACC_ADDR_PIPE_cs    <= ACC_ADDR_PIPE_ns;
                    ACC_ADDR_DELAY_cs   <= ACC_ADDR_DELAY_ns;
                    ACCUMULATE_DELAY_cs <= ACCUMULATE_DELAY_ns;
                    ACC_EN_DELAY_cs     <= ACC_EN_DELAY_ns;
                    MMU_SDS_DELAY_cs    <= MMU_SDS_DELAY_ns;
                    SIGNED_PIPE_cs      <= SIGNED_PIPE_ns;
                    WEIGHT_PIPE_cs      <= WEIGHT_PIPE_ns;
                    ACTIVATE_WEIGHT_DELAY_cs <= ACTIVATE_WEIGHT_DELAY_ns;
                end if;
            end if;
            
            if ACC_RESET = '1' then
                ACCUMULATE_cs   <= '0';
                BUF_READ_PIPE_cs    <= (others => '0');
                MMU_SDS_EN_PIPE_cs  <= (others => '0');
                ACC_EN_PIPE_cs      <= (others => '0');
                ACCUMULATE_PIPE_cs  <= (others => '0');
                MMU_SIGNED_cs       <= '0';
            else
                if ACC_LOAD = '1' then
                    ACCUMULATE_cs   <= ACCUMULATE_ns;
                    MMU_SIGNED_cs   <= MMU_SIGNED_ns;
                end if;
                
                if ENABLE = '1' then
                    BUF_READ_PIPE_cs    <= BUF_READ_PIPE_ns;
                    MMU_SDS_EN_PIPE_cs  <= MMU_SDS_EN_PIPE_ns;
                    ACC_EN_PIPE_cs      <= ACC_EN_PIPE_ns;
                    ACCUMULATE_PIPE_cs  <= ACCUMULATE_PIPE_ns;
                end if;
            end if;
            
            if WEIGHT_RESET = '1' then
                WEIGHT_COUNTER_cs   <= (others => '0');
            else
                if ENABLE = '1' then
                    WEIGHT_COUNTER_cs   <= WEIGHT_COUNTER_ns;
                end if;
            end if;
        end if;
    end process SEQ_LOG;
end architecture BEH;

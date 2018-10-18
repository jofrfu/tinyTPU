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

--! @file TPU_CORE.vhdl
--! @author Jonas Fuhrmann
--! @brief This component is the core of the Tensor Processing Unit.
--! @details The TPU core includes all component, which are necessary for calculation and controlling.

use WORK.TPU_pack.all;
library IEEE;
    use IEEE.std_logic_1164.all;
    use IEEE.numeric_std.all;
    
entity TPU_CORE is
    generic(
        MATRIX_WIDTH            : natural := 14; --!< The width of the Matrix Multiply Unit and busses.
        WEIGHT_BUFFER_DEPTH     : natural := 32768; --!< The depth of the weight buffer.
        UNIFIED_BUFFER_DEPTH    : natural := 4096 --!< The depth of the unified buffer.
    );
    port(
        CLK, RESET          : in  std_logic;
        ENABLE              : in  std_logic;
    
        WEIGHT_WRITE_PORT   : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Host write port for the weight buffer
        WEIGHT_ADDRESS      : in  WEIGHT_ADDRESS_TYPE; --!< Host address for the weight buffer.
        WEIGHT_ENABLE       : in  std_logic; --!< Host enable for the weight buffer.
        WEIGHT_WRITE_ENABLE : in  std_logic_vector(0 to MATRIX_WIDTH-1); --!< Host write enable for the weight buffer.
        
        BUFFER_WRITE_PORT   : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Host write port for the unified buffer.
        BUFFER_READ_PORT    : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1); --!< Host read port for the unified buffer.
        BUFFER_ADDRESS      : in  BUFFER_ADDRESS_TYPE; --!< Host address for the unified buffer.
        BUFFER_ENABLE       : in  std_logic; --!< Host enable for the unified buffer.
        BUFFER_WRITE_ENABLE : in  std_logic_vector(0 to MATRIX_WIDTH-1); --!< Host write enable for the unified buffer.
        
        INSTRUCTION_PORT    : in  INSTRUCTION_TYPE; --!< Write port for instructions.
        INSTRUCTION_ENABLE  : in  std_logic; --!< Write enable for instructions.
        
        BUSY                : out std_logic; --!< The TPU is still busy and can't take any instruction.
        SYNCHRONIZE         : out std_logic --!< Synchronization interrupt.
    );
end entity TPU_CORE;

--! @brief The architecture of the TPU core.
architecture BEH of TPU_CORE is
    component WEIGHT_BUFFER is
        generic(
            MATRIX_WIDTH    : natural := 14;
            -- How many tiles can be saved
            TILE_WIDTH      : natural := 32768
        );
        port(
            CLK, RESET      : in  std_logic;
            ENABLE          : in  std_logic;
            
            -- Port0
            ADDRESS0        : in  WEIGHT_ADDRESS_TYPE;
            EN0             : in  std_logic;
            WRITE_EN0       : in  std_logic;
            WRITE_PORT0     : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            READ_PORT0      : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            -- Port1
            ADDRESS1        : in  WEIGHT_ADDRESS_TYPE;
            EN1             : in  std_logic;
            WRITE_EN1       : in  std_logic_vector(0 to MATRIX_WIDTH-1);
            WRITE_PORT1     : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            READ_PORT1      : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1)
        );
    end component WEIGHT_BUFFER;
    for all : WEIGHT_BUFFER use entity WORK.WEIGHT_BUFFER(BEH);
    
    signal WEIGHT_ADDRESS0      : WEIGHT_ADDRESS_TYPE;
    signal WEIGHT_EN0           : std_logic;
    signal WEIGHT_READ_PORT0    : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    component UNIFIED_BUFFER is
        generic(
            MATRIX_WIDTH    : natural := 14;
            -- How many tiles can be saved
            TILE_WIDTH      : natural := 4096
        );
        port(
            CLK, RESET      : in  std_logic;
            ENABLE          : in  std_logic;
            
            -- Master port - overrides other ports
            MASTER_ADDRESS      : in  BUFFER_ADDRESS_TYPE;
            MASTER_EN           : in  std_logic;
            MASTER_WRITE_EN     : in  std_logic_vector(0 to MATRIX_WIDTH-1);
            MASTER_WRITE_PORT   : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            MASTER_READ_PORT    : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            -- Port0
            ADDRESS0        : in  BUFFER_ADDRESS_TYPE;
            EN0             : in  std_logic;
            READ_PORT0      : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            -- Port1
            ADDRESS1        : in  BUFFER_ADDRESS_TYPE;
            EN1             : in  std_logic;
            WRITE_EN1       : in  std_logic;
            WRITE_PORT1     : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1)
        );
    end component UNIFIED_BUFFER;
    for all : UNIFIED_BUFFER use entity WORK.UNIFIED_BUFFER(BEH);
    
    signal BUFFER_ADDRESS0      : BUFFER_ADDRESS_TYPE;
    signal BUFFER_EN0           : std_logic;
    signal BUFFER_READ_PORT0    : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    signal BUFFER_ADDRESS1      : BUFFER_ADDRESS_TYPE;
    signal BUFFER_WRITE_EN1     : std_logic;
    signal BUFFER_WRITE_PORT1   : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    component SYSTOLIC_DATA_SETUP is
        generic(
            MATRIX_WIDTH  : natural := 14
        );
        port(
            CLK, RESET      : in  std_logic;
            ENABLE          : in  std_logic;
            DATA_INPUT      : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            SYSTOLIC_OUTPUT : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1)
        );
    end component SYSTOLIC_DATA_SETUP;
    for all : SYSTOLIC_DATA_SETUP use entity WORK.SYSTOLIC_DATA_SETUP(BEH);
    
    signal SDS_SYSTOLIC_OUTPUT  : BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    component MATRIX_MULTIPLY_UNIT is
        generic(
            MATRIX_WIDTH    : natural := 14
        );
        port(
            CLK, RESET      : in  std_logic;
            ENABLE          : in  std_logic;
            
            WEIGHT_DATA     : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            WEIGHT_SIGNED   : in  std_logic;
            SYSTOLIC_DATA   : in  BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            SYSTOLIC_SIGNED : in  std_logic;
            
            ACTIVATE_WEIGHT : in  std_logic; -- Activates the loaded weights sequentially
            LOAD_WEIGHT     : in  std_logic; -- Preloads one column of weights with WEIGHT_DATA
            WEIGHT_ADDRESS  : in  BYTE_TYPE; -- Addresses up to 256 columns of preweights
            
            RESULT_DATA     : out WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1)
        );
    end component MATRIX_MULTIPLY_UNIT;
    for all : MATRIX_MULTIPLY_UNIT use entity WORK.MATRIX_MULTIPLY_UNIT(BEH);
    
    signal MMU_WEIGHT_SIGNED    : std_logic;
    signal MMU_SYSTOLIC_SIGNED  : std_logic;
    
    signal MMU_ACTIVATE_WEIGHT  : std_logic;
    signal MMU_LOAD_WEIGHT      : std_logic;
    signal MMU_WEIGHT_ADDRESS   : BYTE_TYPE;
    
    signal MMU_RESULT_DATA      : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    component REGISTER_FILE is
        generic(
            MATRIX_WIDTH    : natural := 14;
            REGISTER_DEPTH  : natural := 512
        );
        port(
            CLK, RESET          : in  std_logic;
            ENABLE              : in  std_logic;
            
            WRITE_ADDRESS       : in  ACCUMULATOR_ADDRESS_TYPE;
            WRITE_PORT          : in  WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            WRITE_ENABLE        : in  std_logic;
            
            ACCUMULATE          : in  std_logic;
            
            READ_ADDRESS        : in  ACCUMULATOR_ADDRESS_TYPE;
            READ_PORT           : out WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1)
        );
    end component REGISTER_FILE;
    for all : REGISTER_FILE use entity WORK.REGISTER_FILE(BEH);
    
    signal REG_WRITE_ADDRESS    : ACCUMULATOR_ADDRESS_TYPE;
    signal REG_WRITE_EN         : std_logic;
    
    signal REG_ACCUMULATE       : std_logic;
    signal REG_READ_ADDRESS     : ACCUMULATOR_ADDRESS_TYPE;
    signal REG_READ_PORT        : WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
    
    component ACTIVATION is
        generic(
            MATRIX_WIDTH        : natural := 14
        );
        port(
            CLK, RESET          : in  std_logic;
            ENABLE              : in  std_logic;
            
            ACTIVATION_FUNCTION : in  ACTIVATION_BIT_TYPE;
            SIGNED_NOT_UNSIGNED : in  std_logic;
            
            ACTIVATION_INPUT    : in  WORD_ARRAY_TYPE(0 to MATRIX_WIDTH-1);
            ACTIVATION_OUTPUT   : out BYTE_ARRAY_TYPE(0 to MATRIX_WIDTH-1)
        );
    end component ACTIVATION;
    for all : ACTIVATION use entity WORK.ACTIVATION(BEH);
    
    signal ACTIVATION_FUNCTION  : ACTIVATION_BIT_TYPE;
    signal ACTIVATION_SIGNED    : std_logic;
        
    component WEIGHT_CONTROL is
        generic(
            MATRIX_WIDTH            : natural := 14
        );
        port(
            CLK, RESET              :  in std_logic;
            ENABLE                  :  in std_logic;
        
            INSTRUCTION             :  in WEIGHT_INSTRUCTION_TYPE;
            INSTRUCTION_EN          :  in std_logic;
            
            WEIGHT_READ_EN          : out std_logic;
            WEIGHT_BUFFER_ADDRESS   : out WEIGHT_ADDRESS_TYPE;
            
            LOAD_WEIGHT             : out std_logic;
            WEIGHT_ADDRESS          : out BYTE_TYPE;
            
            WEIGHT_SIGNED           : out std_logic;
                        
            BUSY                    : out std_logic;
            RESOURCE_BUSY           : out std_logic
        );
    end component WEIGHT_CONTROL;
    for all : WEIGHT_CONTROL use entity WORK.WEIGHT_CONTROL(BEH);
    
    signal WEIGHT_INSTRUCTION       : WEIGHT_INSTRUCTION_TYPE;
    signal WEIGHT_INSTRUCTION_EN    : std_logic;
    
    signal WEIGHT_READ_EN           : std_logic;
    
    signal WEIGHT_RESOURCE_BUSY     : std_logic;
    
    component MATRIX_MULTIPLY_CONTROL is
        generic(
            MATRIX_WIDTH    : natural := 14
        );
        port(
            CLK, RESET      :  in std_logic;
            ENABLE          :  in std_logic; 
            
            INSTRUCTION     :  in INSTRUCTION_TYPE;
            INSTRUCTION_EN  :  in std_logic;
            
            BUF_TO_SDS_ADDR : out BUFFER_ADDRESS_TYPE;
            BUF_READ_EN     : out std_logic;
            MMU_SDS_EN      : out std_logic;
            MMU_SIGNED      : out std_logic;
            ACTIVATE_WEIGHT : out std_logic;
            
            ACC_ADDR        : out ACCUMULATOR_ADDRESS_TYPE;
            ACCUMULATE      : out std_logic;
            ACC_ENABLE      : out std_logic;
            
            BUSY            : out std_logic;
            RESOURCE_BUSY   : out std_logic
        );
    end component MATRIX_MULTIPLY_CONTROL;
    for all : MATRIX_MULTIPLY_CONTROL use entity WORK.MATRIX_MULTIPLY_CONTROL(BEH);
    
    signal MMU_INSTRUCTION      : INSTRUCTION_TYPE;
    signal MMU_INSTRUCTION_EN   : std_logic;
    
    signal BUF_READ_EN          : std_logic;
    signal MMU_SDS_EN           : std_logic;    

    signal MMU_RESOURCE_BUSY    : std_logic;
    
    component ACTIVATION_CONTROL is
        generic(
            MATRIX_WIDTH        : natural := 14
        );
        port(
            CLK, RESET          :  in std_logic;
            ENABLE              :  in std_logic;
            
            INSTRUCTION         :  in INSTRUCTION_TYPE;
            INSTRUCTION_EN      :  in std_logic;
            
            ACC_TO_ACT_ADDR     : out ACCUMULATOR_ADDRESS_TYPE;
            ACTIVATION_FUNCTION : out ACTIVATION_BIT_TYPE;
            SIGNED_NOT_UNSIGNED : out std_logic;
            
            ACT_TO_BUF_ADDR     : out BUFFER_ADDRESS_TYPE;
            BUF_WRITE_EN        : out std_logic;
            
            BUSY                : out std_logic;
            RESOURCE_BUSY       : out std_logic
        );
    end component ACTIVATION_CONTROL;
    for all : ACTIVATION_CONTROL use entity WORK.ACTIVATION_CONTROL(BEH);
    
    signal ACTIVATION_INSTRUCTION       : INSTRUCTION_TYPE;
    signal ACTIVATION_INSTRUCTION_EN    : std_logic;
    
    signal ACTIVATION_RESOURCE_BUSY     : std_logic;
    
    component LOOK_AHEAD_BUFFER is
        port(
            CLK, RESET          :  in std_logic;
            ENABLE              :  in std_logic;
            
            INSTRUCTION_BUSY    :  in std_logic;
            
            INSTRUCTION_INPUT   :  in INSTRUCTION_TYPE;
            INSTRUCTION_WRITE   :  in std_logic;
            
            INSTRUCTION_OUTPUT  : out INSTRUCTION_TYPE;
            INSTRUCTION_READ    : out std_logic
        );
    end component LOOK_AHEAD_BUFFER;
    for all : LOOK_AHEAD_BUFFER use entity WORK.LOOK_AHEAD_BUFFER(BEH);
    
    signal INSTRUCTION_BUSY     : std_logic;
    
    signal INSTRUCTION_OUTPUT   : INSTRUCTION_TYPE;
    signal INSTRUCTION_READ     : std_logic;
    
    component CONTROL_COORDINATOR is
        port(
            CLK, RESET                  :  in std_logic;
            ENABLE                      :  in std_logic;
                
            INSTRUCTION                 :  in INSTRUCTION_TYPE;
            INSTRUCTION_EN              :  in std_logic;
            
            BUSY                        : out std_logic;
            
            WEIGHT_BUSY                 :  in std_logic;
            WEIGHT_RESOURCE_BUSY        :  in std_logic;
            WEIGHT_INSTRUCTION          : out WEIGHT_INSTRUCTION_TYPE;
            WEIGHT_INSTRUCTION_EN       : out std_logic;
            
            MATRIX_BUSY                 :  in std_logic;
            MATRIX_RESOURCE_BUSY        :  in std_logic;
            MATRIX_INSTRUCTION          : out INSTRUCTION_TYPE;
            MATRIX_INSTRUCTION_EN       : out std_logic;
            
            ACTIVATION_BUSY             :  in std_logic;
            ACTIVATION_RESOURCE_BUSY    :  in std_logic;
            ACTIVATION_INSTRUCTION      : out INSTRUCTION_TYPE;
            ACTIVATION_INSTRUCTION_EN   : out std_logic;
            
            SYNCHRONIZE                 : out std_logic
        );
    end component CONTROL_COORDINATOR;
    for all : CONTROL_COORDINATOR use entity WORK.CONTROL_COORDINATOR(BEH);
    
    signal CONTROL_BUSY             : std_logic;
    signal WEIGHT_BUSY              : std_logic;
    signal MATRIX_BUSY              : std_logic;
    signal ACTIVATION_BUSY          : std_logic;
begin
    WEIGHT_BUFFER_i : WEIGHT_BUFFER
    generic map(
        MATRIX_WIDTH    => MATRIX_WIDTH,
        TILE_WIDTH      => WEIGHT_BUFFER_DEPTH
    )
    port map(
        CLK             => CLK,
        RESET           => RESET,
        ENABLE          => ENABLE,
            
        -- Port0    
        ADDRESS0        => WEIGHT_ADDRESS0,
        EN0             => WEIGHT_EN0,
        WRITE_EN0       => '0',
        WRITE_PORT0     => (others => (others => '0')),
        READ_PORT0      => WEIGHT_READ_PORT0,
        -- Port1    
        ADDRESS1        => WEIGHT_ADDRESS,
        EN1             => WEIGHT_ENABLE,
        WRITE_EN1       => WEIGHT_WRITE_ENABLE,
        WRITE_PORT1     => WEIGHT_WRITE_PORT,
        READ_PORT1      => open
    );
    
    UNIFIED_BUFFER_i : UNIFIED_BUFFER
    generic map(
        MATRIX_WIDTH    => MATRIX_WIDTH,
        TILE_WIDTH      => UNIFIED_BUFFER_DEPTH
    )
    port map(
        CLK             => CLK,
        RESET           => RESET,
        ENABLE          => ENABLE,
        
        -- Master port - overrides other ports
        MASTER_ADDRESS      => BUFFER_ADDRESS,
        MASTER_EN           => BUFFER_ENABLE,
        MASTER_WRITE_EN     => BUFFER_WRITE_ENABLE,
        MASTER_WRITE_PORT   => BUFFER_WRITE_PORT,
        MASTER_READ_PORT    => BUFFER_READ_PORT,
        -- Port0
        ADDRESS0        => BUFFER_ADDRESS0,
        EN0             => BUFFER_EN0,
        READ_PORT0      => BUFFER_READ_PORT0,
        -- Port1
        ADDRESS1        => BUFFER_ADDRESS1,
        EN1             => BUFFER_WRITE_EN1,
        WRITE_EN1       => BUFFER_WRITE_EN1,
        WRITE_PORT1     => BUFFER_WRITE_PORT1
    );
    
    SYSTOLIC_DATA_SETUP_i : SYSTOLIC_DATA_SETUP
    generic map(
        MATRIX_WIDTH
    )
    port map(
        CLK             => CLK,
        RESET           => RESET,      
        ENABLE          => ENABLE,
        DATA_INPUT      => BUFFER_READ_PORT0,
        SYSTOLIC_OUTPUT => SDS_SYSTOLIC_OUTPUT 
    );
    
    MATRIX_MULTIPLY_UNIT_i : MATRIX_MULTIPLY_UNIT
    generic map(
        MATRIX_WIDTH   
    )
    port map(
        CLK             => CLK,
        RESET           => RESET,
        ENABLE          => ENABLE,         
        
        WEIGHT_DATA     => WEIGHT_READ_PORT0,
        WEIGHT_SIGNED   => MMU_WEIGHT_SIGNED,
        SYSTOLIC_DATA   => SDS_SYSTOLIC_OUTPUT,
        SYSTOLIC_SIGNED => MMU_SYSTOLIC_SIGNED,
        
        ACTIVATE_WEIGHT => MMU_ACTIVATE_WEIGHT,
        LOAD_WEIGHT     => MMU_LOAD_WEIGHT,
        WEIGHT_ADDRESS  => MMU_WEIGHT_ADDRESS,
        
        RESULT_DATA     => MMU_RESULT_DATA
    );
    
    REGISTER_FILE_i : REGISTER_FILE
    generic map(
        MATRIX_WIDTH    => MATRIX_WIDTH,
        REGISTER_DEPTH  => 512
    )
    port map(  
        CLK             => CLK,
        RESET           => RESET,
        ENABLE          => ENABLE,
           
        WRITE_ADDRESS   => REG_WRITE_ADDRESS,
        WRITE_PORT      => MMU_RESULT_DATA,
        WRITE_ENABLE    => REG_WRITE_EN,
           
        ACCUMULATE      => REG_ACCUMULATE,
           
        READ_ADDRESS    => REG_READ_ADDRESS,
        READ_PORT       => REG_READ_PORT
    );
    
    ACTIVATION_i : ACTIVATION
    generic map(
        MATRIX_WIDTH        => MATRIX_WIDTH
    )
    port map(
        CLK                 => CLK,
        RESET               => RESET,
        ENABLE              => ENABLE,      
        
        ACTIVATION_FUNCTION => ACTIVATION_FUNCTION,
        SIGNED_NOT_UNSIGNED => ACTIVATION_SIGNED,
        
        ACTIVATION_INPUT    => REG_READ_PORT,
        ACTIVATION_OUTPUT   => BUFFER_WRITE_PORT1
    );
    
    WEIGHT_CONTROL_i : WEIGHT_CONTROL
    generic map(
        MATRIX_WIDTH            => MATRIX_WIDTH
    )
    port map(
        CLK                     => CLK,
        RESET                   => RESET,
        ENABLE                  => ENABLE,
    
        INSTRUCTION             => WEIGHT_INSTRUCTION,
        INSTRUCTION_EN          => WEIGHT_INSTRUCTION_EN,
        
        WEIGHT_READ_EN          => WEIGHT_EN0,
        WEIGHT_BUFFER_ADDRESS   => WEIGHT_ADDRESS0,
        
        LOAD_WEIGHT             => MMU_LOAD_WEIGHT,
        WEIGHT_ADDRESS          => MMU_WEIGHT_ADDRESS,
        
        WEIGHT_SIGNED           => MMU_WEIGHT_SIGNED,
                
        BUSY                    => WEIGHT_BUSY,
        RESOURCE_BUSY           => WEIGHT_RESOURCE_BUSY
    );
    
    MATRIX_MULTIPLY_CONTROL_i : MATRIX_MULTIPLY_CONTROL
    generic map(
        MATRIX_WIDTH   
    )
    port map(
        CLK             => CLK,
        RESET           => RESET,
        ENABLE          => ENABLE,
        
        INSTRUCTION     => MMU_INSTRUCTION,
        INSTRUCTION_EN  => MMU_INSTRUCTION_EN,
        
        BUF_TO_SDS_ADDR => BUFFER_ADDRESS0,
        BUF_READ_EN     => BUFFER_EN0,
        MMU_SDS_EN      => MMU_SDS_EN,
        MMU_SIGNED      => MMU_SYSTOLIC_SIGNED,
        ACTIVATE_WEIGHT => MMU_ACTIVATE_WEIGHT,
        
        ACC_ADDR        => REG_WRITE_ADDRESS,
        ACCUMULATE      => REG_ACCUMULATE,
        ACC_ENABLE      => REG_WRITE_EN,
        
        BUSY            => MATRIX_BUSY,
        RESOURCE_BUSY   => MMU_RESOURCE_BUSY
    );
    
    ACTIVATION_CONTROL_i : ACTIVATION_CONTROL
    generic map(
        MATRIX_WIDTH        
    )
    port map(
        CLK                 => CLK,
        RESET               => RESET,
        ENABLE              => ENABLE,
        
        INSTRUCTION         => ACTIVATION_INSTRUCTION,
        INSTRUCTION_EN      => ACTIVATION_INSTRUCTION_EN,
        
        ACC_TO_ACT_ADDR     => REG_READ_ADDRESS,
        ACTIVATION_FUNCTION => ACTIVATION_FUNCTION,
        SIGNED_NOT_UNSIGNED => ACTIVATION_SIGNED,
        
        ACT_TO_BUF_ADDR     => BUFFER_ADDRESS1,
        BUF_WRITE_EN        => BUFFER_WRITE_EN1,
        
        BUSY                => ACTIVATION_BUSY,
        RESOURCE_BUSY       => ACTIVATION_RESOURCE_BUSY
    );
    
    LOOK_AHEAD_BUFFER_i : LOOK_AHEAD_BUFFER
    port map(
        CLK                 => CLK,
        RESET               => RESET,
        ENABLE              => ENABLE,
        
        INSTRUCTION_BUSY    => INSTRUCTION_BUSY,
        
        INSTRUCTION_INPUT   => INSTRUCTION_PORT,
        INSTRUCTION_WRITE   => INSTRUCTION_ENABLE,
        
        INSTRUCTION_OUTPUT  => INSTRUCTION_OUTPUT,
        INSTRUCTION_READ    => INSTRUCTION_READ
    );
    
    CONTROL_COORDINATOR_i : CONTROL_COORDINATOR
    port map(
        CLK                         => CLK,
        RESET                       => RESET,
        ENABLE                      => ENABLE,
        
        INSTRUCTION                 => INSTRUCTION_OUTPUT,
        INSTRUCTION_EN              => INSTRUCTION_READ,

        BUSY                        => INSTRUCTION_BUSY,

        WEIGHT_BUSY                 => WEIGHT_BUSY,
        WEIGHT_RESOURCE_BUSY        => WEIGHT_RESOURCE_BUSY,
        WEIGHT_INSTRUCTION          => WEIGHT_INSTRUCTION,
        WEIGHT_INSTRUCTION_EN       => WEIGHT_INSTRUCTION_EN,

        MATRIX_BUSY                 => MATRIX_BUSY,
        MATRIX_RESOURCE_BUSY        => MMU_RESOURCE_BUSY,
        MATRIX_INSTRUCTION          => MMU_INSTRUCTION,
        MATRIX_INSTRUCTION_EN       => MMU_INSTRUCTION_EN,

        ACTIVATION_BUSY             => ACTIVATION_BUSY,
        ACTIVATION_RESOURCE_BUSY    => ACTIVATION_RESOURCE_BUSY,
        ACTIVATION_INSTRUCTION      => ACTIVATION_INSTRUCTION,
        ACTIVATION_INSTRUCTION_EN   => ACTIVATION_INSTRUCTION_EN,
        
        SYNCHRONIZE                 => SYNCHRONIZE
    );
    
    BUSY <= INSTRUCTION_BUSY;
end architecture BEH;
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

entity TB_tinyTPU_v1_0_S00_AXI is
end entity TB_tinyTPU_v1_0_S00_AXI;

architecture BEH of TB_tinyTPU_v1_0_S00_AXI is
    component DUT is
        generic (
            -- Users to add parameters here

            -- User parameters ends
            -- Do not modify the parameters beyond this line

            -- Width of S_AXI data bus
            C_S_AXI_DATA_WIDTH	: integer	:= 32;
            -- Width of S_AXI address bus
            C_S_AXI_ADDR_WIDTH	: integer	:= 20
        );
        port (
            -- Users to add ports here

            -- User ports ends
            -- Do not modify the ports beyond this line

            -- Global Clock Signal
            S_AXI_ACLK	: in std_logic;
            -- Global Reset Signal. This Signal is Active LOW
            S_AXI_ARESETN	: in std_logic;
            -- Write address (issued by master, acceped by Slave)
            S_AXI_AWADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
            -- Write channel Protection type. This signal indicates the
                -- privilege and security level of the transaction, and whether
                -- the transaction is a data access or an instruction access.
            S_AXI_AWPROT	: in std_logic_vector(2 downto 0);
            -- Write address valid. This signal indicates that the master signaling
                -- valid write address and control information.
            S_AXI_AWVALID	: in std_logic;
            -- Write address ready. This signal indicates that the slave is ready
                -- to accept an address and associated control signals.
            S_AXI_AWREADY	: out std_logic;
            -- Write data (issued by master, acceped by Slave) 
            S_AXI_WDATA	: in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
            -- Write strobes. This signal indicates which byte lanes hold
                -- valid data. There is one write strobe bit for each eight
                -- bits of the write data bus.    
            S_AXI_WSTRB	: in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
            -- Write valid. This signal indicates that valid write
                -- data and strobes are available.
            S_AXI_WVALID	: in std_logic;
            -- Write ready. This signal indicates that the slave
                -- can accept the write data.
            S_AXI_WREADY	: out std_logic;
            -- Write response. This signal indicates the status
                -- of the write transaction.
            S_AXI_BRESP	: out std_logic_vector(1 downto 0);
            -- Write response valid. This signal indicates that the channel
                -- is signaling a valid write response.
            S_AXI_BVALID	: out std_logic;
            -- Response ready. This signal indicates that the master
                -- can accept a write response.
            S_AXI_BREADY	: in std_logic;
            -- Read address (issued by master, acceped by Slave)
            S_AXI_ARADDR	: in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
            -- Protection type. This signal indicates the privilege
                -- and security level of the transaction, and whether the
                -- transaction is a data access or an instruction access.
            S_AXI_ARPROT	: in std_logic_vector(2 downto 0);
            -- Read address valid. This signal indicates that the channel
                -- is signaling valid read address and control information.
            S_AXI_ARVALID	: in std_logic;
            -- Read address ready. This signal indicates that the slave is
                -- ready to accept an address and associated control signals.
            S_AXI_ARREADY	: out std_logic;
            -- Read data (issued by slave)
            S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
            -- Read response. This signal indicates the status of the
                -- read transfer.
            S_AXI_RRESP	: out std_logic_vector(1 downto 0);
            -- Read valid. This signal indicates that the channel is
                -- signaling the required read data.
            S_AXI_RVALID	: out std_logic;
            -- Read ready. This signal indicates that the master can
                -- accept the read data and response information.
            S_AXI_RREADY	: in std_logic
        );
    end component DUT;
    for all : DUT use entity WORK.tinyTPU_v1_0_S00_AXI(arch_imp);
    
    signal CLK : std_logic;
    signal NRESET : std_logic;
    
    constant C_S_AXI_DATA_WIDTH	    : integer	:= 32;
    constant C_S_AXI_ADDR_WIDTH	    : integer	:= 20;
    
    signal S_AXI_AWADDR	    : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal S_AXI_AWPROT	    : std_logic_vector(2 downto 0);
    signal S_AXI_AWVALID	: std_logic;
    signal S_AXI_AWREADY	: std_logic;
    signal S_AXI_WDATA	    : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal S_AXI_WSTRB	    : std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
    signal S_AXI_WVALID	    : std_logic;
    signal S_AXI_WREADY	    : std_logic;
    signal S_AXI_BRESP	    : std_logic_vector(1 downto 0);
    signal S_AXI_BVALID	    : std_logic;
    signal S_AXI_BREADY	    : std_logic;
    signal S_AXI_ARADDR	    : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    signal S_AXI_ARPROT	    : std_logic_vector(2 downto 0);
    signal S_AXI_ARVALID	: std_logic;
    signal S_AXI_ARREADY	: std_logic;
    signal S_AXI_RDATA	    : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
    signal S_AXI_RRESP	    : std_logic_vector(1 downto 0);
    signal S_AXI_RVALID	    : std_logic;
    signal S_AXI_RREADY	    : std_logic;
    
    -- for clock gen
    constant clock_period   : time := 10 ns;
    signal stop_the_clock   : boolean;
begin
    DUT_i : DUT
    generic map(
        C_S_AXI_DATA_WIDTH => C_S_AXI_DATA_WIDTH,
        C_S_AXI_ADDR_WIDTH => C_S_AXI_ADDR_WIDTH
    )
    port map(
        S_AXI_ACLK      => CLK,
        S_AXI_ARESETN   => NRESET,
        S_AXI_AWADDR    => S_AXI_AWADDR,
        S_AXI_AWPROT    => S_AXI_AWPROT,
        S_AXI_AWVALID   => S_AXI_AWVALID,
        S_AXI_AWREADY   => S_AXI_AWREADY,
        S_AXI_WDATA     => S_AXI_WDATA,
        S_AXI_WSTRB     => S_AXI_WSTRB,
        S_AXI_WVALID    => S_AXI_WVALID,
        S_AXI_WREADY    => S_AXI_WREADY,
        S_AXI_BRESP     => S_AXI_BRESP,
        S_AXI_BVALID    => S_AXI_BVALID,
        S_AXI_BREADY    => S_AXI_BREADY,
        S_AXI_ARADDR    => S_AXI_ARADDR,
        S_AXI_ARPROT    => S_AXI_ARPROT,
        S_AXI_ARVALID   => S_AXI_ARVALID,
        S_AXI_ARREADY   => S_AXI_ARREADY,
        S_AXI_RDATA     => S_AXI_RDATA,
        S_AXI_RRESP     => S_AXI_RRESP,
        S_AXI_RVALID    => S_AXI_RVALID,
        S_AXI_RREADY    => S_AXI_RREADY
    );
    
    STIMULUS:
    process is
        procedure WRITE_PROCEDURE(
            constant ADDRESS : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
            constant DATA    : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
            constant STROBE  : in std_logic_vector(3 downto 0)
        ) is
        begin
            S_AXI_AWADDR <= ADDRESS;
            S_AXI_AWVALID <= '1';
            --wait until S_AXI_AWREADY = '1';
            wait until CLK='1' and CLK'event;
            S_AXI_AWVALID <= '0';
            wait until CLK='1' and CLK'event;
            S_AXI_WDATA <= DATA;
            S_AXI_WSTRB <= STROBE;
            S_AXI_WVALID <= '1';
            --wait until S_AXI_WREADY = '1';
            wait until CLK='1' and CLK'event;
            S_AXI_WVALID <= '0';
            wait until CLK='1' and CLK'event;
            S_AXI_BREADY <= '1';
            --wait until S_AXI_BVALID = '1';
            wait until CLK='1' and CLK'event;
            S_AXI_BREADY <= '0';
            wait until CLK='1' and CLK'event;
        end procedure WRITE_PROCEDURE;
        
        procedure READ_PROCEDURE(
            constant ADDRESS : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0)
        ) is
        begin
            S_AXI_ARADDR <= ADDRESS;
            S_AXI_ARVALID <= '1';
            wait until CLK='1' and CLK'event;
            S_AXI_ARVALID <= '0';
            wait until CLK='1' and CLK'event;
            S_AXI_RREADY <= '1';
            wait until CLK='1' and CLK'event;
            wait until CLK='1' and CLK'event;
            wait until CLK='1' and CLK'event;
            wait until CLK='1' and CLK'event;
            wait until CLK='1' and CLK'event;
            S_AXI_RREADY <= '0';
            wait until CLK='1' and CLK'event;
        end procedure READ_PROCEDURE;
        
        variable INSTRUCTION : INSTRUCTION_TYPE;
    begin
        S_AXI_ARADDR <= (others => '0');
        S_AXI_AWPROT <= (others => '0');
        S_AXI_AWVALID <= '0';
        S_AXI_WDATA <= (others => '0');
        S_AXI_WSTRB <= (others => '0');
        S_AXI_WVALID <= '0';
        S_AXI_BREADY <= '0';
        S_AXI_ARADDR <= (others => '0');
        S_AXI_ARPROT <= (others => '0');
        S_AXI_ARVALID <= '0';
        S_AXI_RREADY <= '0';
        
        NRESET <= '0';
        wait until CLK='1' and CLK'event;
        NRESET <= '1';
        wait until CLK='1' and CLK'event;
        -- Weight buffer write test
        WRITE_PROCEDURE(x"00000", x"AFFEDEAD", "1111"); -- Base address
        WRITE_PROCEDURE(x"00004", x"DEADAFFE", "1111");
        WRITE_PROCEDURE(x"00008", x"12345678", "1111");
        WRITE_PROCEDURE(x"0000C", x"0000B00B", "1111");
        WRITE_PROCEDURE(x"00958", x"12345678", "1111");
        WRITE_PROCEDURE(x"7FFFC", x"0000B00B", "1111"); -- End address
        -- Unified buffer write test
        WRITE_PROCEDURE(x"80000", x"AFFEDEAD", "1111"); -- Base address
        WRITE_PROCEDURE(x"80004", x"DEADAFFE", "1111");
        WRITE_PROCEDURE(x"80008", x"12345678", "1111");
        WRITE_PROCEDURE(x"8000C", x"0000B00B", "1111");
        WRITE_PROCEDURE(x"80958", x"12345678", "1111");
        WRITE_PROCEDURE(x"8FFFC", x"0000B00B", "1111"); -- End address
        -- Instruction fifo write test
        WRITE_PROCEDURE(x"90000", x"AFFEDEAD", "1111"); -- Base address, shouldn't do anything
        
        INSTRUCTION.OP_CODE := "00001000"; -- load weight
        INSTRUCTION.CALC_LENGTH := std_logic_vector(to_unsigned(14, LENGTH_WIDTH));
        INSTRUCTION.BUFFER_ADDRESS := x"000000";
        INSTRUCTION.ACC_ADDRESS := x"0000";
        
        WRITE_PROCEDURE(x"90004", INSTRUCTION_TO_BITS(INSTRUCTION)(1*4*BYTE_WIDTH-1 downto 0*4*BYTE_WIDTH), "1111"); -- Write lower instruction word
        WRITE_PROCEDURE(x"90008", INSTRUCTION_TO_BITS(INSTRUCTION)(2*4*BYTE_WIDTH-1 downto 1*4*BYTE_WIDTH), "1111"); -- Write middle instruction word
        WRITE_PROCEDURE(x"9000C", x"0000" & INSTRUCTION_TO_BITS(INSTRUCTION)(2*4*BYTE_WIDTH + 2*BYTE_WIDTH-1 downto 2*4*BYTE_WIDTH), "1111"); -- Write upper instruction word
        
        -- Weight buffer read test - shouldn't do anything
        READ_PROCEDURE(x"00000");
        READ_PROCEDURE(x"00004");
        READ_PROCEDURE(x"00008");
        READ_PROCEDURE(x"0000C");
        READ_PROCEDURE(x"00958");
        READ_PROCEDURE(x"7FFFC");
        -- Unified buffer read test
        READ_PROCEDURE(x"80000");
        READ_PROCEDURE(x"80004");
        READ_PROCEDURE(x"80008");
        READ_PROCEDURE(x"8000C");
        READ_PROCEDURE(x"80958");
        READ_PROCEDURE(x"8FFFC");
        -- Instruction fifo read test
        READ_PROCEDURE(x"90000"); -- should be TPU max index
        READ_PROCEDURE(x"90004"); -- shouldn't do anything
        READ_PROCEDURE(x"90008"); -- shouldn't do anything
        READ_PROCEDURE(x"9000C"); -- shouldn't do anything
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
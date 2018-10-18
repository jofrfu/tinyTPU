// Copyright 2018 Jonas Fuhrmann. All rights reserved.
//
// This project is dual licensed under GNU General Public License version 3
// and a commercial license available on request.
//-------------------------------------------------------------------------
// For non commercial use only:
// This file is part of tinyTPU.
// 
// tinyTPU is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// tinyTPU is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with tinyTPU. If not, see <http://www.gnu.org/licenses/>.

#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"
#include "xil_io.h"
#include "tinyTPU.h"
#include "xil_exception.h"
#include "xscugic.h"
#include "xparameters.h"
#include "xparameters_ps.h"

#define TPU_BASE 				XPAR_TINYTPU_0_S00_AXI_BASEADDR
#define TPU_WEIGHT_BUFFER_BASE  (TPU_BASE)
#define TPU_UNIFIED_BUFFER_BASE (TPU_BASE + 0x80000)
#define TPU_INSTRUCTION_BASE    (TPU_BASE + 0x90000)

#define TPU_LOWER_WORD_OFFSET  0x4
#define TPU_MIDDLE_WORD_OFFSET 0x8
#define TPU_UPPER_WORD_OFFSET  0xC

#define TPU_DEVICE_ID		XPAR_TINYTPU_0_DEVICE_ID
#define INTC_TPU_SYNCHRONIZE_ID	XPS_FPGA2_INT_ID

static XScuGic INTCInst;

#ifdef STANDARD
int setup_interrupt(void);
void synchronize_isr(void *vp);

volatile char synchronizeHappened;


int main() {
    init_platform();

    synchronizeHappened = FALSE;
    if(setup_interrupt() != XST_SUCCESS) {
    	printf("Error initializing interrupts.");
    }

    // Nearly identity matrix
    uint8_t weights[14][14] = {
    		{0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
			{0, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
			{0, 0, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
			{0, 0, 0, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
			{0, 0, 0, 0, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0},
			{0, 0, 0, 0, 0, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0},
			{0, 0, 0, 0, 0, 0, 0xFF, 0, 0, 0, 0, 0, 0, 0},
			{0, 0, 0, 0, 0, 0, 0, 0xFF, 0, 0, 0, 0, 0, 0},
			{0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0, 0, 0, 0, 0},
			{0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0, 0, 0, 0},
			{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0, 0, 0},
			{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0, 0},
			{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0},
			{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xFF}
    };

    // Any input matrix for testing
    uint8_t input[14][14] = {
    		{0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D},
			{0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D},
			{0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D},
			{0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D},
			{0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D},
			{0x50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D},
			{0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D},
			{0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D},
			{0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D},
			{0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D},
			{0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD},
			{0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD},
			{0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB, 0xCC, 0xCD},
			{0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB, 0xDC, 0xDD}
    };

    printf("Welcome!\n\r");

    printf("Press any key to test.\n\r");
    uint8_t serial_input;
    scanf("%c", &serial_input);

    printf("Size of TPU is %d.\n\r", TINYTPU_mReadReg(TPU_INSTRUCTION_BASE, 0)+1);

    printf("Writing weights to weight buffer.\n\r");
    for(int32_t i = 0; i < 14; i++) {
    	for(int32_t j = 0; j < 14; j+=4) {
    		uint32_t current = 0;
    		current |= weights[i][j];
    		if(j+1 < 14) {
    			current |= (weights[i][j+1] << 8);
    		}
    		if(j+2 < 14) {
    			current |= (weights[i][j+2] << 16);
    		}
    		if(j+3 < 14) {
    			current |=  (weights[i][j+3] << 24);
    		}

    		uint32_t addr = (i*4*4)+j;
    		printf("Writing %#010X to %#010X\n\r", current, TPU_WEIGHT_BUFFER_BASE+addr);
    		TINYTPU_mWriteReg(TPU_WEIGHT_BUFFER_BASE, addr, current);
    		printf("Wrote %#010X to %#010X\n\r", current, TPU_WEIGHT_BUFFER_BASE+addr);
    	}
    }

    printf("Writing input to unified buffer.\n\r");
	for(int32_t i = 0; i < 14; i++) {
		for(int32_t j = 0; j < 14; j+=4) {
			uint32_t current = 0;
			current |= input[i][j];
			if(j+1 < 14) {
				current |= (input[i][j+1] << 8);
			}
			if(j+2 < 14) {
				current |= (input[i][j+2] << 16);
			}
			if(j+3 < 14) {
				current |=  (input[i][j+3] << 24);
			}

			uint32_t addr = (i*4*4)+j;
			printf("Writing %#010X to %#010X\n\r", current, TPU_UNIFIED_BUFFER_BASE+addr);
			TINYTPU_mWriteReg(TPU_UNIFIED_BUFFER_BASE, addr, current);
			printf("Wrote %#010X to %#010X\n\r", current, TPU_UNIFIED_BUFFER_BASE+addr);
		}
	}

	printf("Reading from unified buffer.\n\r");
	for(int32_t i = 0; i < 14; i++) {
		for(int32_t j = 0; j < 14; j+=4) {
			uint32_t addr = (i*4*4)+j;
			uint32_t current = TINYTPU_mReadReg(TPU_UNIFIED_BUFFER_BASE, addr);
			printf("Read %#010X from %#010X\n\r", current, TPU_UNIFIED_BUFFER_BASE+addr);
		}
	}

	printf("Writing instructions to instruction FIFO.\n\r");
	uint8_t instruction[10];

	instruction[0] = 0b00001000; // load weights unsigned
	instruction[1] = 14;
	instruction[2] = 0;
	instruction[3] = 0;
	instruction[4] = 0;
	instruction[5] = 0;
	instruction[6] = 0;
	instruction[7] = 0;
	instruction[8] = 0;
	instruction[9] = 0;

	TINYTPU_mWriteReg(TPU_INSTRUCTION_BASE, TPU_LOWER_WORD_OFFSET , *((uint32_t*) instruction   ));
	TINYTPU_mWriteReg(TPU_INSTRUCTION_BASE, TPU_MIDDLE_WORD_OFFSET, *((uint32_t*)(instruction+4)));
	TINYTPU_mWriteReg(TPU_INSTRUCTION_BASE, TPU_UPPER_WORD_OFFSET , *((uint16_t*)(instruction+8)));

	printf("Wrote 0X%04X%08X%08X\n\r", *((uint16_t*)(instruction+8)), *((uint32_t*)(instruction+4)), *((uint32_t*) instruction));

	instruction[0] = 0b00100000; // matrix multiply unsigned

	TINYTPU_mWriteReg(TPU_INSTRUCTION_BASE, TPU_LOWER_WORD_OFFSET , *((uint32_t*) instruction   ));
	TINYTPU_mWriteReg(TPU_INSTRUCTION_BASE, TPU_MIDDLE_WORD_OFFSET, *((uint32_t*)(instruction+4)));
	TINYTPU_mWriteReg(TPU_INSTRUCTION_BASE, TPU_UPPER_WORD_OFFSET , *((uint16_t*)(instruction+8)));

	printf("Wrote 0X%04X%08X%08X\n\r", *((uint16_t*)(instruction+8)), *((uint32_t*)(instruction+4)), *((uint32_t*) instruction));

	instruction[0] = 0b10001001; // activation unsigned sigmoid
	instruction[7] = 0xE;

	TINYTPU_mWriteReg(TPU_INSTRUCTION_BASE, TPU_LOWER_WORD_OFFSET , *((uint32_t*) instruction   ));
	TINYTPU_mWriteReg(TPU_INSTRUCTION_BASE, TPU_MIDDLE_WORD_OFFSET, *((uint32_t*)(instruction+4)));
	TINYTPU_mWriteReg(TPU_INSTRUCTION_BASE, TPU_UPPER_WORD_OFFSET , *((uint16_t*)(instruction+8)));

	printf("Wrote 0X%04X%08X%08X\n\r", *((uint16_t*)(instruction+8)), *((uint32_t*)(instruction+4)), *((uint32_t*) instruction));

	instruction[0] = 0b11111111; // synchronize
	instruction[1] = 0;
	instruction[2] = 0;
	instruction[3] = 0;
	instruction[4] = 0;
	instruction[5] = 0;
	instruction[6] = 0;
	instruction[7] = 0;
	instruction[8] = 0;
	instruction[9] = 0;

	TINYTPU_mWriteReg(TPU_INSTRUCTION_BASE, TPU_LOWER_WORD_OFFSET , *((uint32_t*) instruction   ));
	TINYTPU_mWriteReg(TPU_INSTRUCTION_BASE, TPU_MIDDLE_WORD_OFFSET, *((uint32_t*)(instruction+4)));
	TINYTPU_mWriteReg(TPU_INSTRUCTION_BASE, TPU_UPPER_WORD_OFFSET , *((uint16_t*)(instruction+8)));

	printf("Wrote 0X%04X%08X%08X\n\r", *((uint16_t*)(instruction+8)), *((uint32_t*)(instruction+4)), *((uint32_t*) instruction));

	while(!synchronizeHappened);

	printf("Reading results from unified buffer.\n\r");
	for(int32_t i = 0; i < 14; i++) {
		for(int32_t j = 0; j < 14; j+=4) {
			uint32_t addr = (i*4*4)+j;
			uint32_t current = TINYTPU_mReadReg(TPU_UNIFIED_BUFFER_BASE, 14*16 + addr);
			printf("%#02X ", (uint8_t)current);
			if(j+1 < 14) {
				printf("%#02X ", (uint8_t)(current >> 8));
			}
			if(j+2 < 14) {
				printf("%#02X ", (uint8_t)(current >> 8));
			}
			if(j+3 < 14) {
				printf("%#02X ", (uint8_t)(current >> 8));
			}

		}
		printf("\n\r");
	}

    cleanup_platform();
    return 0;
}

int setup_interrupt(void) {
	int result;
	XScuGic *intc_instance_ptr = &INTCInst;
	XScuGic_Config *intc_config;

	// get config for interrupt controller
	intc_config = XScuGic_LookupConfig(XPAR_PS7_SCUGIC_0_DEVICE_ID);
	if(NULL == intc_config) return XST_FAILURE;

	//initialize the interrupt controller driver
	result = XScuGic_CfgInitialize(intc_instance_ptr, intc_config, intc_config->CpuBaseAddress);

	if(result != XST_SUCCESS) return result;

	// set priority of IRQ_F2P[2:2] to 0xA0 and trigger for rising edge 0x3.
	XScuGic_SetPriorityTriggerType(intc_instance_ptr, INTC_TPU_SYNCHRONIZE_ID, 0xA0, 0x3);

	// connect the interrupt service routine to the interrupt controller
	result = XScuGic_Connect(intc_instance_ptr, INTC_TPU_SYNCHRONIZE_ID, (Xil_ExceptionHandler) synchronize_isr, (void*) &INTCInst);

	if(result != XST_SUCCESS) return result;

	// enable interrupt
	XScuGic_Enable(intc_instance_ptr, INTC_TPU_SYNCHRONIZE_ID);

	// initialize the exception table and register the interrupt controller handler with the exception table
	Xil_ExceptionInit();
	Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler) XScuGic_InterruptHandler, intc_instance_ptr);

	// enable non-critical exceptions
	Xil_ExceptionEnable();

	return XST_SUCCESS;
}

void synchronize_isr(void *vp) {
	synchronizeHappened = TRUE;
}
#endif

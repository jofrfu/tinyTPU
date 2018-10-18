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

/*
 * simple_tpu_test.c
 *
 *  Created on: 21.09.2018
 *      Author: Jonas Fuhrmann
 */

#include "simple_tpu_test.h"
#include "tinyTPU_access.h"
#include <stdio.h>
#include "xil_exception.h"
#include "xscugic.h"
#include "xparameters.h"
#include "xparameters_ps.h"

static XScuGic INTCInst;

volatile char synchronizeHappened;
#ifdef TEST
void test_simple_net(void) {
	synchronizeHappened = FALSE;
	if(setup_interrupt() != XST_SUCCESS) {
		printf("Error initializing interrupts.\n\r");
	}

	tpu_vector_t matrix[TPU_VECTOR_SIZE];

	printf("Input matrix:\n\r");
	for(int32_t i = 0; i < TPU_VECTOR_SIZE; ++i) {
		for(int32_t j = 0; j < TPU_VECTOR_SIZE; ++j) {
			matrix[i].byte_vector[j] = (i<<4)+j;
			printf("0x%02x ", matrix[i].byte_vector[j]);
		}
		printf("to address 0x%08x\n\r", i);
		if(write_input_vector(&matrix[i], i)) {
			printf("Bad address!\n\r");
			return;
		}
	}

	printf("Weight matrix:\n\r");
	for(int32_t i = 0; i < TPU_VECTOR_SIZE; ++i) {
		for(int32_t j = 0; j < TPU_VECTOR_SIZE; ++j) {
			if(i == j) {
				matrix[i].byte_vector[j] = 0xFF;
			} else {
				matrix[i].byte_vector[j] = 0x00;
			}
			printf("0x%02x ", matrix[i].byte_vector[j]);
		}
		printf("to address 0x%08x\n\r", i);
		if(write_weight_vector(&matrix[i], i)) {
			printf("Bad address!\n\r");
			return;
		}
	}

	instruction_t instruction;
	instruction.op_code = 0b00001000; // load weights unsigned
	instruction.calc_length[0] = 14;
	instruction.calc_length[1] = 0;
	instruction.calc_length[2] = 0;
	instruction.calc_length[3] = 0;
	instruction.weight_address[0] = 0;
	instruction.weight_address[1] = 0;
	instruction.weight_address[2] = 0;
	instruction.weight_address[3] = 0;
	instruction.weight_address[4] = 0;

	write_instruction(&instruction);

	instruction.op_code = 0b00100000; // matrix multiply unsigned
	instruction.calc_length[0] = 14;
	instruction.calc_length[1] = 0;
	instruction.calc_length[2] = 0;
	instruction.calc_length[3] = 0;
	instruction.acc_address[0] = 0;
	instruction.acc_address[1] = 0;
	instruction.buf_address[0] = 0;
	instruction.buf_address[1] = 0;
	instruction.buf_address[2] = 0;

	write_instruction(&instruction);

	instruction.op_code = 0b10001001; // sigmoid activation unsigned
	instruction.calc_length[0] = 14;
	instruction.calc_length[1] = 0;
	instruction.calc_length[2] = 0;
	instruction.calc_length[3] = 0;
	instruction.acc_address[0] = 0;
	instruction.acc_address[1] = 0;
	instruction.buf_address[0] = 14;
	instruction.buf_address[1] = 0;
	instruction.buf_address[2] = 0;

	write_instruction(&instruction);

	instruction.op_code = 0b11111111; // synchronize
	instruction.calc_length[0] = 0;
	instruction.calc_length[1] = 0;
	instruction.calc_length[2] = 0;
	instruction.calc_length[3] = 0;
	instruction.acc_address[0] = 0;
	instruction.acc_address[1] = 0;
	instruction.buf_address[0] = 0;
	instruction.buf_address[1] = 0;
	instruction.buf_address[2] = 0;

	write_instruction(&instruction);

	while(!synchronizeHappened);

	tpu_vector_t result;

	printf("Output matrix:\n\r");
	for(int32_t i = TPU_VECTOR_SIZE; i < 2*TPU_VECTOR_SIZE; ++i) {
		if(read_output_vector(&result, i)) {
			printf("Bad address!\n\r");
		}
		for(int32_t j = 0; j < TPU_VECTOR_SIZE; ++j) {
			printf("0x%02x ", result.byte_vector[j]);
		}
		printf("from address 0x%08x\n\r", i);
	}
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
	XScuGic_SetPriorityTriggerType(intc_instance_ptr, INTC_TPU_DEVICE_ID, 0xA0, 0x3);

	// connect the interrupt service routine to the interrupt controller
	result = XScuGic_Connect(intc_instance_ptr, INTC_TPU_DEVICE_ID, (Xil_ExceptionHandler) synchronize_isr, (void*) &INTCInst);

	if(result != XST_SUCCESS) return result;

	// enable interrupt
	XScuGic_Enable(intc_instance_ptr, INTC_TPU_DEVICE_ID);

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

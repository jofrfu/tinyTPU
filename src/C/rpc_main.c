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
 * rpc_main.c
 *
 *  Created on: 27.09.2018
 *      Author: Jonas Fuhrmann
 */



#include "tinyTPU_access.h"
#include "platform.h"
#include "xil_exception.h"
#include "xscugic.h"
#include "xparameters.h"
#include "xparameters_ps.h"
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>

#define WEIGHTS "weights:["
#define INPUTS "inputs:["
#define INSTRUCTIONS "instructions:["
#define END "]"

#define INTC_TPU_SYNCHRONIZE_ID	XPS_FPGA0_INT_ID


#ifdef RPC
static XScuGic INTCInst;

volatile char synchronize_happened;

int setup_interrupt(void);
void synchronize_isr(void* vp);

int main(void) {
	init_platform();

	synchronize_happened = 0;
	if(setup_interrupt() != XST_SUCCESS) printf("Coulnd't configure interrupts!\n\r");

	char message[1024];

	while(1) {
		printf("Enter message:\n\r");
		scanf("%s", message);

		printf("Message was: %s\n\r", message);

		uint32_t weight_addr = 0;
		if(strncmp(WEIGHTS, message, sizeof(WEIGHTS)) == 0) {
			scanf("%s", message);
			while(strncmp(END, message, sizeof(END)) != 0) {
				tpu_vector_t vector;

				uint32_t i = 0;
				char *str = strtok(message, "[,]");
				while(str != NULL) {
					if(i >= TPU_VECTOR_SIZE) {
						printf("Vector out of bounds!\n\r");
					}
					vector.byte_vector[i++] = atoi(str);
					//printf("Added %hhd\n\r", vector.byte_vector[i-1]);
				 	str = strtok(NULL, "[,]");
				}

				if(i < TPU_VECTOR_SIZE) {
					printf("Vector to small!\n\r");
				}

				if(write_weight_vector(&vector, weight_addr++)) {
					printf("Bad address!\n\r");
				} else {
					printf("Wrote 0x%04x%08x%08x%08x to 0x%08x\n\r", vector.transfer_vector[3], vector.transfer_vector[2], vector.transfer_vector[1], vector.transfer_vector[0], weight_addr-1);
				}

				scanf("%s", message);
			}
		}

		uint32_t input_addr = 0;
		if(strncmp(INPUTS, message, sizeof(INPUTS)) == 0) {
			scanf("%s", message);
			while(strncmp(END, message, sizeof(END)) != 0) {
				tpu_vector_t vector;

				uint32_t i = 0;
				char *str = strtok(message, "[,]");
				while(str != NULL) {
					if(i >= TPU_VECTOR_SIZE) {
						printf("Vector out of bounds!\n\r");
					}
					vector.byte_vector[i++] = atoi(str);
					//printf("Added 0x%02x\n\r", vector.byte_vector[i-1]);
					str = strtok(NULL, "[,]");
				}
				if(i < TPU_VECTOR_SIZE-1) {
					printf("Vector to small!\n\r");
				}

				if(write_input_vector(&vector, input_addr++)) {
					printf("Bad address!\n\r");
				} /*else {
					printf("Wrote to 0x%08x\n\r", input_addr-1);
				}*/

				scanf("%s", message);
			}
		}

		if(strncmp(INSTRUCTIONS, message, sizeof(INSTRUCTIONS)) == 0) {
			instruction_t instructions[512];
			char done = 0;
			while(!done) {
				int32_t i = 0;
				for(; i < sizeof(instructions); ++i) {
					scanf("%s", message);

					if(strncmp(END, message, sizeof(END)) == 0) {
						done = 1;
						break;
					}

					uint32_t j = 0;

					uint8_t op_code;
					uint32_t calc_length;
					uint16_t acc_addr;
					uint32_t buffer_addr;
					uint64_t weight_addr;

					char *str = strtok(message, "[,]");
					while(str != NULL) {
						if(j >= 4) {
							printf("Out of bounds!\n\r");
						}

						switch(j) {
							case 0:
								op_code = strtoul(str, NULL, 0);
								break;
							case 1:
								calc_length = strtoul(str, NULL, 0);
								break;
							case 2:
								acc_addr = strtoul(str, NULL, 0);
								weight_addr = strtoul(str, NULL, 0);
								break;
							case 3:
								buffer_addr = strtoul(str, NULL, 0);
								break;
						}

						j++;
						str = strtok(NULL, "[,]");
					}

					instructions[i].op_code = op_code;
					instructions[i].calc_length[0] = calc_length;
					instructions[i].calc_length[1] = calc_length >> 8;
					instructions[i].calc_length[2] = calc_length >> 16;
					instructions[i].calc_length[3] = calc_length >> 24;

					if(j <= 3) {
						instructions[i].weight_address[0] = weight_addr;
						instructions[i].weight_address[1] = weight_addr >> 8;
						instructions[i].weight_address[2] = weight_addr >> 16;
						instructions[i].weight_address[3] = weight_addr >> 24;
						instructions[i].weight_address[4] = weight_addr >> 32;
					} else {
						instructions[i].acc_address[0] = acc_addr;
						instructions[i].acc_address[1] = acc_addr >> 8;
						instructions[i].buf_address[0] = buffer_addr;
						instructions[i].buf_address[1] = buffer_addr >> 8;
						instructions[i].buf_address[2] = buffer_addr >> 16;
					}

					printf("Added instruction 0x%04x%08x%08x\n\r", instructions[i].upper_word, instructions[i].middle_word, instructions[i].lower_word);
				}

				for(uint32_t x = 0; x < i; ++x) {
					write_instruction(&instructions[x]);
				}
			}
			while(!synchronize_happened);
			synchronize_happened = 0;
			printf("Calculations finished.\n\r");
			uint32_t cycles;
			if(read_runtime(&cycles)) {
				printf("Bad address!\n\r");
			} else {
				printf("Calculations took %d cycles/%f nanoseconds to complete.\n\r", cycles, cycles*TPU_CLOCK_CYCLE);
			}
		}
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

	// set priority of IRQ_F2P[0:0] to 0x00 and trigger for rising edge 0x3.
	XScuGic_SetPriorityTriggerType(intc_instance_ptr, INTC_TPU_SYNCHRONIZE_ID, 0x00, 0x3);
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
	synchronize_happened = 1;
}

#endif


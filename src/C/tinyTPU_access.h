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
 * tinyTPU_access.h
 *
 *  Created on: 20.09.2018
 *      Author: Jonas Fuhrmann
 */

#ifndef SRC_TINYTPU_ACCESS_H_
#define SRC_TINYTPU_ACCESS_H_

#include <stdint.h>

#define TPU_BASE 				(0x43C00000)
#define TPU_WEIGHT_BUFFER_BASE  (TPU_BASE)
#define TPU_UNIFIED_BUFFER_BASE (TPU_BASE + 0x80000)
#define TPU_INSTRUCTION_BASE    (TPU_BASE + 0x90000)

#define TPU_LOWER_WORD_OFFSET  0x4
#define TPU_MIDDLE_WORD_OFFSET 0x8
#define TPU_UPPER_WORD_OFFSET  0xC

#define TPU_VECTOR_SIZE 14
// For byte padding
#define TPU_VECTOR_PADDING (TPU_VECTOR_SIZE+2)

#define WEIGHT_BUFFER_SIZE 32768
#define UNIFIED_BUFFER_SIZE 4096

#define TPU_CLOCK_CYCLE 5.625f

#define WRITE_32(addr, data)(*(volatile uint32_t *) (addr) = (data));
#define WRITE_16(addr, data)(*(volatile uint16_t *) (addr) = (data));
#define READ_32(addr)(*(volatile uint32_t *) (addr));

typedef union tpu_vector {
	uint8_t byte_vector[TPU_VECTOR_SIZE];
	uint32_t transfer_vector[TPU_VECTOR_PADDING/sizeof(uint32_t)];
} tpu_vector_t;

/**
 * Instruction type definition
 */
typedef union __attribute__((__packed__)) instruction {
	// Assignment structure
	struct {
		uint8_t op_code;
		uint8_t calc_length[4];
		union {
			struct {
				uint8_t acc_address[2];
				uint8_t buf_address[3];
			};
			uint8_t weight_address[5];
		};
	};
	// Access structure
	struct {
		uint32_t lower_word;
		uint32_t middle_word;
		uint16_t upper_word;
	};
} instruction_t;

int32_t write_weight_vector(tpu_vector_t *weight_vector, uint32_t weight_address);

int32_t write_input_vector(tpu_vector_t *input_vector, uint32_t buffer_address);

int32_t read_output_vector(tpu_vector_t *output_vector, uint32_t buffer_address);

int32_t write_instruction(instruction_t *instruction);

int32_t read_runtime(uint32_t* runtime_cycles);

#endif /* SRC_TINYTPU_ACCESS_H_ */

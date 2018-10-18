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
 * tinyTPU_access.c
 *
 *  Created on: 20.09.2018
 *      Author: Jonas Fuhrmann
 */

#include "tinyTPU_access.h"
#include <errno.h>
#include <math.h>

int32_t write_weight_vector(tpu_vector_t *weight_vector, uint32_t weight_address) {
	if(weight_address >= WEIGHT_BUFFER_SIZE) return EFAULT;

	weight_address <<= (uint32_t)(ceil(log2(TPU_VECTOR_SIZE)));

	for(uint32_t i = 0; i < TPU_VECTOR_SIZE; i+=sizeof(uint32_t)) {
		WRITE_32(TPU_WEIGHT_BUFFER_BASE+weight_address+i, weight_vector->transfer_vector[i/sizeof(uint32_t)]);
	}

	return 0;
}

int32_t write_input_vector(tpu_vector_t *input_vector, uint32_t buffer_address) {
	if(buffer_address >= UNIFIED_BUFFER_SIZE) return EFAULT;

	buffer_address <<= (uint32_t)(ceil(log2(TPU_VECTOR_SIZE)));

	for(uint32_t i = 0; i < TPU_VECTOR_SIZE; i+=sizeof(uint32_t)) {
		WRITE_32(TPU_UNIFIED_BUFFER_BASE+buffer_address+i, input_vector->transfer_vector[i/sizeof(uint32_t)]);
	}

	return 0;
}

int32_t read_output_vector(tpu_vector_t *output_vector, uint32_t buffer_address) {
	if(buffer_address >= UNIFIED_BUFFER_SIZE) return EFAULT;

	buffer_address <<= (uint32_t)(ceil(log2(TPU_VECTOR_SIZE)));

	for(uint32_t i = 0; i < TPU_VECTOR_SIZE; i+=sizeof(uint32_t)) {
		output_vector->transfer_vector[i/sizeof(uint32_t)] = READ_32(TPU_UNIFIED_BUFFER_BASE+buffer_address+i);
	}

	return 0;
}

int32_t write_instruction(instruction_t *instruction) {
	WRITE_32(TPU_INSTRUCTION_BASE+TPU_LOWER_WORD_OFFSET, instruction->lower_word);
	WRITE_32(TPU_INSTRUCTION_BASE+TPU_MIDDLE_WORD_OFFSET, instruction->middle_word);
	WRITE_16(TPU_INSTRUCTION_BASE+TPU_UPPER_WORD_OFFSET, instruction->upper_word);

	return 0;
}

int32_t read_runtime(uint32_t* runtime_cycles) {
	*runtime_cycles = READ_32(TPU_INSTRUCTION_BASE);

	return 0;
}

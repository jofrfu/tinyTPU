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
 * type_test.c
 *
 *  Created on: 21.09.2018
 *      Author: Jonas Fuhrmann
 */

#include "type_test.h"
#include "tinyTPU_access.h"
#include <stdio.h>

void test_vector_type(void) {
	printf("Testing vector type.\n\r");

	tpu_vector_t vector;

	for(int32_t i = 0; i < sizeof(vector.byte_vector); ++i) {
		vector.byte_vector[i] = i;
	}

	printf("Byte array: 0x");
	for(int32_t i = 0; i < sizeof(vector.byte_vector); ++i) {
		printf("%02x", vector.byte_vector[sizeof(vector.byte_vector)-1-i]);
	}
	printf("\n\r");

	printf("Word array: 0x");
	for(int32_t i = 0; i < 4; ++i) {
		printf("%08x", vector.transfer_vector[3-i]);
	}
	printf("\n\r");
}

void test_instruction_type(void) {
	printf("Testing instruction type.\n\r");

	instruction_t instruction;

	instruction.op_code = 0xAB;
	instruction.calc_length[0] = 0x0D;
	instruction.calc_length[1] = 0x00;
	instruction.calc_length[2] = 0x00;
	instruction.calc_length[3] = 0x00;
	instruction.acc_address[0] = 0x02;
	instruction.acc_address[1] = 0x00;
	instruction.buf_address[0] = 0x00;
	instruction.buf_address[1] = 0xFF;
	instruction.buf_address[2] = 0x00;

	printf("Byte array: 0x");
	for(int32_t i = 0; i < 10; ++i) {
		printf("%02x", ((uint8_t*)(&instruction))[9-i]);
	}
	printf("\n\r");

	printf("Word representation: 0x%04x%08x%08x\n\r", instruction.upper_word, instruction.middle_word, instruction.lower_word);
}

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
 * access_test.c
 *
 *  Created on: 21.09.2018
 *      Author: Jonas Fuhrmann
 */

#include "access_test.h"
#include "tinyTPU_access.h"
#include <stdlib.h>
#include <stdio.h>

#define SEED 176

void test_unified_access(void) {
	tpu_vector_t vector;

	srand(SEED);
	for(uint32_t address = 0; address < UNIFIED_BUFFER_SIZE; ++address) {
		for(int32_t i = 0; i < sizeof(vector.byte_vector); ++i) {
			vector.byte_vector[i] = rand();
		}

		if(write_input_vector(&vector, address)) {
			printf("Bad address on write!\n\r");
			return;
		}
	}

	srand(SEED);
	for(uint32_t address = 0; address < UNIFIED_BUFFER_SIZE; ++address) {
		if(read_output_vector(&vector, address)) {
			printf("Bad address on read!\n\r");
			return;
		}

		for(int32_t i = 0; i < sizeof(vector.byte_vector); ++i) {
			uint8_t value = rand();
			if(value != vector.byte_vector[i]) {
				printf("Read wrong value at address 0x%08x! Value was 0x%02x but should be 0x%02x.\n\r", address, vector.byte_vector[i], value);
				return;
			}
		}
	}

	printf("Unified buffer test was successful!\n\r");
}

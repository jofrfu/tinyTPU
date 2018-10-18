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
 *  Created on: 21.09.2018
 *      Author: Jonas Fuhrmann
 */

#include "type_test.h"
#include "access_test.h"
#include "simple_tpu_test.h"
#include "platform.h"

#ifdef TEST
int main(void) {
	init_platform();
	test_vector_type();
	test_instruction_type();
	test_unified_access();
	test_simple_net();
	cleanup_platform();
	return 0;
}
#endif

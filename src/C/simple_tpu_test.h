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
 * simple_tpu_test.h
 *
 *  Created on: 21.09.2018
 *      Author: Jonas Fuhrmann
 */

#ifndef SRC_SIMPLE_TPU_TEST_H_
#define SRC_SIMPLE_TPU_TEST_H_

#define TPU_DEVICE_ID		XPAR_TINYTPU_0_DEVICE_ID
#define INTC_TPU_SYNCHRONIZE_ID	XPS_FPGA2_INT_ID

void test_simple_net(void);
#ifdef TEST
int setup_interrupt(void);
void synchronize_isr(void *vp);
#endif

#endif /* SRC_SIMPLE_TPU_TEST_H_ */

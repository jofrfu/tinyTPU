# Copyright 2018 Jonas Fuhrmann. All rights reserved.
#
# This project is dual licensed under GNU General Public License version 3
# and a commercial license available on request.
#-------------------------------------------------------------------------
# For non commercial use only:
# This file is part of tinyTPU.
# 
# tinyTPU is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# tinyTPU is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with tinyTPU. If not, see <http://www.gnu.org/licenses/>.

import numpy as np
import serial
import os
import re
import sys

# Instructions are formatted like this:
# op_code - calc_length - acc_addr - buffer_addr
# [uint8,uint32,uint16,uint24]
# or
# op_code - calc_length - weight_addr
# [uint8,uint32,uint40]

TPU_WIDTH = int(sys.argv[1])

# Open file
file = open("instructions.txt", 'w')

p = re.compile('^kernel\d+\.csv$')

# get all sorted layer file path names
list = os.listdir('.')
remove_list = []
for path in list:
    if p.match(path) == None:
        remove_list.append(path)

for path in remove_list:
    list.remove(path)
    
list.sort()
print(str(list))

file.write("instructions:[\n")

weight_count = 0;
input_count = 0;

for path in list:
    print("Load " + path + ":")
    weights = np.loadtxt(path, dtype=np.int8, delimiter=',')
    print(str(weights))
    
    # Get appending size to fit the size of the TPU
    appendix_column = (TPU_WIDTH - (len(weights[0]) % TPU_WIDTH)) % TPU_WIDTH
    print("Column appendix: " + str(appendix_column))
    appendix_row = (TPU_WIDTH - (len(weights) % TPU_WIDTH)) % TPU_WIDTH
    print("Row appendix: " + str(appendix_row))
    
    row_length = int(len(weights)+appendix_row)
    column_length = int((len(weights[0])+appendix_column)/TPU_WIDTH)
    
    print("Rows: " + str(row_length) + " Columns: " + str(column_length))
    
    input_count = input_count + row_length
    input_base = input_count - row_length
    
    for matrix_column in range(column_length):
        print("Column: " + str(matrix_column))
        # Load first signed matrix
        file.write("[9," + str(TPU_WIDTH) + "," + str(matrix_column*row_length + weight_count) + "]\n")
        # First signed matrix multiply without accumulation
        file.write("[33," + str(TPU_WIDTH) + "," + str(matrix_column*TPU_WIDTH) + "," + str(input_base) + "]\n")
        # Load signed weight - complete row exluding the first matrix
        file.write("[9," + str(row_length-TPU_WIDTH) + "," + str(matrix_column*row_length+TPU_WIDTH + weight_count) + "]\n")
        # Signed matrix multiply with accumulation
        file.write("[35," + str(row_length-TPU_WIDTH) + "," + str(matrix_column*TPU_WIDTH) + "," + str(input_base+TPU_WIDTH) + "]\n")
        # Activation - signed sigmoid
        file.write("[153," + str(TPU_WIDTH) + "," + str(matrix_column*TPU_WIDTH) + "," + str(input_count+matrix_column*TPU_WIDTH) + "]\n")
       
    weight_count = weight_count + column_length*row_length
# Synchronize - calculations are finished
file.write("[255,0,0]\n")
    
file.write("]\n")
file.flush()
file.close()
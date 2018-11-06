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

import os
import sys
import numpy as np
from shutil import copyfile

INPUT_NAME = sys.argv[1]
INPUT_NUMBER = int(sys.argv[2])
OUTPUT_OFFSET = int(sys.argv[3])
OUTPUT_NUMBER = int(sys.argv[4])
TPU_WIDTH = int(sys.argv[5])

os.system("transfer_weights.py " + str(TPU_WIDTH))
copyfile("weights.txt", "complete.txt")
f = open("complete.txt", "a")

inputs = np.loadtxt(INPUT_NAME, dtype=np.int8, delimiter=',')

APPEND = 0

for i in range(0, INPUT_NUMBER, TPU_WIDTH):
    f.write("inputs:[\n")
    if (i + TPU_WIDTH) <= len(inputs):
        transfer_input = inputs[i : (i + TPU_WIDTH)]
    else:
        transfer_input = inputs[i : len(inputs)]
        for j in range(0, TPU_WIDTH - (len(inputs) % TPU_WIDTH)):
            transfer_input = np.append(transfer_input, [np.zeros(len(inputs[0]), dtype=np.int8)], axis=0)
    print(str(transfer_input))
    print(transfer_input.shape)
    
    for i in range(0, len(transfer_input[0]), TPU_WIDTH):
        for j in range(0, TPU_WIDTH):
            vector = []
            for k in range(i, i+TPU_WIDTH):
                if k >= len(transfer_input[0]):
                    vector.append(0)
                else:
                    vector.append(str(transfer_input[j][k]))
            
            vector_str = str(vector).replace(" ", "").replace("'", "") + "\n"
            f.write(vector_str)
    f.write("]\n")
    if APPEND == 0:
        os.system("transfer_instructions.py " + str(TPU_WIDTH))
        temp = open("instructions.txt", "r")
        instructions = temp.read()
        temp.close
    f.write(instructions)
    f.write("results:[\n[" + str(OUTPUT_OFFSET) + "," + str(OUTPUT_NUMBER) + "," + str(APPEND) + "]\n]\n")
    APPEND = 1

f.close()
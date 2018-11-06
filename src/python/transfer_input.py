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
import sys

TPU_WIDTH = int(sys.argv[3])

# Open file
file = open("inputs.txt", 'w')

file.write("inputs:[\n")

inputs = np.loadtxt(str(sys.argv[1]), dtype=np.int8, delimiter=',')
if (int(sys.argv[2]) + TPU_WIDTH) <= len(inputs):
    transfer_input = inputs[int(sys.argv[2]) : (int(sys.argv[2]) + TPU_WIDTH)]
else:
    transfer_input = inputs[int(sys.argv[2]) : len(inputs)]
print(str(transfer_input))

for i in range(0, len(transfer_input[0]), TPU_WIDTH):
    for j in range(0, TPU_WIDTH):
        vector = []
        for k in range(i, i+TPU_WIDTH):
            if k >= len(transfer_input[0]):
                vector.append(0)
            else:
                vector.append(str(transfer_input[j][k]))
        
        vector_str = str(vector).replace(" ", "").replace("'", "") + "\n"
        file.write(vector_str)

file.write("]\n")
file.flush()
file.close()
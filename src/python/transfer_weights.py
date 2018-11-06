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
import os
import re
import sys

TPU_WIDTH = int(sys.argv[1])

# Open file
file = open("weights.txt", 'w')

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

file.write("weights:[\n")

for path in list:
    print("Load " + path + ":")
    weights = np.loadtxt(path, dtype=np.int8, delimiter=',')
    print(str(weights))
    
    # Get appending size to fit the size of the TPU
    appendix_column = (TPU_WIDTH - (len(weights[0]) % TPU_WIDTH)) % TPU_WIDTH
    print("Column appendix: " + str(appendix_column))
    appendix_row = (TPU_WIDTH - (len(weights) % TPU_WIDTH)) % TPU_WIDTH
    print("Row appendix: " + str(appendix_row))
    
    row_length = len(weights)+appendix_row
    column_length = len(weights[0])+appendix_column
    
    print("Rows: " + str(row_length) + " Columns: " + str(column_length))
    
    
        
    for matrix_column in range(0, column_length, TPU_WIDTH):
        #print("Column: " + str(matrix_column))
        for matrix_row in range(0, row_length, TPU_WIDTH):
            #print("Row: " + str(matrix_row))
            #print("Next matrix:")
            for sub_matrix_row in range(TPU_WIDTH):
                #print("Subrow: " + str(sub_matrix_row))
                vector = []
                for sub_matrix_column in range(TPU_WIDTH):
                    #print("Subcolumn: " + str(sub_matrix_column))
                    if matrix_row+sub_matrix_row >= len(weights) or matrix_column+sub_matrix_column >= len(weights[0]):
                        vector.append(0)
                    else:
                        vector.append(weights[matrix_row+sub_matrix_row][matrix_column+sub_matrix_column])
                
                vector_str = str(vector).replace(" ", "") + "\n"
                file.write(vector_str)
                #print(vector_str)
 
file.write("]\n")
file.flush()
file.close()
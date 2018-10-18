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

import h5py
import numpy as np
import sys
import re

p = re.compile('kernel')
kernel_num = 0

def export(name, node):
    global kernel_num
    if isinstance(node, h5py.Dataset):
        local_name = p.search(name)
        if local_name != None:
            print("Found node!")
            csv = np.int8(node[()]*128.0)
            np.savetxt(local_name.group(0) + str(kernel_num) + ".csv", csv, fmt='%4d', delimiter=',')
            print(str(csv))
            kernel_num = kernel_num + 1
                    
model_file = h5py.File(str(sys.argv[1]), 'r')
model_file.visititems(export)
model_file.close()
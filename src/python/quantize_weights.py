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

def quantize(name, node):
    if isinstance(node, h5py.Dataset):
        if p.search(name) != None:
            print("Found node!")
            for i in range(len(node)):
                node[i] = np.around(node[i]*128.0)/128.0
                    
model_file = h5py.File(str(sys.argv[1]), 'r+')
model_file.visititems(quantize)
model_file.flush()
model_file.close()
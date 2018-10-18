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

import tensorflow as tf
from tensorflow.keras.constraints import Constraint
import numpy as np

# get the MNIST dataset
mnist = tf.keras.datasets.mnist

# test and train data
(x_train, y_train),(x_test, y_test) = mnist.load_data()
# normalize the input according to int8 from -1 to 127/128
x_train, x_test = (x_train-128.0), (x_test-128.0)

inputs = tf.keras.layers.Input(shape=x_test[0].shape)
prediction = tf.keras.layers.Flatten()(inputs)
model = tf.keras.models.Model(inputs=inputs, outputs=prediction)

x_flattened = model.predict(x_test)

print(str(x_flattened))
np.savetxt("test_input.csv", x_flattened, fmt='%4d', delimiter=',')
np.savetxt("test_label.csv", y_test, fmt='%4d', delimiter=',')
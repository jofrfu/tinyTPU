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
import tensorflow as tf
from tensorflow.keras.constraints import Constraint
from tensorflow.keras import backend as K

class weight_clip(Constraint):
    '''Clips the weights incident to each hidden unit to be inside a range
    '''
    def __init__(self, min=-1.0, max=1.0):
        self.min = min
        self.max = max

    def __call__(self, p):
        return K.clip(p, self.min, self.max)

    def get_config(self):
        return {'min': self.min, 'max': self.max}

x_train = np.array([[127,-128,-128,-128,-128,-128,-128,-128,-128,-128],
                    [-128,127,-128,-128,-128,-128,-128,-128,-128,-128],
                    [-128,-128,127,-128,-128,-128,-128,-128,-128,-128],
                    [-128,-128,-128,127,-128,-128,-128,-128,-128,-128],
                    [-128,-128,-128,-128,127,-128,-128,-128,-128,-128],
                    [-128,-128,-128,-128,-128,127,-128,-128,-128,-128],
                    [-128,-128,-128,-128,-128,-128,127,-128,-128,-128],
                    [-128,-128,-128,-128,-128,-128,-128,127,-128,-128],
                    [-128,-128,-128,-128,-128,-128,-128,-128,127,-128],
                    [-128,-128,-128,-128,-128,-128,-128,-128,-128,127]
                    ])
x_train = x_train/128.0
y_train = np.array([0,1,2,3,4,5,6,7,8,9])

# create the model - only sigmoid can be used by the TPU at the moment
# bias-less NN are easier to compute with the TPU
# weights can only be in a range of -1 to 127/128
model = tf.keras.models.Sequential([
    tf.keras.layers.Flatten(),
    tf.keras.layers.Dense(
        28,
        activation=tf.nn.sigmoid,
        use_bias=False,
        kernel_constraint=weight_clip(-1.0, 127.0/128.0)
    ),
    tf.keras.layers.Dropout(0.2),
    tf.keras.layers.Dense(
        10,
        activation=tf.nn.sigmoid,
        use_bias=False,
        kernel_constraint=weight_clip(-1.0, 127.0/128.0)
    )
])

# compile the model
model.compile(optimizer='adam',
    loss='sparse_categorical_crossentropy',
    metrics=['accuracy']
)

# train the model with 20 epochs
model.fit(x_train, y_train, epochs=1000)
# evaluate test data
#score = model.evaluate(x_test, y_test)
#print(score)
get_3rd_layer_output = K.function([model.layers[0].input],
                                  [model.layers[1].output])
layer_output = get_3rd_layer_output([x_train])[0]

print(str(layer_output))

get_3rd_layer_output = K.function([model.layers[0].input],
                                  [model.layers[3].output])
layer_output = get_3rd_layer_output([x_train])[0]

print(str(layer_output))

model.save("simple_model.h5")

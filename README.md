# tinyTPU
The aim of this project is to create a machine learning co-processor with a similar architecture as Google's Tensor Processing Unit. The implementation is resource-friendly and can be used in different sizes to fit every type of FPGA. This allows the deployment of this co-processor in embedded systems and IoT devices, but it can also be scaled up to be used in data centers and high-perfomance machines. The AXI interface allows usage in a variety of combinations. Evaluations were made on the Xilinx Zynq 7020 SoC.

## Quantization
Unlike the original TPU, this version can only do fixed-point arithmetic. Weights and inputs have to be in the range of -1 to 127/128 or 0 to 255/256.

## Architecture
There are 6 main components, which allow the arithmetic:
- Weight Buffer: BlockRAM, which holds the weights. The buffer can be written from the host-system over the AXI interface.
- Unified Buffer: BlockRAM, which holds the input/output of the net layers. The buffer can be written and read from the host-system over the AXI interface.
- Systolic Data Setup: A set of Registers, which diagonalizes input data read from the Unified Buffer.
- Matrix Multiply Unit (MXU or MMU): The heart of the TPU, a 2 dimensional grid of Multiply-Add units, which can do NxN matrix-multiplies. It reads weights from the Weight Buffer and the diagonalized input from the Systolic Data Setup. The result is stored in a set of accumulators.
- Accumulators: Can accumulate or override the result of the Matrix Multiply Unit to merge splitted up matrix-multiplies.
- Activation: Fused activation functions to activate the result in the accumulators. Sigmoid and (bounded) ReLU are currently supported. The results are stored in the Unified Buffer.

The sizes of the components (e.g. size of MXU, buffers, etc.) can be configured seperately.

## Instructions
The control units allow the system to execute 10 Byte wide instructions (more info at doc/TPU_ISA.md). Instructions can be transmitted over AXI and are stored in a small fifo-buffer.

## Measurements
A sample model, trained with the MNIST dataset, was evaluated on different sized MXUs at 177.77 MHz with a theorethical perfomance of up to 72.18 GOPS. Real timing measurements were then compared with traditional processors:

#### Tensor Processing Unit at 177.77 MHz

|Matrix Width N|6|8|10|12|14|
|:-:|:-:|:-:|:-:|:-:|:-:|
|Instruction Count|431|326|261|216|186|
|Duration in us (N input vectors)|383|289|234|194|165|
|Duration per input vector in us|63|36|23|16|11|

|Processor|Intel Core i5-5287U at 2.9 GHz|BCM2837 4x ARM Cortex-A53 at 1.2 GHz|
|:-:|:-:|:-:|
|Duration per input vector in us|62|763|

## Getting Started
To get started with tinyTPU, please have a look at getting_started.pdf, where detailed instructions for Xilinx Zynq SoCs and Vivado can be found.

## More Information
This project was developed during a bachelor thesis in technical computer science at the HAW Hamburg. If you want to know more about the co-processor, you can have a look at the thesis [here](https://drive.google.com/file/d/1ruGQ9-zKKLDuujQX47IoflLwsDpLhAaQ/view?usp=sharing) (german).
# TPU-ISA
This is a short explenation of the ISA used by tinyTPU.
## Instruction Set Architecture
The ISA consists of 6 instructions:
1. nop - No Operation, does basically nothing
2. halt - used to stop the TPU and preparing for shutdown
3. read_weights - loads weights from the weight buffer into the matrix multiply unit
4. matrix_multiply - execute a matrix multiply
5. activate - run the result through an activation function
6. synchronize - "marker" instruction which fires an interrupt for memory synchronisation

There are no instructions for memory reads/writes between the host and the TPU.
The TPU is completely memory mapped and therefore, the TPU's memory can be accessed directly from the host.
However, the synchronize instruction is used to inform the host when some other instructions are finished and is therefore considered a "marker".
It's mainly used for exchanging data between the host and the TPU.
## Instruction Structure
The structure of the instructions may vary, but is tried to stay consistent when possible.
Some instructions need addresses and address fields may be shared in the structure.  
Instruction structures are shown below:

### Standard Instruction Type
|Buffer Address|Accumulator Address|Length|OP-Code|
|:------------:|:-----------------:|:----:|:-----:|
|    24 Bit    |       16 Bit      |32 Bit| 8 Bit |

### Weight Instruction Type
|Weight Address|Length|OP-Code|
|:------------:|:----:|:-----:|
|    40 Bit    |32 Bit| 8 Bit |

## List of OP-Codes

The OP-Code field constists of 8 Bit and is segmented in 4 sections:

|Function|Activation|Arithmetic|Weights|Control|
|:-------|:--------:|:--------:|:-----:|:-----:|
|Position|   [7:0]  |   [5:0]  | [3:0] | [1:0] |

Functions are prioritized: The function with the higher bit index is inferred.  
A Function field is inferred, when the MSB of the function is set to 1.
A Function field can use bits of a lower prioritized function field.  
However, there are a few exceptions:  
The synchronize operation is inferred when all bits are set to 1.  
The nop operation is inferred when all bits are set to 0.

With that in mind, functions can have sub-functions. For example, a pass-through activation is encoded in [10000000], then a sigmoid activation can be encoded by using bits of lower prioritized functions (like [10000001]).

Below is a brief list of OP-Codes and their respective instruction field usage.

| OP-Code|       Function|  Buffer Address|Accumulator Address|    Length|
|-------:|--------------:|---------------:|------------------:|---------:|
|00000000|            nop|      don't care|         don't care|don't care|
|00000010|           halt|      don't care|         don't care|don't care|
|00001000|   read_weights|uses all 40 Bits|   uses all 40 Bits|      used|
|00100000|matrix_multiply|            used|               used|      used|
|10000000|       activate|            used|               used|      used|
|11111111|    synchronize|      don't care|         don't care|don't care|
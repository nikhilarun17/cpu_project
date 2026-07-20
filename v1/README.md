# CPU Project - V1

This is an hobby project of mine to try implementing a mini cpu on an fpga (Sipeed Tang Nano 20k) using Verilog and python (for compiler and assembler).

## V1 functionality:
- Can program printing any integer or string and can print it on a laptop terminal using UART Protocol
- Can read arithmetic calculations (simple 2 number multiplication with results capped at 32767) sent on the port and output results immediately (intentional design) on the same port using UART.
- Can do both simulataneosly implementing a priority instruction format giving priority to whatever is sent from the terminal.
- Programming is done on a custom very readable language which is converted to assembly which is later converted to binary.

## Structure:

### Modules Used:
- [ALU](ALU.v) :- Used to refer to arithmetic logics whihc instructions act based on.
- [Control Unit](CONTROL_UNIT.v) :- Main block where instructions are processed and acted upon.
- [Register](REG.v) :- A temporary scratch space where work is done before it is wiped out for the next usage.
- [Decoder](DECODER.v) :- An module which is used to decode instructions and toggle writing and reading functions in memory and register so that the ALU and Control Unit can act upon it accordingly.
- [UART-TX](UART_TX.v) and [UART-RX](UART_RX.v) :- Used for communication between the terminal and the fpga.
- [Memory](MEMORY.v) :- Used for storage of instructions as of now and used as bait for storing things to print.

### Additional Helpers Used:
- [Arithmetic Calculator](bodmos.v) :- A helper module which writes imm_pc instructions and injects them into the control unit (halting the current program) and running the immediate program first.
- [ITOA](itoa.v) :- Used to handle the integer to ASCII conversion for processing, storing and printing (Uses Double Dabble algorithm).
- [Button debounce](button_debounce.v) :- Another helper to handle the button debounce of the reset button.

All modules are integrated and called in [CPU_TOP](CPU_TOP.v) (A unit which acts as the top layer and contains the control unit along with the rx and tx communications between different devices).

### Python Helpers Used:
- [Assembler](assembler.py) :- Takes in Assembly code from a txt file and converts it into binary instructions correctly which is directly stored in a temporary file called program_init.v which is directly accessed by Memory.

## All features implemented:
- 16 unit register with 16 bits per unit. 256 Unit memory with 16 bits every unit.
- 16 bit wide instructions containing the format [OP_code][RA_Address][RB_Address][RD_Address] 
- UART_TX with 8 bit transfer at a time (in one call) accessing a 32 unit tx storage buffer.
- UART_RX with syncing which stores in another rx buffer for further use with the help of [arithmetic calculator](bodmos.v)
- Tagged storage to store and differentiate integers and ASCII characters.
- ALU with 14 calculation possibilities and Decoder with 16 values (load,jmp,jz,add,subtract,etc) to decode from the memory instructions.
- Button debounce to sort out any issues with multiple button registers in one press
- ITOA for managing integer to ASCII when printing, storing and processing.
- Control unit which can work with priority halting with imm_instructions are loaded.

## To be improved:
- Adding improved TX which can process larger than 8 bits and send them together as one.
- Better values for Register units, memory units, unit size and instruction list (Just expansion to add more space to work with)
- Better handling of integers and differentiating when storing.
- A custom compiler which compiles into assembly for easier usage.
- Better RX handling and more efficient usage of LUT's.
- Adding more features like image processing and faster communication than UART if possible.
- Add concept of negative numbers


## Images:

![alt text](images/image.png)

![alt text](images/image-1.png)

## How to use:
- Install the software for your fpga board (gowin ide for tang-nano 20k).
- Upload all the verilog files into the software and synthesize it and route it after assigning the correct rx and tx pins for UART and clock.
- Write your custom Assembly code in the file [input.txt](input.txt) and run the python file [assembler.py](assembler.py)
- Upload to the fpga and open the port in the terminal (use minicom or picocom or anything else and set the baud rate accorindingly (default is 115200, can be changed in code.)) and echo any arithmetic into the the port to get the result immediately.

```
# Found this to be the best and most user-friendly way
stty -F /dev/ttyUSB1 115200 raw -echo
cat /dev/ttyUSB1
```
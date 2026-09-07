# SimpleRISC CPU

This repository contains the RTL code for a SimpleRISC CPU architecture.

The CPU is pipelined into 5 stages:

1. **Instruction Fetch (IF)**
2. **Operand Fetch (OF)**
3. **Execute (EX)**
4. **Memory Access (MA)**
5. **Register Write (RW)**

These stages will be later referred to as:

**IF → OF → EX → MA → RW**

This architecture takes care of various hazards like:

* **Data Hazards**
* **Control Hazards**
* **Load-Use Hazard**

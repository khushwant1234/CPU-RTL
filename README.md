# SimpleRISC CPU

RTL (SystemVerilog) for a 5-stage pipelined SimpleRisc processor, with unit
tests for every module and an integration test that runs real programs on the
full CPU.

**IF → OF → EX → MA → RW**

Hazards handled:

* **Data hazards**: forwarding from EX/MEM and MEM/WB into EX
* **Load-use hazard**: 1-cycle stall + bubble
* **Control hazards**: branches resolved in EX, the 2 wrong-path instructions are flushed

## Work split

| Part | Who | Files |
|---|---|---|
| Fetch + decode (IF, OF) | Magirman | `rtl/magirman/` pc_reg, instr_mem, if_id_reg, decoder, reg_file, id_ex_reg |
| Execute, memory, write-back (EX, MA, RW) | Khushwant | `rtl/khushwant/` alu, flags, branch_unit, execute_stage, ex_mem_reg, memory_unit, mem_wb_reg, writeback |
| Shared | both | `rtl/common/simpleriscprocessor_pkg.sv`, `rtl/shared/` forwarding_unit, hazard_unit, data_mem, simplerisc_cpu (top) |

Tests follow the same layout under `tb/magirman`, `tb/khushwant` and `tb/shared`.

## Layout

```
rtl/common/     simpleriscprocessor_pkg.sv   opcodes, ctrl_t, alu_op_e, fwd_sel_e, CTRL_BUBBLE
rtl/magirman/   IF + OF stage modules
rtl/khushwant/  EX + MA + RW stage modules
rtl/shared/     forwarding_unit, hazard_unit, data_mem, simplerisc_cpu (top level)
tb/common/      tb_check.svh (CHECK_EQ macros), tb_encode.svh (instruction encoders)
tb/*/           one self-checking testbench per module, tb_cpu = full CPU
programs/       SimpleRisc assembly test programs (+ assembled .hex)
tools/sr_asm.py small assembler, .s -> .hex for $readmemh
run_tests.sh    builds + runs every testbench with Icarus Verilog
```

## Running the tests

Needs Icarus Verilog 12+ (`brew install icarus-verilog`) and python3.

```bash
./run_tests.sh              # everything
./run_tests.sh magirman     # only Magirman's unit tests
./run_tests.sh tb_cpu -v    # one testbench with full output
```

Current result: **18 testbenches, all pass (~11.8k checks)**.

Waveform of the full CPU run (open with GTKWave):

```bash
vvp build/tb_cpu.vvp +vcd   # writes build/tb_cpu.vcd
```

Assembling a program by hand:

```bash
python3 tools/sr_asm.py programs/bubble_sort.s -l
```

## Instruction encoding

```
[31:27] opcode  [26] I  [25:22] rd  [21:18] rs1  [17:14] rs2          (I = 0)
[31:27] opcode  [26] I  [25:22] rd  [21:18] rs1  [17:16] mod [15:0] imm  (I = 1)
[31:27] opcode  [26:0] offset                                          (branches)
```

* `mod`: `00` sign-extend, `01` (`u`) zero-extend, `10` (`h`) load into upper 16 bits
* Branch target = `pc + (sign_ext(offset) << 2)`, so offset counts instructions
* 16 registers, `r14 = sp`, `r15 = ra`, r0 is a normal register

Opcodes are in `simpleriscprocessor_pkg.sv`: add, sub, mul, div, mod, cmp, and, or,
not, mov, lsl, lsr, asr, nop, ld, st, beq, bgt, b, call, ret.

The decoder normalizes the odd cases so the hazard logic never needs opcode specific checks:

* `st rd, imm[rs1]`: the stored register comes out on `rs2`, with no reg write
* `ret`: reads `r15` on `rs1`
* `call`: writes `r15` (value `pc + 4` chosen in write-back)

## Hazard handling

| Situation | Handled by | Cost |
|---|---|---|
| Result needed by the next instruction | forwarding_unit, EX/MEM → EX | 0 cycles |
| Result needed 2 instructions later | forwarding_unit, MEM/WB → EX | 0 cycles |
| Result needed 3 instructions later | reg_file write-first bypass | 0 cycles |
| `ld` followed by a use of the loaded reg | hazard_unit: stall PC + IF/ID, bubble ID/EX | 1 cycle |
| Taken branch / call / ret | hazard_unit: flush IF/ID + ID/EX, PC ← target | 2 cycles |
| `cmp` directly followed by `beq`/`bgt` | flags written at the end of cmp's EX cycle | 0 cycles |

## Integration test programs

| Program | What it checks | Stalls | Flushes |
|---|---|---|---|
| arith.s | every ALU op, immediates, `u`/`h` modifiers | 0 | 0 |
| forwarding.s | dependency chains at distance 1/2/3, store data forwarding | 0 | 0 |
| load_use.s | ld → use, ld → st, ld → base address, ld → cmp | 4 | 1 |
| branches.s | beq/bgt taken and not taken, signed compare, flushed wrong path, loop | 0 | 13 |
| call_ret.s | call/ret, stack, recursive factorial, `ld ra` → `ret` | 1 | 19 |
| bubble_sort.s | sorts 8 signed words in memory, then sums them | 36 | 72 |

The stall and flush counts are checked exactly by `tb_cpu`, along with every
register and memory result.

## Changes made to the fetch/decode files during integration

* `decoder.sv`: sets the new `ctrl.branch_gt` bit so EX knows beq from bgt; the
  not/mov ternary became an if/else (Icarus needs a cast otherwise)
* `id_ex_reg.sv`: reset/flush load the `CTRL_BUBBLE` constant (the old
  always_comb bubble was X at time 0); flush moved out of the async reset branch
* `simpleriscprocessor_pkg.sv`: added `branch_gt`, `fwd_sel_e` and `CTRL_BUBBLE`

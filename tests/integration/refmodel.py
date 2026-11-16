MASK = 0xFFFFFFFF
NOP = 0x68000000
DMEM_WORDS = 1024

OPS = ["add", "sub", "mul", "div", "mod", "cmp", "and", "or", "not", "mov", "lsl", "lsr",
       "asr", "nop", "ld", "st", "beq", "bgt", "b", "call", "ret"]
ALU_OPS = {"add", "sub", "mul", "div", "mod", "and", "or", "lsl", "lsr", "asr"}


def signed(v):
    return v - (1 << 32) if v & 0x80000000 else v


def extend_imm(imm16, mod):
    if mod == 0:
        return (imm16 - 0x10000 if imm16 & 0x8000 else imm16) & MASK
    if mod == 1:
        return imm16
    if mod == 2:
        return imm16 << 16
    return 0


def alu(op, a, b):
    sa, sb = signed(a), signed(b)
    if op == "add":
        return (a + b) & MASK
    if op == "sub":
        return (a - b) & MASK
    if op == "mul":
        return (a * b) & MASK
    if op in ("div", "mod"):
        if b == 0:
            return 0
        q = abs(sa) // abs(sb)
        if (sa < 0) != (sb < 0):
            q = -q
        return (q if op == "div" else sa - sb * q) & MASK
    if op == "and":
        return a & b
    if op == "or":
        return a | b
    if op == "lsl":
        return (a << (b & 31)) & MASK
    if op == "lsr":
        return a >> (b & 31)
    if op == "asr":
        return (sa >> (b & 31)) & MASK
    raise ValueError(op)


def decode(word):
    op = word >> 27
    d = {
        "op": OPS[op] if op < len(OPS) else "bad",
        "imm_form": (word >> 26) & 1,
        "rd": (word >> 22) & 0xF,
        "rs1": (word >> 18) & 0xF,
        "rs2": (word >> 14) & 0xF,
        "imm": extend_imm(word & 0xFFFF, (word >> 16) & 3),
        "offset": (word & 0x7FFFFFF) - (1 << 27) if word & 0x4000000 else word & 0x7FFFFFF,
    }
    return d


def reads(d):
    op = d["op"]
    if op in ALU_OPS or op == "cmp":
        return {d["rs1"]} if d["imm_form"] else {d["rs1"], d["rs2"]}
    if op in ("not", "mov"):
        return set() if d["imm_form"] else {d["rs2"]}
    if op == "ld":
        return {d["rs1"]}
    if op == "st":
        return {d["rs1"], d["rd"]}
    if op == "ret":
        return {15}
    return set()


def run(words, max_steps=200000):
    r = [0] * 16
    mem = {}
    flag_e = flag_gt = False
    pc = 0
    steps = stalls = flushes = 0
    last_load = None
    trace = []

    while steps < max_steps:
        i = pc >> 2
        word = words[i] if i < len(words) else NOP
        d = decode(word)
        op = d["op"]
        target = (pc + d["offset"] * 4) & MASK
        nxt = pc + 4

        if op == "b" and target == pc:
            return {"halted": True, "regs": r, "mem": {a: v for a, v in mem.items() if v},
                    "steps": steps, "stalls": stalls, "flushes": flushes, "trace": trace, "halt_pc": pc}

        if last_load is not None and last_load in reads(d):
            stalls += 1
            trace.append(("stall", pc))
        last_load = d["rd"] if op == "ld" else None

        op2 = d["imm"] if d["imm_form"] else r[d["rs2"]]
        taken = False

        if op in ALU_OPS:
            result = alu(op, r[d["rs1"]], op2)
            trace.append(("W", pc, d["rd"], result))
            r[d["rd"]] = result
        elif op == "cmp":
            flag_e = r[d["rs1"]] == op2
            flag_gt = signed(r[d["rs1"]]) > signed(op2)
        elif op in ("not", "mov"):
            result = (~op2 & MASK) if op == "not" else op2
            trace.append(("W", pc, d["rd"], result))
            r[d["rd"]] = result
        elif op == "ld":
            addr = (r[d["rs1"]] + d["imm"]) & MASK
            result = mem.get(addr >> 2, 0) if (addr >> 2) < DMEM_WORDS else 0
            trace.append(("W", pc, d["rd"], result))
            r[d["rd"]] = result
        elif op == "st":
            addr = (r[d["rs1"]] + d["imm"]) & MASK
            trace.append(("S", pc, addr, r[d["rd"]]))
            if (addr >> 2) < DMEM_WORDS:
                mem[addr >> 2] = r[d["rd"]]
        elif op in ("beq", "bgt"):
            taken = flag_e if op == "beq" else flag_gt
        elif op == "b":
            taken = True
        elif op == "call":
            trace.append(("W", pc, 15, (pc + 4) & MASK))
            r[15] = (pc + 4) & MASK
            taken = True
        elif op == "ret":
            target = r[15]
            taken = True

        if taken:
            flushes += 1
            trace.append(("flush", pc, target))
            nxt = target
        pc = nxt
        steps += 1

    return {"halted": False, "regs": r, "mem": {a: v for a, v in mem.items() if v},
            "steps": steps, "stalls": stalls, "flushes": flushes, "trace": trace, "halt_pc": None}

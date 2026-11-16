import random

from refmodel import MASK, alu, signed

ALU = ["add", "sub", "mul", "div", "mod", "and", "or", "lsl", "lsr", "asr"]
OPNUM = {"add": 0, "sub": 1, "mul": 2, "div": 3, "mod": 4, "cmp": 5, "and": 6, "or": 7,
         "not": 8, "mov": 9, "lsl": 10, "lsr": 11, "asr": 12}


def h(v):
    return f"0x{v & MASK:08x}"


def show(v):
    s = signed(v & MASK)
    if 0 <= s <= 9999:
        return str(s)
    if -9999 <= s < 0:
        return f"{s} ({h(v)})"
    return h(v)


def imm_value(imm16, mod):
    if mod == 0:
        return (imm16 - 0x10000 if imm16 & 0x8000 else imm16) & MASK
    return [None, imm16, imm16 << 16, 0][mod]


def imm_text(imm16, mod):
    if mod == 0:
        return str(imm16 - 0x10000 if imm16 & 0x8000 else imm16)
    return f"0x{imm16:x}"


def imm_words(imm16, mod):
    v = imm_value(imm16, mod)
    if mod == 0:
        if imm16 & 0x8000:
            return f"{imm_text(imm16, 0)} (sign-extended to {h(v)})"
        return imm_text(imm16, 0)
    if mod == 1:
        return f"0x{imm16:x} with the u modifier, so it's zero-extended to {h(v)}"
    return f"0x{imm16:x} with the h modifier, so it goes in the top half: {h(v)}"


SUFFIX = {0: "", 1: "u", 2: "h"}


def enc_i(op, rd, rs1, mod, imm16):
    return (OPNUM[op] << 27) | (1 << 26) | (rd << 22) | (rs1 << 18) | (mod << 16) | imm16


class Prog:
    def __init__(self):
        self.lines = []

    def op(self, text):
        self.lines.append("        " + text)

    def label(self, name):
        self.lines.append(f"{name}:")

    def const(self, reg, v):
        v &= MASK
        s = signed(v)
        if -32768 <= s <= 32767:
            self.op(f"mov  {reg}, {s}")
        elif v <= 0xFFFF:
            self.op(f"movu {reg}, 0x{v:x}")
        else:
            self.op(f"movh {reg}, 0x{v >> 16:x}")
            if v & 0xFFFF:
                self.op(f"oru  {reg}, {reg}, 0x{v & 0xFFFF:x}")

    def nops(self, n):
        for _ in range(n):
            self.op("nop")

    def fillers(self, n, reg="r11"):
        for i in range(n):
            self.op(f"add  {reg}, {reg}, 1" if i % 2 == 0 else "nop")

    def source(self):
        return "\n".join(self.lines + ["halt:   b    halt"]) + "\n"


def make(group, name, what, prog, focus=()):
    return {"group": group, "name": f"{group}/{name}", "what": what,
            "source": prog.source(), "focus": list(focus)}


def alu_note(op, a, b, res):
    sa, sb, sr = signed(a), signed(b), signed(res)
    if op == "add":
        if (sa >= 0) == (sb >= 0) and (sr >= 0) != (sa >= 0):
            return " this overflows the signed range. the cpu just wraps around, nothing traps."
        if a + b > MASK:
            return " the unsigned sum doesn't fit in 32 bits so the carry out is just dropped."
    if op == "sub":
        if (sa >= 0) != (sb >= 0) and (sr >= 0) != (sa >= 0):
            return " this overflows the signed range, so it wraps around."
        if sa < sb:
            return " the left side is smaller so the answer is negative."
    if op == "mul" and a * b > MASK:
        return " the real product needs more than 32 bits, only the low 32 bits are kept."
    if op in ("div", "mod"):
        if b == 0:
            return " dividing by zero. simplerisc has no trap for this, our alu just gives 0."
        if sa == -2**31 and sb == -1:
            if op == "div":
                return " this is the one division that overflows (the answer would be +2^31), so it comes out as 0x80000000."
            return " this is the overflow case for division, the remainder is still 0."
        if (sa < 0) != (sb < 0) or sa < 0:
            if op == "div":
                return " there's a negative in it, so the answer rounds toward zero like in c."
            return " there's a negative in it. the remainder takes the sign of the left number."
    if op in ("lsl", "lsr", "asr"):
        if b & 31 != b:
            return f" the shift amount is {show(b)} but only the low 5 bits count, so it really shifts by {b & 31}."
        if b == 0:
            return " shifting by 0 should change nothing."
        if op == "asr" and sa < 0:
            return " asr copies the sign bit in from the left, so it stays negative."
        if op == "lsr" and sa < 0:
            return " lsr fills with zeros from the left, so the result turns positive."
        if op == "lsl" and (a << b) > MASK:
            return " bits shifted out of the top are lost."
    return ""


COMMON = [(5, 3), (3, 5), (0, 0), (0xFFFFFFFF, 1), (0x7FFFFFFF, 1), (0x80000000, 0xFFFFFFFF),
          (0x80000000, 0x80000000), (0xFFFFFFFF, 0xFFFFFFFF), (0x12345678, 0x9ABCDEF0)]
DIVS = [(100, 7), (0xFFFFFF9C, 7), (100, 0xFFFFFFF9), (0xFFFFFF9C, 0xFFFFFFF9), (7, 0), (0, 5),
        (1, 2), (0xFFFFFFFF, 2), (0x80000000, 2)]
EXTRA = {
    "add": [(0x7FFFFFFF, 0x7FFFFFFF), (1, 0xFFFFFFFE), (0xFFFF, 1), (100, 0xFFFFFF9C)],
    "sub": [(0, 1), (0x80000000, 1), (5, 5), (1, 0xFFFFFFFF), (0x7FFFFFFF, 0xFFFFFFFF)],
    "mul": [(0x10000, 0x10000), (0xFFFFFFFD, 7), (0x7FFFFFFF, 2), (0xFFFF, 0xFFFF), (1234, 5678)],
    "div": DIVS,
    "mod": DIVS,
    "and": [(0xF0F0F0F0, 0x0FF00FF0), (0xFFFFFFFF, 0x12345678), (0, 0xFFFFFFFF), (0xAAAAAAAA, 0x55555555)],
    "or": [(0xF0000000, 0xF), (0xAAAAAAAA, 0x55555555), (0x12340000, 0x5678), (0x80000000, 1)],
    "lsl": [(1, 0), (1, 1), (1, 31), (1, 32), (1, 33), (3, 4), (0x80000000, 1), (0xFFFFFFFF, 16), (0x12345678, 63)],
    "lsr": [(0x80000000, 31), (0x80000000, 1), (0xFFFFFFFF, 4), (1, 1), (0x12345678, 32), (0x12345678, 8),
            (5, 0), (0xFFFFFFFF, 0xFFFFFFFF)],
    "asr": [(0x80000000, 4), (0x80000000, 31), (0xFFFFFFFF, 31), (0x40000000, 4), (0x12345678, 33),
            (0xF0000000, 28), (5, 0), (0xFFFFFFF0, 2)],
}
IMMS = {
    "shift": [(0x80000001, 0, 0), (0x80000001, 1, 0), (0x80000001, 31, 0), (0x80000001, 32, 0), (0x80000001, 4, 0)],
    "div": [(100, 7, 0), (100, 0xFFF9, 0), (0xFFFFFF9C, 7, 0), (5, 0, 0), (0x30000, 1, 2)],
    "other": [(7, 0xFFFF, 0), (0x7FFFFFFF, 0x7FFF, 0), (0, 0x8000, 0), (1, 0xFFFF, 1), (0x1234, 0x8000, 2)],
}


def alu_tests():
    tests = []
    for op in ALU:
        pairs = []
        for p in EXTRA[op] + COMMON:
            if p not in pairs:
                pairs.append(p)
        for i, (a, b) in enumerate(pairs[:14]):
            res = alu(op, a, b)
            p = Prog()
            p.const("r1", a)
            p.const("r2", b)
            p.nops(3)
            p.op(f"{op:<4} r3, r1, r2")
            what = (f"{op} with two registers. r1 = {show(a)} and r2 = {show(b)}, so r3 should be "
                    f"{show(res)}.{alu_note(op, a, b, res)}")
            tests.append(make("alu", f"{op}_reg_{i:02d}", what, p, ["r3"]))

        kind = "shift" if op in ("lsl", "lsr", "asr") else "div" if op in ("div", "mod") else "other"
        for i, (a, imm16, mod) in enumerate(IMMS[kind]):
            b = imm_value(imm16, mod)
            res = alu(op, a, b)
            p = Prog()
            p.const("r1", a)
            p.nops(3)
            p.op(f"{op + SUFFIX[mod]:<4} r3, r1, {imm_text(imm16, mod)}")
            what = (f"{op} with an immediate. r1 = {show(a)} and the immediate is {imm_words(imm16, mod)}, "
                    f"so r3 should be {show(res)}.{alu_note(op, a, b, res)}")
            tests.append(make("alu", f"{op}_imm_{i:02d}", what, p, ["r3"]))

    for v in [0, 0xFFFFFFFF, 0x12345678, 0x80000000, 0x55555555]:
        for op in ("not", "mov"):
            res = (~v & MASK) if op == "not" else v
            p = Prog()
            p.const("r1", v)
            p.nops(3)
            p.op(f"{op:<4} r3, r1")
            what = (f"{op} with a register. r1 = {show(v)}, so r3 should be {show(res)}. "
                    f"{op} only uses its second operand, there's no rs1.")
            tests.append(make("alu", f"{op}_reg_{v:08x}", what, p, ["r3"]))
    for op, imm16, mod in [("mov", 0x7FFF, 0), ("mov", 0x8000, 0), ("mov", 0xFFFF, 1), ("mov", 0xABCD, 2),
                           ("not", 0, 0), ("not", 0xFFFF, 1), ("not", 0x00FF, 2), ("not", 0x8000, 0)]:
        v = imm_value(imm16, mod)
        res = (~v & MASK) if op == "not" else v
        p = Prog()
        p.op(f"{op + SUFFIX[mod]:<4} r3, {imm_text(imm16, mod)}")
        what = f"{op} with an immediate. the immediate is {imm_words(imm16, mod)}, so r3 should be {show(res)}."
        tests.append(make("alu", f"{op}_imm_{imm16:04x}_{mod}", what, p, ["r3"]))
    return tests


def immediate_tests():
    tests = []
    for i, (imm16, mod) in enumerate([(0, 0), (1, 0), (0x7FFF, 0), (0x8000, 0), (0xFFFF, 0), (0x1234, 0),
                                      (0x8000, 1), (0xFFFF, 1), (0, 1), (0x8000, 2), (0xFFFF, 2), (1, 2)]):
        v = imm_value(imm16, mod)
        p = Prog()
        p.op(f"mov{SUFFIX[mod]:<1} r1, {imm_text(imm16, mod)}")
        what = f"mov an immediate into r1. the immediate is {imm_words(imm16, mod)}, so r1 should be {show(v)}."
        tests.append(make("immediate", f"mov_{i:02d}", what, p, ["r1"]))

    for v in [0xDEADBEEF, 0x80000000, 0x7FFFFFFF, 0xFFFF0001, 0x00010000, 0x12345678]:
        p = Prog()
        p.op(f"movh r1, 0x{v >> 16:x}")
        p.op(f"oru  r1, r1, 0x{v & 0xFFFF:x}")
        what = (f"build a full 32-bit constant the normal way: movh puts 0x{v >> 16:04x} in the top half, then oru "
                f"(zero-extended) fills in the bottom half with 0x{v & 0xFFFF:04x}. r1 should be {h(v)}.")
        tests.append(make("immediate", f"build_{v:08x}", what, p, ["r1"]))

    cases = [
        ("addu", 1, 0xFFFF, 1, "add"), ("addh", 5, 1, 2, "add"), ("subh", 0, 1, 2, "sub"),
        ("andu", 0xDEADBEEF, 0xFFFF, 1, "and"), ("andh", 0xDEADBEEF, 0xFFFF, 2, "and"),
        ("orh", 1, 0x8000, 2, "or"), ("lsl", 3, 0x7FFF, 0, "lsl"),
    ]
    for mnem, a, imm16, mod, op in cases:
        b = imm_value(imm16, mod)
        res = alu(op, a, b)
        p = Prog()
        p.const("r1", a)
        p.op(f"{mnem:<4} r2, r1, {imm_text(imm16, mod)}")
        what = (f"{mnem}: r1 = {show(a)} and the immediate is {imm_words(imm16, mod)}, so r2 should be "
                f"{show(res)}.{alu_note(op, a, b, res)}")
        tests.append(make("immediate", f"{mnem}_{a:x}", what, p, ["r2"]))

    for mnem, a, imm16, mod in [("cmpu", 0xFFFF, 0xFFFF, 1), ("cmp", 0xFFFFFFFF, 0xFFFF, 0),
                                ("cmpu", 0xFFFFFFFF, 0xFFFF, 1)]:
        b = imm_value(imm16, mod)
        p = Prog()
        p.const("r1", a)
        p.op(f"{mnem:<4} r1, {imm_text(imm16, mod)}")
        p.op("beq  equal")
        p.op("mov  r5, 1")
        p.label("equal")
        p.op("mov  r6, 2")
        same = a == b
        what = (f"{mnem} r1 against an immediate. r1 = {show(a)} and the immediate is {imm_words(imm16, mod)}. "
                + ("they're equal, so beq is taken and r5 stays 0." if same else
                   "they're not equal (the modifier changes the value), so beq is not taken and r5 becomes 1."))
        tests.append(make("immediate", f"{mnem}_{a:x}_{mod}", what, p, ["r5"]))

    p = Prog()
    p.op(f".word 0x{enc_i('mov', 1, 0, 3, 0x1234):08x}   @ mov r1, 0x1234 but with the reserved modifier 11")
    what = ("mov with the reserved modifier 11 (the assembler can't write this, so it's a raw .word). "
            "our decoder gives 0 for this modifier, so r1 should be 0, not 0x1234.")
    tests.append(make("immediate", "reserved_mod_mov", what, p, ["r1"]))
    p = Prog()
    p.op("mov  r1, 7")
    p.nops(2)
    p.op(f".word 0x{enc_i('add', 2, 1, 3, 0x0FFF):08x}   @ add r2, r1, 0xfff but with the reserved modifier 11")
    what = ("add with the reserved modifier 11. the immediate turns into 0, so r2 should just be r1 = 7.")
    tests.append(make("immediate", "reserved_mod_add", what, p, ["r2"]))
    return tests


def registers_tests():
    tests = []
    notes = {0: " r0 is a normal register in simplerisc, unlike mips or risc-v where it's always 0.",
             14: " r14 is sp by convention, but the hardware treats it like any other register.",
             15: " r15 is only special because call and ret use it, otherwise it's normal."}
    for r in range(16):
        v = 0x10000001 * (r + 1) & MASK
        dst = (r + 5) % 16
        p = Prog()
        p.const(f"r{r}", v)
        p.nops(3)
        p.op(f"add  r{dst}, r{r}, 0")
        what = f"write {h(v)} into r{r} and copy it to r{dst}. both should end up as {h(v)}.{notes.get(r, '')}"
        tests.append(make("registers", f"r{r:02d}", what, p, [f"r{r}", f"r{dst}"]))

    p = Prog()
    for r in range(16):
        p.const(f"r{r}", 0x01010101 * r + 0x100 * r)
    what = "fill all 16 registers with different values at once. if two registers were mixed up somewhere, one of them shows the wrong value."
    tests.append(make("registers", "all_sixteen", what, p, [f"r{r}" for r in range(16)]))

    p = Prog()
    p.op("mov  r0, 5")
    p.op("add  r1, r0, r0")
    p.op("sub  r0, r1, 3")
    what = "use r0 as a real register: r0 = 5, then r1 = r0 + r0 = 10, then r0 = r1 - 3 = 7. if r0 was stuck at 0 like in mips, these would be wrong."
    tests.append(make("registers", "r0_is_normal", what, p, ["r0", "r1"]))
    p = Prog()
    p.op("mov  r10, 0x200")
    p.op("mov  r1, 99")
    p.op("st   r1, 0[r10]")
    p.op("ld   r0, 0[r10]")
    p.nops(2)
    p.op("add  r2, r0, 1")
    what = "load into r0. r0 should become 99 and r2 = r0 + 1 = 100."
    tests.append(make("registers", "load_into_r0", what, p, ["r0", "r2"]))

    for op in ("add", "mul", "sub"):
        p = Prog()
        p.op("mov  r1, 12")
        p.nops(3)
        p.op(f"{op:<4} r2, r1, r1")
        res = alu(op, 12, 12)
        what = f"{op} r2, r1, r1 reads the same register for both operands. r1 = 12, so r2 should be {res}."
        tests.append(make("registers", f"same_src_{op}", what, p, ["r2"]))

    for gap in (0, 2):
        p = Prog()
        p.op("mov  r1, 3")
        for _ in range(5):
            p.op("add  r1, r1, r1")
            p.nops(gap)
        what = (f"add r1, r1, r1 five times in a row (with {gap} nops between). r1 is both the source and the "
                f"destination, so it doubles every time: 3, 6, 12, 24, 48, 96. r1 should end up as 96.")
        tests.append(make("registers", f"self_update_gap{gap}", what, p, ["r1"]))

    for gap in (0, 1):
        p = Prog()
        for v in (1, 2, 3):
            p.op(f"mov  r1, {v}")
            p.nops(gap)
        p.op("add  r2, r1, 0")
        what = (f"write r1 three times (1, then 2, then 3, with {gap} nops between) and then read it. "
                "the newest write has to win, so r2 should be 3.")
        tests.append(make("registers", f"newest_wins_gap{gap}", what, p, ["r2"]))

    for r in (2, 7, 12, 15):
        p = Prog()
        p.const(f"r{r}", 0xABC00000 + r)
        p.nops(2)
        p.op(f"add  r1, r{r}, 1")
        what = (f"write r{r}, wait 2 nops, then read it. at this distance the write and the read happen in the same "
                f"cycle, so it only works because of the write-first bypass in reg_file. r1 should be {h(0xABC00000 + r + 1)}.")
        tests.append(make("registers", f"bypass_r{r:02d}", what, p, ["r1"]))

    p = Prog()
    for r in range(1, 16):
        p.op(f"mov  r{r}, {r * 3}")
    p.op("add  r0, r15, r14")
    for r in range(1, 15):
        p.op(f"add  r{r}, r{r}, r{r + 1}")
    what = ("write r1 to r15 one after another, then go back through them so each one adds the next. "
            "this mixes forwarding, the bypass and normal reads all over the register file.")
    tests.append(make("registers", "sweep", what, p, [f"r{r}" for r in range(15)]))
    return tests


def memory_tests(rng):
    tests = []
    cases = [(0x200, 0), (0x200, 4), (0x200, 0x40), (0x300, -4), (0x300, -0x100), (0, 0), (0, 0xFFC),
             (0xFFC, 0), (0x800, -0x800), (0x100, 0x7FC)]
    vals = [0x11111111, 0xDEADBEEF, 0xFFFFFFFF, 0x80000000, 1, 0x7FFFFFFF, 0x12345678, 0xCAFEF00D,
            0xFFFFFFFE, 0x55AA55AA]
    for i, ((base, off), v) in enumerate(zip(cases, vals)):
        addr = (base + off) & MASK
        p = Prog()
        p.const("r10", base)
        p.const("r1", v)
        p.nops(3)
        p.op(f"st   r1, {off}[r10]")
        p.nops(3)
        p.op(f"ld   r2, {off}[r10]")
        note = ""
        if addr == 0xFFC:
            note = " this is the last word of the 4 KB data memory."
        elif addr == 0:
            note = " this is address 0, the first word."
        elif off < 0:
            note = " the offset is negative, so it goes backwards from the base."
        what = (f"store {h(v)} at address {h(addr)} (base {h(base)} plus offset {off}) and load it back. "
                f"r2 should get {h(v)} and mem[{h(addr)}] should hold it.{note}")
        tests.append(make("memory", f"st_ld_{i:02d}_{addr:04x}", what, p, ["r2", f"mem[{h(addr)}]"]))

    for d in range(1, 5):
        p = Prog()
        p.op("mov  r10, 0x200")
        p.const("r1", 0x600DF00D)
        p.nops(3)
        p.op("st   r1, 0[r10]")
        p.nops(d - 1)
        p.op("ld   r2, 0[r10]")
        what = (f"store and then load the same address, {d} instruction{'s' if d > 1 else ''} apart. stores happen at "
                "the end of MA and loads read during MA, so even back to back the load should see the new value. "
                "r2 should be 0x600df00d.")
        tests.append(make("memory", f"st_then_ld_d{d}", what, p, ["r2"]))

    for gap in (0, 3):
        p = Prog()
        p.op("mov  r10, 0x200")
        p.op("mov  r1, 111")
        p.op("mov  r2, 222")
        p.nops(3)
        p.op("st   r1, 0[r10]")
        p.nops(gap)
        p.op("st   r2, 0[r10]")
        p.op("ld   r3, 0[r10]")
        what = f"store 111 and then 222 to the same address ({gap} nops between). the second store wins, so r3 should be 222."
        tests.append(make("memory", f"overwrite_gap{gap}", what, p, ["r3"]))

    for gap in (0, 3):
        p = Prog()
        p.op("mov  r10, 0x200")
        p.op("mov  r1, 0x0aaa")
        p.op("mov  r2, 0x0bbb")
        p.nops(3)
        p.op("st   r1, 0[r10]")
        p.op("st   r2, 4[r10]")
        p.nops(gap)
        p.op("ld   r3, 0[r10]")
        p.op("ld   r4, 4[r10]")
        what = "store to two neighbouring words (0x200 and 0x204). they must not overwrite each other: r3 should be 0xaaa and r4 should be 0xbbb."
        tests.append(make("memory", f"neighbours_gap{gap}", what, p, ["r3", "r4"]))

    for d in range(1, 4):
        p = Prog()
        p.op("mov  r10, 0x200")
        p.op("mov  r2, 1000")
        p.op("mov  r3, 234")
        p.nops(3)
        p.op("add  r1, r2, r3")
        p.fillers(d - 1)
        p.op("st   r1, 0[r10]")
        what = (f"add makes r1 = 1234 and the st stores it {d} instruction{'s' if d > 1 else ''} later. "
                "the data has to be forwarded into the store, so mem[0x200] should be 1234.")
        tests.append(make("memory", f"store_data_fwd_d{d}", what, p, ["mem[0x00000200]"]))
    for d in range(1, 4):
        p = Prog()
        p.op("mov  r11, 0x300")
        p.op("mov  r1, 77")
        p.nops(3)
        p.op("add  r10, r11, 8")
        p.fillers(d - 1)
        p.op("st   r1, 0[r10]")
        what = (f"add works out the address (0x300 + 8 = 0x308) and the st uses it {d} instruction{'s' if d > 1 else ''} "
                "later. the base register has to be forwarded, so 77 should land at mem[0x308].")
        tests.append(make("memory", f"store_base_fwd_d{d}", what, p, ["mem[0x00000308]"]))
    for d in range(1, 4):
        p = Prog()
        p.op("mov  r12, 0x308")
        p.op("mov  r1, 55")
        p.op("st   r1, 0[r12]")
        p.op("mov  r11, 0x300")
        p.nops(3)
        p.op("add  r10, r11, 8")
        p.fillers(d - 1)
        p.op("ld   r2, 0[r10]")
        what = (f"same idea for a load: the address 0x308 comes from the add {d} instruction{'s' if d > 1 else ''} before. "
                "r2 should get the 55 stored there.")
        tests.append(make("memory", f"load_base_fwd_d{d}", what, p, ["r2"]))

    for off in (1, 2, 3):
        p = Prog()
        p.op("mov  r10, 0x200")
        p.const("r1", 0x89ABCDEF)
        p.op("st   r1, 0[r10]")
        p.nops(2)
        p.op(f"ld   r2, {off}[r10]")
        what = (f"load from address 0x20{off}, which isn't word aligned. memory ignores the low 2 address bits, "
                "so this still reads the word at 0x200. r2 should be 0x89abcdef.")
        tests.append(make("memory", f"unaligned_ld_{off}", what, p, ["r2"]))
    p = Prog()
    p.op("mov  r10, 0x200")
    p.op("mov  r1, 321")
    p.nops(2)
    p.op("st   r1, 5[r10]")
    p.op("ld   r2, 4[r10]")
    what = "store to address 0x205. the low 2 bits are ignored, so it lands in the word at 0x204, and r2 (loaded from 0x204) should be 321."
    tests.append(make("memory", "unaligned_st", what, p, ["r2", "mem[0x00000204]"]))

    for base in (0x1000, 0x2000, 0xFFFFFFFC, 0x80000000):
        p = Prog()
        p.op("mov  r12, 0")
        p.const("r1", 0x5EED5EED)
        p.op("st   r1, 0[r12]")
        p.const("r10", base)
        p.op("mov  r2, 9")
        p.nops(2)
        p.op("ld   r2, 0[r10]")
        what = (f"load from {h(base)}, which is past the end of the 4 KB data memory. out of range loads give 0, "
                "so r2 should be 0. word 0 holds 0x5eed5eed, so if the address wrapped around we'd see that instead.")
        tests.append(make("memory", f"oob_ld_{base:08x}", what, p, ["r2"]))
    for base, word in ((0x1000, 0), (0x1004, 1), (0xFFFFFFF0, 0)):
        p = Prog()
        p.const("r12", word * 4)
        p.const("r1", 0x0000F00D)
        p.op("st   r1, 0[r12]")
        p.const("r10", base)
        p.const("r2", 0xBAD0BAD0)
        p.nops(2)
        p.op("st   r2, 0[r10]")
        p.op("ld   r3, 0[r12]")
        what = (f"store to {h(base)}, which is out of range. the store should just be dropped. it must not wrap "
                f"around and overwrite word {word} (address {h(word * 4)}), so r3 should still be 0xf00d.")
        tests.append(make("memory", f"oob_st_{base:08x}", what, p, ["r3"]))

    p = Prog()
    p.op("mov  r10, 0x200")
    p.op("mov  r1, 42")
    p.op("st   r1, 0[r10]")
    p.op("mov  r2, 0")
    p.op("st   r2, 0[r10]")
    p.op("ld   r3, 0[r10]")
    what = "store 42 and then store 0 over it. r3 should be 0 and that word should be back to 0."
    tests.append(make("memory", "store_zero", what, p, ["r3"]))
    for r in (0, 14, 15):
        p = Prog()
        p.op("mov  r10, 0x200")
        p.const("r1", 0x31415926)
        p.op("st   r1, 0[r10]")
        p.op(f"ld   r{r}, 0[r10]")
        what = f"load straight into r{r}. it should get 0x31415926 like any other register."
        tests.append(make("memory", f"ld_into_r{r}", what, p, [f"r{r}"]))

    for i in range(25):
        p = Prog()
        p.op("mov  r10, 0x200")
        n = rng.randint(8, 16)
        stores = loads = 0
        for _ in range(n):
            reg = f"r{rng.randint(1, 4)}"
            off = 4 * rng.randint(0, 31)
            if rng.random() < 0.6:
                p.const(reg, rng.getrandbits(32))
                p.op(f"st   {reg}, {off}[r10]")
                stores += 1
            else:
                p.op(f"ld   {reg}, {off}[r10]")
                loads += 1
        what = (f"random mix of {stores} stores and {loads} loads in the window 0x200 to 0x27c. some words get "
                "written more than once and some loads read words that were never written (those give 0).")
        tests.append(make("memory", f"random_{i:02d}", what, p, []))
    return tests


def address_operands(op, addr):
    return {"add": (addr - 0x30, 0x30), "sub": (addr + 0x44, 0x44), "mul": (addr // 4, 4),
            "and": (addr | 0xFFFF0000, 0xFFFF), "or": (addr & 0xF00, addr & 0xFF),
            "lsl": (addr >> 2, 2), "not": (~addr & MASK, 0), "mov": (addr, 0)}[op]


DIST = {
    1: "right in the next instruction, so it has to come from EX/MEM (distance 1).",
    2: "with one instruction in between, so it comes from MEM/WB (distance 2).",
    3: "with two instructions in between. now the write and the read happen in the same cycle, so this needs the write-first bypass in reg_file (distance 3).",
    4: "with three instructions in between. nothing special is needed here, it's a normal register read (distance 4, this is the control case).",
}


def forwarding_tests(rng):
    tests = []
    xregs = ["r5", "r7", "r0", "r12", "r4", "r8", "r14", "r13"]
    for pi, op in enumerate(["add", "sub", "mul", "and", "or", "lsl", "not", "mov"]):
        x = xregs[pi]
        for slot in ["rs1", "rs2", "both", "store data", "load base"]:
            for d in range(1, 5):
                p = Prog()
                if slot == "load base":
                    addr = 0x200 + 4 * rng.randint(0, 63)
                    a, b = address_operands(op, addr)
                    p.const("r3", 0x7E57DA7A)
                    p.const("r9", addr)
                    p.op("st   r3, 0[r9]")
                else:
                    a = rng.choice([0x12345678, 0xFFFFFFF0, 0x7FFFFFFF, 0x0000ABCD, rng.getrandbits(32)])
                    b = rng.randint(1, 31) if op == "lsl" else rng.choice([3, 0x00FF00FF, 0xFFFFFFFF, rng.getrandbits(32)])
                p.const("r1", a)
                p.const("r2", b)
                p.const("r3", 0x00000100)
                p.const(x, 0x0BADBAD0)
                if slot == "store data":
                    p.op("mov  r9, 0x300")
                p.nops(3)
                if op in ("not", "mov"):
                    p.op(f"{op:<4} {x}, r1")
                else:
                    p.op(f"{op:<4} {x}, r1, r2")
                p.fillers(d - 1)
                use = {"rs1": (f"add  r6, {x}, r3", f"add r6, {x}, r3 reads it as the first operand"),
                       "rs2": (f"sub  r6, r3, {x}", f"sub r6, r3, {x} reads it as the second operand"),
                       "both": (f"add  r6, {x}, {x}", f"add r6, {x}, {x} reads it as both operands"),
                       "store data": (f"st   {x}, 0[r9]", f"st {x}, 0[r9] stores it (st reads its data register through the rs2 path)"),
                       "load base": (f"ld   r6, 0[{x}]", f"ld r6, 0[{x}] uses it as the address")}[slot]
                p.op(use[0])
                what = f"{op} writes {x}, and then {use[1]} {DIST[d]}"
                focus = ["mem[0x00000300]"] if slot == "store data" else ["r6"]
                tests.append(make("forwarding", f"{op}_{slot.replace(' ', '_')}_d{d}", what, p, focus))

    prio = [
        ("mov  r5, 1|mov  r5, 2|add  r6, r5, 0", "r5 is written twice in a row (1 then 2) and read right after. both EX/MEM and MEM/WB have a value for r5, and the newer one (EX/MEM) has to win. r6 should be 2."),
        ("mov  r5, 1|mov  r5, 2|nop|add  r6, r5, 0", "same thing one step later: MEM/WB has the newer value and the register file is being written with the older one. r6 should be 2."),
        ("mov  r5, 1|nop|mov  r5, 2|add  r6, r5, 0", "older write at distance 3 and newer write at distance 1. r6 should be 2."),
        ("mov  r5, 1|mov  r5, 2|sub  r6, r5, r5", "same priority check, but the register is read through both operand paths. r6 should be 2 - 2 = 0."),
        ("mov  r5, 1|mov  r5, 2|mov  r5, 3|add  r6, r5, 0", "three writes to r5 in a row. the last one (3) has to win."),
        ("mov  r3, 7|mov  r5, 1|mov  r5, 2|sub  r6, r3, r5", "priority check on the second operand: r6 = 7 - 2 = 5."),
    ]
    for i, (code, what) in enumerate(prio):
        p = Prog()
        for line in code.split("|"):
            p.op(line)
        tests.append(make("forwarding", f"priority_{i}", what, p, ["r6"]))

    chains = [
        ("mov  r1, 3|add  r2, r1, 1|add  r3, r2, r2|mul  r4, r3, r3|sub  r5, r4, r1",
         "a chain where every instruction needs the one right before it: r1 = 3, r2 = 4, r3 = 8, r4 = 64, r5 = 61."),
        ("mov  r1, 2|lsl  r1, r1, 3|or   r1, r1, 1|mul  r1, r1, r1|sub  r1, r1, 1",
         "one register updated over and over: 2, 16, 17, 289, then 288."),
        ("mov  r10, 0x200|mov  r1, 9|add  r2, r1, r1|st   r2, 0[r10]|ld   r3, 0[r10]|nop|add  r4, r3, r2",
         "a chain that goes through memory: r2 = 18 is stored, loaded back into r3, then r4 = 18 + 18 = 36."),
        ("mov  r1, 1|mov  r2, 1|add  r3, r1, r2|add  r4, r2, r3|add  r5, r3, r4|add  r6, r4, r5|add  r7, r5, r6",
         "fibonacci where each add uses results from distance 1 and distance 2 at the same time. r7 should be 13."),
    ]
    for i, (code, what) in enumerate(chains):
        p = Prog()
        for line in code.split("|"):
            p.op(line)
        tests.append(make("forwarding", f"chain_{i}", what, p, []))
    return tests


def load_use_tests():
    tests = []

    def base(p, value=0x00000123):
        p.op("mov  r10, 0x200")
        p.const("r2", value)
        p.op("st   r2, 0[r10]")
        p.op("mov  r3, 5")
        p.nops(3)

    consumers = [
        ("add  r6, r5, r3", "add reads it as the first operand"),
        ("add  r6, r3, r5", "add reads it as the second operand"),
        ("add  r6, r5, r5", "add reads it as both operands"),
        ("sub  r6, r5, r3", "sub reads it"),
        ("mul  r6, r5, r3", "mul reads it"),
        ("div  r6, r5, r3", "div reads it"),
        ("and  r6, r5, r3", "and reads it"),
        ("lsl  r6, r3, r5", "it's the shift amount for lsl"),
        ("not  r6, r5", "not reads it (through the rs2 path)"),
        ("mov  r6, r5", "mov copies it (through the rs2 path)"),
        ("add  r6, r5, 7", "an add with an immediate reads it as rs1"),
        ("st   r5, 4[r10]", "st stores it (the data register)"),
    ]
    for i, (code, desc) in enumerate(consumers):
        for d in (1, 2):
            p = Prog()
            base(p)
            p.op("ld   r5, 0[r10]")
            p.nops(d - 1)
            p.op(code)
            if d == 1:
                what = (f"load r5 and then {desc} in the very next instruction. the loaded value isn't ready in time, "
                        "so the cpu has to stall for exactly 1 cycle.")
            else:
                what = (f"load r5, one nop, and then {desc}. by then the value is in MEM/WB and can be forwarded, "
                        "so there should be no stall at all.")
            tests.append(make("load_use", f"use{i:02d}_d{d}", what, p, ["r6"] if "st" not in code else ["mem[0x00000204]"]))

    for d in (1, 2):
        p = Prog()
        base(p, 0x123)
        p.op("ld   r5, 0[r10]")
        p.nops(d - 1)
        p.op("cmp  r5, 0x123")
        p.op("beq  ok")
        p.op("mov  r7, 1")
        p.label("ok")
        p.op("mov  r8, 1")
        what = (f"load r5 and compare it {'right away' if d == 1 else 'after a nop'}. "
                + ("cmp needs the loaded value so the cpu stalls 1 cycle. " if d == 1 else "no stall needed. ")
                + "r5 is 0x123 so beq is taken and r7 stays 0.")
        tests.append(make("load_use", f"cmp_d{d}", what, p, ["r7"]))
    for d in (1, 2):
        p = Prog()
        base(p, 0x240)
        p.op("ld   r5, 0[r10]")
        p.nops(d - 1)
        p.op("st   r3, 0[r5]")
        what = (f"load an address (0x240) into r5 and use it as the store's base {'right away' if d == 1 else 'after a nop'}. "
                + ("that's a load-use on the address, so 1 stall. " if d == 1 else "no stall. ")
                + "5 should land at mem[0x240].")
        tests.append(make("load_use", f"st_base_d{d}", what, p, ["mem[0x00000240]"]))
    for d in (1, 2):
        p = Prog()
        p.op("mov  r10, 0x200")
        p.op("mov  r9, 0x260")
        p.op("mov  r2, 0x0abc")
        p.op("st   r2, 0[r9]")
        p.op("st   r9, 0[r10]")
        p.nops(3)
        p.op("ld   r5, 0[r10]")
        p.nops(d - 1)
        p.op("ld   r6, 0[r5]")
        what = (f"pointer chasing: load a pointer (0x260) and then load from it {'right away' if d == 1 else 'after a nop'}. "
                + ("1 stall. " if d == 1 else "no stall. ") + "r6 should be 0xabc.")
        tests.append(make("load_use", f"ld_base_d{d}", what, p, ["r6"]))

    false_hazards = [
        ("r1", "add  r6, r3, 0x4000", "add r6, r3, 0x4000. the immediate's top bits sit where rs2 would be, and they spell r1. it's an immediate though, so no real dependency"),
        ("r5", "addu r6, r3, 0x4000", "addu r6, r3, 0x4000. with the u modifier those bits spell r5. still just an immediate"),
        ("r5", "movu r6, 0x4000", "movu r6, 0x4000. same bit pattern, mov with an immediate reads no register at all"),
        ("r5", "cmpu r3, 0x4000", "cmpu r3, 0x4000. same thing for cmp"),
        ("r5", "st   r3, 4[r10]", "a store that doesn't involve r5"),
        ("r5", "ld   r5, 4[r10]", "another load into r5. it writes r5 but doesn't read it"),
        ("r5", "nop", "a nop"),
        ("r5", "add  r6, r3, r4", "an add that uses other registers"),
    ]
    for i, (reg, code, desc) in enumerate(false_hazards):
        p = Prog()
        base(p)
        p.op("mov  r1, 66")
        p.op("mov  r4, 4")
        p.nops(2)
        p.op(f"ld   {reg}, 0[r10]")
        p.op(code)
        what = f"load {reg} and then {desc}. the cpu should NOT stall here (0 stalls)."
        tests.append(make("load_use", f"no_stall_{i}", what, p, ["r6"] if "r6" in code else []))

    chains = [
        ("ld   r5, 0[r10]|ld   r6, 0[r5]|add  r7, r6, r6", 0x240, "load a pointer, load through it, then use the result. that's two load-use pairs in a row, so 2 stalls."),
        ("ld   r5, 0[r10]|add  r6, r5, 1|ld   r7, 0[r10]|add  r8, r7, 2", 0x123, "two separate load-use pairs back to back, so 2 stalls."),
        ("ld   r5, 0[r10]|ld   r6, 0[r10]|add  r7, r5, r6", 0x123, "two loads then an add that uses both. r6 is distance 1 (needs a stall) and r5 is distance 2 (fine), so exactly 1 stall."),
        ("ld   r5, 0[r10]|ld   r6, 0[r10]|add  r7, r5, r5", 0x123, "two loads then an add that only uses the first one, which is distance 2 by then. 0 stalls."),
    ]
    for i, (code, value, what) in enumerate(chains):
        p = Prog()
        base(p, value)
        p.op("mov  r9, 0x240")
        p.op("st   r10, 0[r9]")
        p.nops(2)
        for line in code.split("|"):
            p.op(line)
        tests.append(make("load_use", f"chain_{i}", what, p, ["r7"] if "r8" not in code else ["r8"]))

    for r in (0, 1, 4, 8, 12, 14, 15):
        p = Prog()
        base(p, 0x00004321)
        p.op(f"ld   r{r}, 0[r10]")
        p.op(f"add  r6, r{r}, r{r}")
        what = f"load into r{r} and use it right away. 1 stall, and r6 should be 0x4321 + 0x4321 = 0x8642."
        tests.append(make("load_use", f"reg_r{r:02d}", what, p, ["r6"]))
    for v in (0xFFFFFFFF, 0x80000000, 0):
        p = Prog()
        base(p, v)
        p.op("ld   r5, 0[r10]")
        p.op("sub  r6, r5, r3")
        what = f"load {show(v)} and subtract 5 right away. 1 stall, and r6 should be {show(alu('sub', v, 5))}."
        tests.append(make("load_use", f"value_{v:08x}", what, p, ["r6"]))
    return tests


def branch_tests():
    tests = []
    pairs = [(5, 5), (5, 3), (3, 5), (0xFFFFFFFF, 1), (1, 0xFFFFFFFF), (0x7FFFFFFF, 0x80000000),
             (0x80000000, 0x7FFFFFFF), (0, 0), (0xFFFFFFFB, 0xFFFFFFFB), (0xFFFFFFFB, 0xFFFFFFFD),
             (0xFFFFFFFD, 0xFFFFFFFB), (0xFFFFFFFF, 0), (0, 0xFFFFFFFF), (0x80000000, 0x80000000),
             (0x80000000, 0), (0x7FFFFFFF, 0x7FFFFFFF)]

    def relation(a, b):
        sa, sb = signed(a), signed(b)
        if a == b:
            return "they're equal"
        s = f"{show(a)} is {'bigger' if sa > sb else 'smaller'} (signed)"
        if (a > b) != (sa > sb):
            s += " (careful, unsigned it would be the other way around)"
        return s

    def branch_what(br, a, b, rel):
        taken = (a == b) if br == "beq" else signed(a) > signed(b)
        if taken:
            return f"{rel}, so {br} should be taken and jump over the mov r5, 1. r5 should stay 0."
        return f"{rel}, so {br} should not be taken and the mov r5, 1 runs. r5 should be 1."

    for br in ("beq", "bgt"):
        for i, (a, b) in enumerate(pairs):
            p = Prog()
            p.const("r1", a)
            p.const("r2", b)
            p.nops(2)
            p.op("cmp  r1, r2")
            p.op(f"{br:<4} skip")
            p.op("mov  r5, 1")
            p.label("skip")
            p.op("mov  r6, 2")
            what = f"cmp {show(a)} with {show(b)}. " + branch_what(br, a, b, relation(a, b))
            tests.append(make("branches", f"{br}_reg_{i:02d}", what, p, ["r5"]))
        for i, (a, imm16) in enumerate([(5, 5), (5, 3), (3, 5), (0xFFFFFFFF, 0xFFFF), (0, 0xFFFF),
                                        (0xFFFF8000, 0x8000), (0x7FFF, 0x7FFF), (0xFFFFFFFE, 0xFFFF)]):
            b = imm_value(imm16, 0)
            p = Prog()
            p.const("r1", a)
            p.nops(2)
            p.op(f"cmp  r1, {imm_text(imm16, 0)}")
            p.op(f"{br:<4} skip")
            p.op("mov  r5, 1")
            p.label("skip")
            p.op("mov  r6, 2")
            what = f"cmp {show(a)} with the immediate {imm_words(imm16, 0)}. " + branch_what(br, a, b, relation(a, b))
            tests.append(make("branches", f"{br}_imm_{i:02d}", what, p, ["r5"]))

    for br in ("beq", "bgt"):
        for a, b in ((7, 7), (9, 2)) if br == "beq" else ((9, 2), (2, 9)):
            for d in (1, 2, 3):
                p = Prog()
                p.op(f"mov  r1, {a}")
                p.op(f"mov  r2, {b}")
                p.nops(2)
                p.op("cmp  r1, r2")
                for k in range(d - 1):
                    p.op(f"add  r{7 + k}, r1, r2")
                p.op(f"{br:<4} skip")
                p.op("mov  r5, 1")
                p.label("skip")
                what = (f"cmp {a} with {b}, then {br} {d} instruction{'s' if d > 1 else ''} later (the adds in between "
                        "don't touch the flags). " + branch_what(br, a, b, relation(a, b)))
                tests.append(make("branches", f"{br}_dist_{a}_{b}_d{d}", what, p, ["r5"]))

    for br, a, b in (("beq", 4, 4), ("bgt", 8, 1), ("beq", 4, 5)):
        p = Prog()
        p.op(f"mov  r1, {a}")
        p.op(f"mov  r2, {b}")
        p.op("mov  r10, 0x200")
        p.nops(2)
        p.op("cmp  r1, r2")
        p.op("sub  r3, r2, r1")
        p.op("st   r3, 0[r10]")
        p.op("ld   r4, 0[r10]")
        p.op("mov  r6, 100")
        p.op(f"{br:<4} skip")
        p.op("mov  r5, 1")
        p.label("skip")
        what = (f"cmp {a} with {b}, then a sub, a store, a load and a mov before the {br}. none of those change the "
                "flags (only cmp does), so the branch still uses the old compare. " + branch_what(br, a, b, relation(a, b)))
        tests.append(make("branches", f"flags_hold_{br}_{a}_{b}", what, p, ["r5"]))

    for br, first, second in (("beq", (3, 3), (3, 4)), ("bgt", (9, 1), (1, 9)), ("beq", (1, 2), (6, 6))):
        p = Prog()
        p.op(f"mov  r1, {first[0]}")
        p.op(f"mov  r2, {first[1]}")
        p.op(f"mov  r3, {second[0]}")
        p.op(f"mov  r4, {second[1]}")
        p.nops(2)
        p.op("cmp  r1, r2")
        p.op("cmp  r3, r4")
        p.op(f"{br:<4} skip")
        p.op("mov  r5, 1")
        p.label("skip")
        what = (f"two cmps in a row ({first[0]} vs {first[1]}, then {second[0]} vs {second[1]}). the second one "
                "overwrites the flags, so only it matters. " + branch_what(br, *second, relation(*second)))
        tests.append(make("branches", f"cmp_twice_{br}_{second[0]}_{second[1]}", what, p, ["r5"]))

    for br in ("beq", "bgt"):
        p = Prog()
        p.op(f"{br:<4} skip")
        p.op("mov  r5, 1")
        p.label("skip")
        what = f"{br} before any cmp has run. reset clears both flags, so it should not be taken and r5 should be 1."
        tests.append(make("branches", f"{br}_after_reset", what, p, ["r5"]))

    for k in range(5):
        p = Prog()
        p.op("mov  r10, 0x200")
        p.op("mov  r9, 0x0bad")
        p.nops(2)
        p.op("b    skip")
        for j in range(k):
            p.op(["mov  r5, 1", "mov  r6, 1", "st   r9, 0[r10]", "add  r7, r9, r9", "mov  r8, 1"][j])
        p.label("skip")
        p.op("mov  r4, 1")
        if k == 0:
            what = "b to the very next instruction. it's still a taken branch, so it costs 2 cycles even though nothing gets skipped."
        else:
            what = (f"b jumps over {k} instruction{'s' if k > 1 else ''}. the cpu fetches up to 2 of them before it knows "
                    "the branch is taken, so they must get flushed and never write anything (no register writes, no store).")
        tests.append(make("branches", f"b_skip_{k}", what, p, ["r4"]))

    for gap in (0, 1):
        p = Prog()
        p.op("mov  r10, 0x200")
        p.op("mov  r1, 3")
        p.op("mov  r9, 0x0bad")
        p.nops(2)
        p.op("cmp  r1, 3")
        p.op("beq  skip")
        p.nops(gap)
        p.op("st   r9, 0[r10]")
        p.op("st   r9, 4[r10]")
        p.label("skip")
        p.op("ld   r2, 0[r10]")
        what = "beq is taken over two stores. they're on the wrong path, so memory has to stay empty and r2 should load 0."
        tests.append(make("branches", f"wrong_path_store_{gap}", what, p, ["r2"]))

    for n in range(1, 7):
        p = Prog()
        p.op(f"mov  r1, {n}")
        p.op("mov  r2, 0")
        p.label("loop")
        p.op("add  r2, r2, 3")
        p.op("sub  r1, r1, 1")
        p.op("cmp  r1, 0")
        p.op("bgt  loop")
        what = (f"a loop that runs {n} time{'s' if n > 1 else ''} using a backward bgt. r2 adds 3 each time so it should be "
                f"{3 * n}. the bgt is taken {n - 1} time{'s' if n != 2 else ''}, so that's {n - 1} flush{'es' if n != 2 else ''}.")
        tests.append(make("branches", f"loop_{n}", what, p, ["r2"]))
    for outer, inner in ((2, 3), (3, 4)):
        p = Prog()
        p.op(f"mov  r1, {outer}")
        p.op("mov  r3, 0")
        p.label("outer")
        p.op(f"mov  r2, {inner}")
        p.label("inner")
        p.op("add  r3, r3, 1")
        p.op("sub  r2, r2, 1")
        p.op("cmp  r2, 0")
        p.op("bgt  inner")
        p.op("sub  r1, r1, 1")
        p.op("cmp  r1, 0")
        p.op("bgt  outer")
        what = f"nested loops, {outer} times {inner}. r3 counts every inner step, so it should be {outer * inner}."
        tests.append(make("branches", f"nested_{outer}x{inner}", what, p, ["r3"]))

    p = Prog()
    p.op("b    first")
    p.op("mov  r5, 1")
    p.label("first")
    p.op("b    second")
    p.op("mov  r6, 1")
    p.label("second")
    p.op("mov  r4, 1")
    what = "a taken branch that lands on another taken branch. 2 flushes, and neither mov r5 nor mov r6 should run."
    tests.append(make("branches", "branch_to_branch", what, p, ["r5", "r6"]))
    p = Prog()
    p.op("mov  r1, 1")
    p.op("cmp  r1, 1")
    p.op("beq  first")
    p.op("mov  r5, 1")
    p.label("first")
    p.op("bgt  never")
    p.op("beq  second")
    p.op("mov  r6, 1")
    p.label("never")
    p.op("mov  r7, 1")
    p.label("second")
    p.op("mov  r4, 1")
    what = "beq taken, lands on a bgt that's not taken (1 is not > 1), then another beq that is taken. r5, r6 and r7 should all stay 0."
    tests.append(make("branches", "branch_chain", what, p, ["r5", "r6", "r7"]))
    p = Prog()
    p.op("mov  r1, 2")
    p.op("cmp  r1, 7")
    p.op("beq  a")
    p.op("beq  a")
    p.op("bgt  a")
    p.op("mov  r4, 1")
    p.label("a")
    p.op("mov  r5, 1")
    what = "three branches in a row and none of them is taken (2 is not equal to 7 and not bigger). no flushes, r4 and r5 should both be 1."
    tests.append(make("branches", "three_not_taken", what, p, ["r4"]))
    p = Prog()
    p.op("mov  r1, 9")
    p.op("b    halt")
    p.op("mov  r5, 1")
    what = "b straight to the halt loop. the mov after it must not run."
    tests.append(make("branches", "branch_to_halt", what, p, ["r5"]))

    for br, a, b in (("beq", 6, 6), ("beq", 6, 7), ("bgt", 8, 6), ("bgt", 6, 8)):
        for d in (1, 2, 3):
            p = Prog()
            p.op(f"mov  r2, {b - 1}")
            p.nops(3)
            p.op(f"add  r1, r2, {a - b + 1}")
            p.fillers(d - 1, "r9")
            p.op(f"cmp  r1, {b}")
            p.op(f"{br:<4} skip")
            p.op("mov  r5, 1")
            p.label("skip")
            what = (f"the add makes r1 = {a} and the cmp reads it {d} instruction{'s' if d > 1 else ''} later (so it's "
                    f"forwarded into the cmp). then cmp r1, {b}: " + branch_what(br, a, b, relation(a, b)))
            tests.append(make("branches", f"fwd_into_cmp_{br}_{a}_{b}_d{d}", what, p, ["r5"]))
    return tests


def call_tests():
    tests = []
    for pad in (0, 1, 3, 10):
        p = Prog()
        p.op("mov  sp, 0x800")
        p.nops(pad)
        p.op("call func")
        p.op("mov  r4, 1")
        p.op("b    halt")
        p.label("func")
        p.op("mov  r3, 7")
        p.op("ret")
        ret_addr = (2 + pad) * 4
        what = (f"call a function from address {h((1 + pad) * 4)}. call saves pc + 4 in r15, so r15 should be "
                f"{h(ret_addr)}. the function sets r3 = 7, ret comes back and mov r4, 1 runs.")
        tests.append(make("calls", f"basic_pad{pad}", what, p, ["r15", "r3", "r4"]))

    funcs = [
        ("add_two", "add  r0, r1, r2|ret", lambda a, b: alu("add", a, b), "adds r1 and r2"),
        ("max", "cmp  r1, r2|bgt  maxa|mov  r0, r2|ret|maxa:|mov  r0, r1|ret",
         lambda a, b: a if signed(a) > signed(b) else b, "returns the bigger of r1 and r2 (signed)"),
        ("abs", "cmp  r1, 0|bgt  absp|sub  r0, r2, r1|ret|absp:|mov  r0, r1|ret",
         lambda a, b: (b - a) & MASK if signed(a) <= 0 else a, "returns |r1| (r2 is 0 here)"),
        ("square", "mul  r0, r1, r1|ret", lambda a, b: alu("mul", a, a), "squares r1"),
        ("sum_to", "mov  r0, 0|sumloop:|add  r0, r0, r1|sub  r1, r1, 1|cmp  r1, 0|bgt  sumloop|ret",
         lambda a, b: a * (a + 1) // 2, "adds 1 + 2 + ... + r1 with a loop"),
    ]
    for name, body, fn, desc in funcs:
        for a, b in ((7, 12), (0xFFFFFFF6, 0) if name == "abs" else (25, 9)):
            p = Prog()
            p.op("mov  sp, 0x800")
            p.const("r1", a)
            p.const("r2", b)
            p.op("call func")
            p.op("mov  r9, r0")
            p.op("b    halt")
            p.label("func")
            for line in body.split("|"):
                if line.endswith(":"):
                    p.label(line[:-1])
                else:
                    p.op(line)
            res = fn(a, b) & MASK
            what = (f"call a function that {desc}. r1 = {show(a)}, r2 = {show(b)}, so it should return "
                    f"{show(res)} in r0, and the caller copies it into r9 right after the ret.")
            tests.append(make("calls", f"func_{name}_{a & 0xFF:02x}", what, p, ["r0", "r9"]))

    for gap in (0, 1):
        p = Prog()
        p.op("call func")
        p.op("mov  r4, 1")
        p.op("b    halt")
        p.label("func")
        p.nops(gap)
        p.op("ret")
        what = ("call a function that just returns" + (" right away" if gap == 0 else " after a nop")
                + ". ret needs the r15 that call just wrote. mov r4, 1 should run after it.")
        tests.append(make("calls", f"empty_func_{gap}", what, p, ["r4", "r15"]))

    for depth in (2, 3, 4):
        p = Prog()
        p.op("mov  sp, 0x800")
        p.op("mov  r3, 0")
        p.op("call f1")
        p.op("mov  r4, 1")
        p.op("b    halt")
        for lvl in range(1, depth + 1):
            p.label(f"f{lvl}")
            p.op("sub  sp, sp, 4")
            p.op("st   ra, 0[sp]")
            p.op("add  r3, r3, 1")
            if lvl < depth:
                p.op(f"call f{lvl + 1}")
            p.op("ld   ra, 0[sp]")
            p.op("add  sp, sp, 4")
            p.op("ret")
        what = (f"calls nested {depth} deep. each function saves r15 on the stack before calling the next one and "
                f"restores it before ret. r3 counts the levels so it should be {depth}, sp should be back to 0x800 "
                "and mov r4, 1 should run at the end.")
        tests.append(make("calls", f"nested_{depth}", what, p, ["r3", "r4", "r14"]))

    for d in (1, 2, 3):
        p = Prog()
        p.op("mov  sp, 0x800")
        p.op("call func")
        p.op("mov  r4, 1")
        p.op("b    halt")
        p.label("func")
        p.op("sub  sp, sp, 4")
        p.op("st   ra, 0[sp]")
        p.op("mov  ra, 0")
        p.op("add  sp, sp, 4")
        p.op("ld   ra, -4[sp]")
        p.fillers(d - 1, "r9")
        p.op("ret")
        what = ("the function trashes r15, then loads it back from the stack and does ret "
                + ("right after the load. " if d == 1 else f"{d} instructions after the load. ")
                + ("ret reads r15 right after the load, so that's a load-use: 1 stall. " if d == 1 else "no stall needed. ")
                + "it should still return to the right place and run mov r4, 1.")
        tests.append(make("calls", f"ld_ra_then_ret_d{d}", what, p, ["r4"]))

    for d in (1, 2, 3):
        p = Prog()
        p.op("call func")
        p.op("mov  r4, 1")
        p.op("mov  r5, 1")
        p.op("b    halt")
        p.label("func")
        p.op("add  r15, r15, 4")
        p.fillers(d - 1, "r9")
        p.op("ret")
        what = (f"the function adds 4 to r15 before returning, so it comes back one instruction later than normal "
                f"and skips mov r4, 1 (r4 stays 0, r5 becomes 1). ret reads r15 "
                + ("right after the add" if d == 1 else f"{d} instructions after the add")
                + ", so the new r15 has to be forwarded into ret.")
        tests.append(make("calls", f"ret_after_add_d{d}", what, p, ["r4", "r5"]))

    for n in (1, 3, 5):
        p = Prog()
        p.op(f"mov  r1, {n}")
        p.op("mov  r3, 0")
        p.label("loop")
        p.op("call func")
        p.op("sub  r1, r1, 1")
        p.op("cmp  r1, 0")
        p.op("bgt  loop")
        p.op("b    halt")
        p.label("func")
        p.op("add  r3, r3, 10")
        p.op("ret")
        what = f"call a function {n} time{'s' if n > 1 else ''} from a loop. it adds 10 to r3 each time, so r3 should be {10 * n}."
        tests.append(make("calls", f"call_in_loop_{n}", what, p, ["r3"]))

    for gap in (0, 1):
        p = Prog()
        p.op("nop")
        p.op("call func")
        p.op("b    halt")
        p.label("func")
        p.nops(gap)
        p.op("add  r3, r15, 0")
        p.op("ret")
        what = (f"the function reads r15 {'as its very first instruction' if gap == 0 else 'right after a nop'}. "
                "r3 should get the return address, 0x00000008.")
        tests.append(make("calls", f"read_ra_{gap}", what, p, ["r3"]))

    for n in (5, 10):
        p = Prog()
        p.op("mov  sp, 0x800")
        p.op(f"mov  r1, {n}")
        p.op("call sum")
        p.op("b    halt")
        p.label("sum")
        p.op("cmp  r1, 0")
        p.op("bgt  more")
        p.op("mov  r0, 0")
        p.op("ret")
        p.label("more")
        p.op("sub  sp, sp, 8")
        p.op("st   ra, 4[sp]")
        p.op("st   r1, 0[sp]")
        p.op("sub  r1, r1, 1")
        p.op("call sum")
        p.op("ld   r1, 0[sp]")
        p.op("ld   ra, 4[sp]")
        p.op("add  sp, sp, 8")
        p.op("add  r0, r0, r1")
        p.op("ret")
        what = (f"recursive sum(n) = n + sum(n - 1), with sum(0) = 0. sum({n}) should be {n * (n + 1) // 2} in r0, "
                "and sp should be back at 0x800.")
        tests.append(make("calls", f"recursive_sum_{n}", what, p, ["r0", "r14"]))

    p = Prog()
    p.op("b    main")
    p.label("func")
    p.op("mov  r3, 33")
    p.op("ret")
    p.label("main")
    p.op("call func")
    p.op("mov  r4, 1")
    what = "the function sits before the main code, so call jumps backwards. r3 should be 33 and r4 should be 1."
    tests.append(make("calls", "backward_call", what, p, ["r3", "r4"]))

    for regs in ((1, 2, 3, 4), (5, 6, 7, 8)):
        p = Prog()
        p.op("mov  sp, 0x800")
        for r in regs:
            p.op(f"mov  r{r}, {r * 11}")
        p.op("call func")
        p.op("b    halt")
        p.label("func")
        p.op(f"sub  sp, sp, {4 * len(regs)}")
        for i, r in enumerate(regs):
            p.op(f"st   r{r}, {4 * i}[sp]")
        for r in regs:
            p.op(f"mov  r{r}, 0")
        p.op("add  r9, r9, 1")
        for i, r in enumerate(regs):
            p.op(f"ld   r{r}, {4 * i}[sp]")
        p.op(f"add  sp, sp, {4 * len(regs)}")
        p.op("ret")
        what = (f"the function saves r{regs[0]} to r{regs[-1]} on the stack, zeroes them, then restores them. after "
                f"the call they should all have their old values back ({', '.join(str(r * 11) for r in regs)}).")
        tests.append(make("calls", f"save_restore_r{regs[0]}", what, p, [f"r{r}" for r in regs]))
    return tests


def hazard_mix_tests(rng):
    tests = []
    snippets = [
        ("ld   r5, 0[r10]|cmp  r5, r3|beq  skip|mov  r7, 1|skip:|mov  r8, 1", 5,
         "load r5 and compare it right away (1 stall), then beq is taken (1 flush). r7 should stay 0."),
        ("ld   r5, 0[r10]|cmp  r5, r3|bgt  skip|mov  r7, 1|skip:|mov  r8, 1", 5,
         "load r5, compare right away (1 stall). 5 is not bigger than 5, so bgt is not taken and r7 becomes 1."),
        ("b    target|mov  r7, 1|target:|ld   r5, 0[r10]|add  r6, r5, r5", 0x21,
         "a taken branch lands on a load-use pair. 1 flush, then 1 stall. r6 should be 0x42."),
        ("ld   r5, 0[r10]|b    skip|mov  r7, 1|skip:|add  r6, r5, r5", 0x21,
         "load r5 then a taken branch. by the time the add at the target reads r5 it's long ready, so 0 stalls and 1 flush."),
        ("cmp  r3, r3|beq  skip|ld   r7, 0[r10]|add  r8, r7, r7|skip:|mov  r9, 1", 0x21,
         "beq is taken over a load-use pair. those two are on the wrong path, so they don't run and don't stall. r7 and r8 stay 0."),
        ("ld   r5, 0[r10]|add  r6, r5, r3|sub  r7, r6, r5", 0x30,
         "load r5, use it right away (1 stall), then the sub needs r6 from EX/MEM and r5 from MEM/WB at the same time. r7 should be 5."),
        ("ld   r5, 0[r10]|st   r5, 4[r10]|ld   r6, 4[r10]|add  r7, r6, r6", 0x30,
         "load, store the loaded value right away (1 stall), load it back from the new place and use it right away (another stall). r7 should be 0x60."),
        ("mov  r1, 0x200|ld   r5, 0[r1]|add  r6, r5, r1", 0x30,
         "the load's address comes from the mov right before it (forwarded), and the add needs the load right away (1 stall) plus r1 (forwarded). r6 should be 0x230."),
        ("mov  r9, 0x240|st   r9, 0[r10]|mov  r8, 0x250|st   r8, 0[r9]|mov  r7, 0x77|st   r7, 0[r8]|ld   r1, 0[r10]|ld   r2, 0[r1]|ld   r4, 0[r2]|add  r6, r4, r1", 0,
         "follow a chain of 3 pointers in memory, each load needs the one before it, and then use the last one. that's 3 stalls. r6 should be 0x77 + 0x240 = 0x2b7."),
        ("cmp  r3, 5|ld   r5, 0[r10]|beq  skip|mov  r7, 1|skip:|add  r6, r5, 1", 0x10,
         "cmp, then a load, then beq. the load doesn't change the flags, so beq still sees 5 == 5 and is taken. no stall (the add after the branch is far from the load)."),
        ("ld   r5, 0[r10]|cmp  r5, 1|bgt  skip|mov  r7, 1|skip:|add  r6, r5, r5", 0x10,
         "load, compare right away (1 stall), bgt taken (0x10 > 1), and the target uses r5 again. r7 stays 0 and r6 is 0x20."),
        ("call func|add  r6, r0, r0|b    halt|func:|ld   r0, 0[r10]|add  r0, r0, 1|ret", 0x10,
         "a load-use inside a function (1 stall), then the caller uses the function's result right after ret. r6 should be 0x22."),
        ("ld   r5, 0[r10]|nop|ld   r6, 0[r10]|add  r7, r5, r6|cmp  r7, 0x20|beq  skip|mov  r8, 1|skip:|mov  r9, 2", 0x10,
         "two loads with a nop between, the add only stalls for the second one (1 stall). 0x10 + 0x10 = 0x20 so beq is taken and r8 stays 0."),
    ]
    for i, (code, value, what) in enumerate(snippets):
        p = Prog()
        p.op("mov  sp, 0x800")
        p.op("mov  r10, 0x200")
        p.const("r2", value)
        p.op("st   r2, 0[r10]")
        p.op("mov  r3, 5")
        p.nops(3)
        for line in code.split("|"):
            if line.endswith(":"):
                p.label(line[:-1])
            else:
                p.op(line)
        tests.append(make("hazard_mix", f"mix_{i:02d}", what, p, []))

    for n in range(1, 6):
        p = Prog()
        p.op("mov  r10, 0x200")
        p.op("mov  r2, 4")
        p.op("st   r2, 0[r10]")
        p.op(f"mov  r1, {n}")
        p.op("mov  r3, 0")
        p.label("loop")
        p.op("ld   r4, 0[r10]")
        p.op("add  r3, r3, r4")
        p.op("sub  r1, r1, 1")
        p.op("cmp  r1, 0")
        p.op("bgt  loop")
        what = (f"a loop that runs {n} time{'s' if n > 1 else ''} with a load-use pair inside, so {n} stall"
                f"{'s' if n > 1 else ''} and {n - 1} flush{'es' if n != 2 else ''}. r3 adds 4 each time, so it should be {4 * n}.")
        tests.append(make("hazard_mix", f"loop_load_use_{n}", what, p, ["r3"]))

    for i in range(20):
        tests.append(random_program(rng, "hazard_mix", f"random_{i:02d}", length=rng.randint(12, 24),
                                    pool=rng.randint(2, 3), load_heavy=True))
    return tests


def random_program(rng, group, name, length, pool, load_heavy=False):
    regs = rng.sample([f"r{i}" for i in range(1, 10)], pool)
    p = Prog()
    p.op("mov  r10, 0x200")
    for r in regs:
        p.const(r, rng.choice([rng.getrandbits(32), rng.randint(0, 100), (-rng.randint(1, 100)) & MASK]))
    n = 0
    pending = []
    label_no = 0
    while n < length:
        for lab in [l for l in pending if l[1] <= n]:
            p.label(lab[0])
            pending.remove(lab)
        roll = rng.random()
        rd, ra, rb = rng.choice(regs), rng.choice(regs), rng.choice(regs)
        if roll < (0.25 if load_heavy else 0.12):
            p.op(f"ld   {rd}, {4 * rng.randint(0, 15)}[r10]")
        elif roll < (0.4 if load_heavy else 0.22):
            p.op(f"st   {ra}, {4 * rng.randint(0, 15)}[r10]")
        elif roll < 0.5:
            p.op(f"cmp  {ra}, {rb}" if rng.random() < 0.6 else f"cmp  {ra}, {rng.randint(-20, 20)}")
        elif roll < 0.6 and n < length - 1:
            label_no += 1
            lab = f"skip{label_no}"
            p.op(f"{rng.choice(['beq ', 'bgt ', 'bgt ', 'b   '])} {lab}")
            pending.append((lab, n + 1 + rng.randint(1, 3)))
        elif roll < 0.68:
            op = rng.choice(["mov", "not"])
            p.op(f"{op:<4} {rd}, {rb}" if rng.random() < 0.5 else f"{op:<4} {rd}, {rng.randint(-100, 100)}")
        else:
            op = rng.choice(ALU)
            if rng.random() < 0.6:
                p.op(f"{op:<4} {rd}, {ra}, {rb}")
            else:
                imm = rng.randint(0, 31) if op in ("lsl", "lsr", "asr") else rng.randint(-50, 50)
                p.op(f"{op:<4} {rd}, {ra}, {imm}")
        n += 1
    for lab in pending:
        p.label(lab[0])
    used = ", ".join(sorted(regs, key=lambda r: int(r[1:])))
    what = (f"random mix of {length} instructions that only use {used} (plus r10 as the memory base), so almost "
            "every instruction depends on the ones just before it. the branches only jump forward.")
    return make(group, name, what, p, [])


def random_tests(rng):
    return [random_program(rng, "random", f"mix_{i:03d}", length=rng.randint(15, 40), pool=rng.randint(3, 6))
            for i in range(120)]


def generate(seed=1):
    rng = random.Random(seed)
    tests = []
    tests += alu_tests()
    tests += immediate_tests()
    tests += registers_tests()
    tests += memory_tests(rng)
    tests += forwarding_tests(rng)
    tests += load_use_tests()
    tests += branch_tests()
    tests += call_tests()
    tests += hazard_mix_tests(rng)
    tests += random_tests(rng)
    return tests

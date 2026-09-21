#!/usr/bin/env python3
"""
sr_asm.py - small assembler for our SimpleRisc processor.

Encoding matches rtl/common/simpleriscprocessor_pkg.sv and decoder.sv:
    [31:27] opcode   [26] I   [25:22] rd   [21:18] rs1   [17:14] rs2
    [17:16] modifier (00 default, 01 'u', 10 'h')   [15:0] imm16
    branches: [26:0] offset in instructions, target = pc + offset*4

Syntax (SimpleRisc style):
    add r1, r2, r3        add r1, r2, 10       addu / addh r1, r2, 0xffff
    cmp r1, r2            not r1, r2           mov r1, 5     movh r1, 0x1234
    ld  r1, 8[r2]         st  r1, -4[sp]
    b label   beq label   bgt label   call label   ret   nop
    label:                comments start with @ ; // or #
    registers r0-r15, sp = r14, ra = r15

Usage:
    python3 tools/sr_asm.py prog.s -o prog.hex [-l]     (-l prints a listing)
"""
import argparse
import re
import sys

OPCODES = {
    "add": 0b00000, "sub": 0b00001, "mul": 0b00010, "div": 0b00011,
    "mod": 0b00100, "cmp": 0b00101, "and": 0b00110, "or":  0b00111,
    "not": 0b01000, "mov": 0b01001, "lsl": 0b01010, "lsr": 0b01011,
    "asr": 0b01100, "nop": 0b01101, "ld":  0b01110, "st":  0b01111,
    "beq": 0b10000, "bgt": 0b10001, "b":   0b10010, "call": 0b10011,
    "ret": 0b10100,
}

THREE_ADDR = {"add", "sub", "mul", "div", "mod", "and", "or", "lsl", "lsr", "asr"}
TWO_ADDR   = {"not", "mov"}
BRANCHES   = {"b", "beq", "bgt", "call"}
MODIFIERS  = {"": 0b00, "u": 0b01, "h": 0b10}


class AsmError(Exception):
    pass


def parse_reg(tok):
    tok = tok.strip().lower()
    if tok == "sp":
        return 14
    if tok == "ra":
        return 15
    m = re.fullmatch(r"r(\d+)", tok)
    if not m or int(m.group(1)) > 15:
        raise AsmError(f"bad register '{tok}'")
    return int(m.group(1))


def is_reg(tok):
    try:
        parse_reg(tok)
        return True
    except AsmError:
        return False


def parse_int(tok):
    try:
        return int(tok.strip(), 0)
    except ValueError:
        raise AsmError(f"bad number '{tok}'")


def imm_field(value, mod, mnemonic):
    """18-bit immediate field: 2-bit modifier + 16-bit value."""
    if mod == "":
        if not -32768 <= value <= 32767:
            raise AsmError(f"{mnemonic}: immediate {value} does not fit in 16 bits signed "
                           f"(use the 'u' or 'h' form)")
    else:
        if not 0 <= value <= 0xFFFF:
            raise AsmError(f"{mnemonic}{mod}: immediate {value} must be 0..0xffff")
    return (MODIFIERS[mod] << 16) | (value & 0xFFFF)


def split_mnemonic(word):
    word = word.lower()
    if word in OPCODES:
        return word, ""
    if word[-1] in "uh" and word[:-1] in (THREE_ADDR | TWO_ADDR | {"cmp"}):
        return word[:-1], word[-1]
    raise AsmError(f"unknown instruction '{word}'")


def strip_comment(line):
    for c in ("@", ";", "//", "#"):
        i = line.find(c)
        if i >= 0:
            line = line[:i]
    return line.strip()


def first_pass(lines):
    labels, instrs = {}, []
    for lineno, raw in enumerate(lines, 1):
        line = strip_comment(raw)
        while True:
            m = re.match(r"^([A-Za-z_]\w*)\s*:(.*)$", line)
            if not m:
                break
            name = m.group(1)
            if name in labels:
                raise AsmError(f"line {lineno}: label '{name}' defined twice")
            labels[name] = len(instrs)
            line = m.group(2).strip()
        if line:
            instrs.append((lineno, line, raw.rstrip()))
    return labels, instrs


def encode(line, index, labels):
    parts = line.split(None, 1)
    op, mod = split_mnemonic(parts[0])
    args = [a.strip() for a in parts[1].split(",")] if len(parts) > 1 else []
    opc = OPCODES[op]

    def need(n):
        if len(args) != n:
            raise AsmError(f"'{op}' expects {n} operand(s), got {len(args)}")

    if op in THREE_ADDR:
        need(3)
        rd, rs1 = parse_reg(args[0]), parse_reg(args[1])
        if is_reg(args[2]) and mod == "":
            return (opc << 27) | (rd << 22) | (rs1 << 18) | (parse_reg(args[2]) << 14)
        return (opc << 27) | (1 << 26) | (rd << 22) | (rs1 << 18) | imm_field(parse_int(args[2]), mod, op)

    if op == "cmp":
        need(2)
        rs1 = parse_reg(args[0])
        if is_reg(args[1]) and mod == "":
            return (opc << 27) | (rs1 << 18) | (parse_reg(args[1]) << 14)
        return (opc << 27) | (1 << 26) | (rs1 << 18) | imm_field(parse_int(args[1]), mod, op)

    if op in TWO_ADDR:
        need(2)
        rd = parse_reg(args[0])
        if is_reg(args[1]) and mod == "":
            return (opc << 27) | (rd << 22) | (parse_reg(args[1]) << 14)
        return (opc << 27) | (1 << 26) | (rd << 22) | imm_field(parse_int(args[1]), mod, op)

    if op in ("ld", "st"):
        need(2)
        rd = parse_reg(args[0])
        m = re.fullmatch(r"(.*)\[\s*(\w+)\s*\]", args[1].replace(" ", ""))
        if not m:
            raise AsmError(f"{op}: expected 'imm[reg]', got '{args[1]}'")
        off = parse_int(m.group(1)) if m.group(1) else 0
        rs1 = parse_reg(m.group(2))
        return (opc << 27) | (1 << 26) | (rd << 22) | (rs1 << 18) | imm_field(off, "", op)

    if op in BRANCHES:
        need(1)
        target = args[0]
        if target == ".":
            offset = 0
        elif target in labels:
            offset = labels[target] - index
        else:
            raise AsmError(f"unknown label '{target}'")
        return (opc << 27) | (offset & 0x7FF_FFFF)

    if op in ("ret", "nop"):
        need(0)
        return opc << 27

    raise AsmError(f"cannot encode '{line}'")


def assemble(text):
    labels, instrs = first_pass(text.splitlines())
    words = []
    for index, (lineno, line, raw) in enumerate(instrs):
        try:
            words.append((encode(line, index, labels), raw))
        except AsmError as e:
            raise AsmError(f"line {lineno}: {e}  ->  {raw.strip()}")
    return words


def main():
    ap = argparse.ArgumentParser(description="SimpleRisc assembler")
    ap.add_argument("src")
    ap.add_argument("-o", "--out", help="output .hex (default: src with .hex)")
    ap.add_argument("-l", "--listing", action="store_true", help="print a listing")
    a = ap.parse_args()

    with open(a.src) as f:
        try:
            words = assemble(f.read())
        except AsmError as e:
            sys.exit(f"{a.src}: {e}")

    out = a.out or re.sub(r"\.\w+$", "", a.src) + ".hex"
    with open(out, "w") as f:
        for w, raw in words:
            f.write(f"{w:08x}   // {raw.strip()}\n")

    if a.listing:
        for i, (w, raw) in enumerate(words):
            print(f"{i*4:04x}:  {w:08x}   {raw.strip()}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
import argparse
import datetime
import os
import re
import shutil
import subprocess
import sys
import textwrap
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, "tools"))

import gen_tests
import refmodel
import sr_asm

BUILD = os.path.join(ROOT, "build", "integration")
FILL = 2

GROUP_ORDER = ["alu", "immediate", "registers", "memory", "forwarding", "load_use", "branches",
               "calls", "hazard_mix", "reset", "programs", "random"]

ABOUT = {
    "alu": "these check one alu operation at a time with edge values. there are 3 nops before the operation so forwarding isn't involved, the values come straight from the register file.",
    "immediate": "these check how the 16-bit immediate gets stretched to 32 bits: sign-extended (no suffix), zero-extended (u), or put in the top half (h).",
    "registers": "these check the register file itself: every register works, r0 isn't stuck at 0, the newest write wins, and the write-first bypass works.",
    "memory": "these check loads and stores: different addresses and offsets, the first and last word, unaligned addresses, out of range addresses, and loads right after stores.",
    "forwarding": "each test writes a register and reads it a few instructions later. distance 1 and 2 need the forwarding unit, distance 3 needs the bypass in reg_file, and distance 4 needs nothing.",
    "load_use": "a load followed right away by an instruction that needs the loaded value. the cpu has to stall exactly 1 cycle for those, and never stall when there's no real dependency.",
    "branches": "these check cmp, beq, bgt and b. each one writes a marker register on the path that shouldn't run, so if the cpu goes the wrong way the registers show it.",
    "calls": "these check call and ret: the return address in r15, nested calls using the stack, and ret right after r15 changes.",
    "hazard_mix": "these put stalls, forwarding and flushes together in the same few instructions, plus small random programs heavy on loads.",
    "reset": "these pull reset in the middle of a program, while instructions are still in the pipeline. after reset the cpu should start over from pc 0 and give the same answer as a normal run.",
    "programs": "real programs written by hand (sorting, factorial, gcd and so on). the expected answers in the .s file were worked out by hand.",
    "random": "random programs on a few registers. nobody wrote the expected values by hand, they come from the python reference model (refmodel.py).",
}

WHERE = {
    "alu": "forwarding is out of the picture here, so look at alu.v first (the case for this operation). for an immediate test also check the immediate extension in decoder.v.",
    "immediate": "look at the immediate extension in decoder.v (the case on the modifier), then alu.v.",
    "registers": "look at reg_file.v (the write and the bypass), then writeback.v for the write address and enable.",
    "memory": "look at memory_unit.v and memory_blackbox.v. if the address is wrong, check the add in the alu. if the stored data is wrong, check the forwarded op2 that goes into ex_mem_reg.v.",
    "forwarding": "look at forwarding_unit.v: the address match, the valid bits, and the priority (EX/MEM has to win over MEM/WB). for distance 3 look at the bypass in reg_file.v.",
    "load_use": "if the stall count is off, look at hazard_unit.v (load_use) and the valid bits coming out of decoder.v. if the stalls are right but a value is wrong, check the MEM/WB forward in forwarding_unit.v.",
    "branches": "look at branch_unit.v and flags.v for the decision, and the target adder in execute_stage.v. if a wrong-path instruction wrote something, the flush didn't happen (hazard_unit.v, if_id_reg.v, id_ex_reg.v).",
    "calls": "look at writeback.v (call writes pc + 4 to r15), the ret path in branch_unit.v, and the r15 forward in forwarding_unit.v.",
    "hazard_mix": "check the stall and flush counts first, they usually point at hazard_unit.v or forwarding_unit.v.",
    "reset": "something survived the reset. check that every pipeline register clears to a bubble (if_id_reg, id_ex_reg, ex_mem_reg, mem_wb_reg) and that pc_reg and flags reset too.",
    "programs": "the first difference in the trace shows the exact instruction where the cpu went wrong, start there.",
    "random": "the first difference in the trace shows the exact instruction where the cpu went wrong, start there.",
}

RESET_TESTS = [("fibonacci", 3), ("fibonacci", 9), ("factorial_loop", 5), ("gcd", 7), ("popcount", 11),
               ("sum_squares", 13), ("shift_add_multiply", 6), ("collatz", 17), ("forwarding", 8), ("branches", 10)]


def h(v):
    return f"0x{v:08x}"


def wrap(text, indent):
    return textwrap.fill(text, width=100, initial_indent="", subsequent_indent=" " * indent)


def load_programs():
    tests = []
    folder = os.path.join(HERE, "programs")
    for fname in sorted(os.listdir(folder)):
        if not fname.endswith(".s"):
            continue
        name = fname[:-2]
        source = open(os.path.join(folder, fname)).read()
        what, expect = [], {}
        for line in source.splitlines():
            m = re.match(r"@\s*what:\s*(.*)", line)
            if m:
                what.append(m.group(1))
                continue
            m = re.match(r"@\s*expect\s+(\S+)\s*=\s*(\S+)", line)
            if m:
                key = m.group(1).lower().replace("sp", "r14").replace("ra", "r15")
                key = re.sub(r"mem\[(\w+)\]", lambda mm: f"mem[{int(mm.group(1), 0)}]", key)
                expect[key] = int(m.group(2), 0) & 0xFFFFFFFF
                continue
            if line.startswith("@") and what and not line.startswith("@ expect"):
                what.append(line.lstrip("@ ").strip())
        tests.append({"group": "programs", "name": f"programs/{name}", "what": " ".join(what),
                      "source": source, "focus": [k for k in expect if k.startswith(("r", "mem"))],
                      "expect": expect, "file": os.path.relpath(os.path.join(folder, fname), ROOT)})
    return tests


def reset_tests(programs):
    by_name = {t["name"].split("/")[1]: t for t in programs}
    tests = []
    for name, cycle in RESET_TESTS:
        src = by_name[name]
        uses_memory = re.search(r"^\s*(\w+:)?\s*(ld|st)\b", src["source"], re.M) is not None
        mem_note = ("memory isn't cleared by reset, but this program stores before it loads so leftovers from the "
                    "first try don't change anything." if uses_memory else "this program doesn't touch memory.")
        tests.append({"group": "reset", "name": f"reset/{name}_at_{cycle}", "source": src["source"],
                      "what": (f"start {name}.s, then pull reset at cycle {cycle} while instructions are still in "
                               f"the pipeline. after reset the cpu should start over cleanly from pc 0 and end up "
                               f"exactly like a normal run. {mem_note}"),
                      "focus": src["focus"], "reset_at": cycle})
    return tests


def prepare(test):
    try:
        words = sr_asm.assemble(test["source"])
    except sr_asm.AsmError as e:
        test["broken"] = f"the test doesn't even assemble: {e}"
        return
    test["words"] = [w for w, _ in words]
    test["lines"] = [raw.strip() for _, raw in words]
    ref = refmodel.run(test["words"])
    test["ref"] = ref
    if not ref["halted"]:
        test["broken"] = "the reference model never reached the halt loop, so the test program itself is wrong"
        return
    test["cycles"] = ref["steps"] + ref["stalls"] + 2 * ref["flushes"] + FILL
    problems = []
    for key, want in test.get("expect", {}).items():
        if key == "stalls":
            got = ref["stalls"]
        elif key == "flushes":
            got = ref["flushes"]
        elif key.startswith("mem["):
            got = ref["mem"].get(int(key[4:-1]) >> 2, 0)
        else:
            got = ref["regs"][int(key[1:])]
        if got != want:
            problems.append(f"{key} is written as {h(want)} in the .s file but the reference model gets {h(got)}")
    if problems:
        test["broken"] = ("the expected values written in the test file don't agree with the reference model, so "
                          "either the test file or refmodel.py is wrong (this isn't about the cpu yet): "
                          + "; ".join(problems))


def parse_results(path):
    results = {}
    cur = None
    for line in open(path):
        parts = line.split()
        if not parts:
            continue
        kind = parts[0]
        if kind == "T":
            cur = {"events": [], "regs": [None] * 16, "mem": {}, "reset_seen": False}
            results[int(parts[1])] = cur
        elif kind == "X":
            cur["events"].append(("X", int(parts[1])))
            cur["reset_seen"] = True
        elif kind == "W":
            cur["events"].append(("W", int(parts[1]), parts[2], int(parts[3]), parts[4]))
        elif kind == "S":
            cur["events"].append(("S", int(parts[1]), parts[2], parts[3], parts[4]))
        elif kind == "L":
            cur["events"].append(("L", int(parts[1]), parts[2], parts[3]))
        elif kind == "F":
            cur["events"].append(("F", int(parts[1]), parts[2], parts[3]))
        elif kind == "E":
            cur["halted"], cur["cycles"], cur["stalls"], cur["flushes"] = (int(x) for x in parts[1:5])
        elif kind == "R":
            cur["regs"][int(parts[1])] = parts[2]
        elif kind == "M":
            cur["mem"][int(parts[1])] = parts[2]
    return results


def src_at(test, pc_text):
    try:
        i = int(pc_text, 16) // 4
    except ValueError:
        return "?"
    return test["lines"][i] if i < len(test["lines"]) else "(past the end of the program)"


def describe_event(test, e):
    if e[0] == "W":
        return f"r{e[3]:<2} <- 0x{e[4]}     pc {e[2][-4:]}  {src_at(test, e[2])}"
    if e[0] == "S":
        return f"stored 0x{e[4]} to mem[0x{e[3]}]     pc {e[2][-4:]}  {src_at(test, e[2])}"
    if e[0] == "L":
        return f"stall: the ld at {e[2][-4:]} isn't done yet, so the instruction at {e[3][-4:]} waits 1 cycle"
    if e[0] == "F":
        return f"branch taken at {e[2][-4:]}, going to {e[3][-4:]}. the 2 instructions fetched after it get flushed"
    return "reset pulled here. everything above this line happened before the reset"


def ref_event_text(test, e):
    if e[0] == "W":
        return f"r{e[2]} <- {h(e[3])} (pc {e[1]:04x}  {test['lines'][e[1] // 4]})"
    return f"stored {h(e[3])} to mem[{h(e[2])}] (pc {e[1]:04x}  {test['lines'][e[1] // 4]})"


def check(test, res):
    ref = test["ref"]
    checks = []
    focus = set(test["focus"])

    if not res["halted"]:
        checks.append((False, f"the cpu never got to the halt loop (b .) within {res['cycles']} cycles. it's probably "
                              "stuck in a loop or jumped somewhere it shouldn't", True))

    if test.get("reset_at") and not res["reset_seen"]:
        checks.append((False, "the reset never happened (the program finished before that cycle), so this test "
                              "didn't check anything. pick an earlier reset cycle", True))

    others_ok, others = True, 0
    for i in range(16):
        want = f"{ref['regs'][i]:08x}"
        got = res["regs"][i] or "????????"
        tag = f"r{i}" in focus
        if got != want:
            unknown = " (it has unknown x bits, something never got driven)" if "x" in got or "z" in got else ""
            checks.append((False, f"r{i} = 0x{got}, should be 0x{want}{unknown}", tag))
        elif tag:
            checks.append((True, f"r{i} = 0x{got}", True))
        else:
            others += 1
    if others:
        checks.append((True, f"the other {others} registers match too", False))

    want_mem = {i: f"{v:08x}" for i, v in ref["mem"].items()}
    mem_bad = []
    for i in sorted(set(want_mem) | set(res["mem"])):
        want = want_mem.get(i, "00000000")
        got = res["mem"].get(i, "00000000")
        if want != got:
            mem_bad.append(f"mem[{h(i * 4)}] = 0x{got}, should be 0x{want}")
    for k in sorted(focus):
        if k.startswith("mem["):
            addr = int(k[4:-1], 0)
            want = want_mem.get(addr >> 2, "00000000")
            got = res["mem"].get(addr >> 2, "00000000")
            if want == got:
                checks.append((True, f"mem[{h(addr)}] = 0x{got}", True))
    for line in mem_bad:
        checks.append((False, line, True))
    if not mem_bad:
        n = len(want_mem)
        checks.append((True, "memory matches (nothing was stored)" if n == 0 else
                       f"memory matches ({n} non-zero word{'s' if n != 1 else ''})", False))

    n_st, n_fl = ref["stalls"], ref["flushes"]
    expl = (f"{ref['steps']} instructions + {n_st} stall{'s' if n_st != 1 else ''} + 2 x {n_fl} "
            f"flush{'es' if n_fl != 1 else ''} + {FILL} to fill the pipeline")
    for what, got, want, note in (("stalls", res["stalls"], ref["stalls"], ""),
                                  ("flushes", res["flushes"], ref["flushes"], ""),
                                  ("cycles", res["cycles"], test["cycles"], f"   ({expl})")):
        if not res["halted"] and what == "cycles":
            continue
        if got == want:
            checks.append((True, f"{what:<7} = {got}{note}", False))
        else:
            checks.append((False, f"{what:<7} = {got}, should be {want}{note}", True))

    rtl = [e for e in res["events"]]
    if res["reset_seen"]:
        last = max(i for i, e in enumerate(rtl) if e[0] == "X")
        rtl = rtl[last + 1:]
    rtl = [e for e in rtl if e[0] in ("W", "S")]
    exp = [e for e in ref["trace"] if e[0] in ("W", "S")]
    first_diff = None
    for i in range(max(len(rtl), len(exp))):
        a = rtl[i] if i < len(rtl) else None
        b = exp[i] if i < len(exp) else None
        if a is None or b is None:
            first_diff = (i, a, b)
            break
        same = (a[0] == b[0] and int(a[2], 16) == b[1] and
                (a[3] == b[2] if a[0] == "W" else a[3] == f"{b[2]:08x}") and a[4] == f"{b[3]:08x}")
        if not same:
            first_diff = (i, a, b)
            break
    if first_diff is None:
        checks.append((True, f"every register write and store happened in the right order with the right value "
                             f"({len(exp)} of them)", False))
    else:
        i, a, b = first_diff
        if a is None:
            text = f"the cpu stopped writing too early. the next thing it should have done is {ref_event_text(test, b)}"
        elif b is None:
            text = f"the cpu did something extra at the end: cycle {a[1]}, {describe_event(test, a)}"
        else:
            text = (f"write number {i + 1} is different. at cycle {a[1]} the cpu did: {describe_event(test, a)}. "
                    f"it should have done: {ref_event_text(test, b)}")
        checks.append((False, text, True))
        test["first_diff"] = text
    return checks


def write_log(test, res, checks, path):
    out = []
    out.append(f"test      {test['name']}")
    out.append(f"group     {test['group']}")
    if test.get("file"):
        out.append(f"file      {test['file']}")
    out.append("what      " + wrap(test["what"], 10))
    out.append("")
    out.append("about this group: " + wrap(ABOUT[test["group"]], 18))
    out.append("")

    if "lines" in test:
        out.append(f"the program ({len(test['words'])} instructions)")
        for i, (w, line) in enumerate(zip(test["words"], test["lines"])):
            out.append(f"  {i * 4:04x}  {w:08x}   {line}")
        out.append("")

    if test.get("broken"):
        out.append("this test is broken, so the cpu wasn't run on it:")
        out.append("  " + wrap(test["broken"], 2))
        out.append("")
        out.append("BROKEN TEST")
    else:
        out.append("what the cpu did (register writes, stores, stalls and flushes, in order)")
        out.append("  (a write shows up when its instruction finishes in RW. stalls and branches show up when they")
        out.append("  happen in EX, so they can come a couple of lines before writes from older instructions)")
        events = res["events"]
        for e in events[:300]:
            out.append(f"  cycle {e[1]:>5}   {describe_event(test, e)}")
        if len(events) > 300:
            out.append(f"  ... and {len(events) - 300} more")
        if not events:
            out.append("  nothing (no register writes or stores at all)")
        out.append("")

        out.append("checks")
        for ok, text, important in checks:
            mark = "ok   " if ok else "WRONG"
            tail = "   <- this is what the test is about" if important and ok else ""
            out.append(f"  {mark}  {wrap(text, 9)}{tail}")
        for key, want in test.get("expect", {}).items():
            out.append(f"  (the program file also says {key} = {h(want)}, and the reference model agrees)")
        out.append("")

        bad = [t for ok, t, _ in checks if not ok]
        if not bad:
            out.append("PASS")
        else:
            out.append(f"FAIL  ({len(bad)} check{'s' if len(bad) > 1 else ''} didn't match)")
            out.append("")
            out.append("what went wrong: " + wrap(bad[0], 17))
            if test.get("first_diff") and test["first_diff"] != bad[0]:
                out.append("first place the cpu went off track: " + wrap(test["first_diff"], 36))
            out.append("where to look: " + wrap(WHERE[test["group"]], 15))

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")


def main():
    ap = argparse.ArgumentParser(description="runs the cpu integration tests and writes a log for every test")
    ap.add_argument("--seed", type=int, default=1, help="seed for the generated tests (default 1)")
    ap.add_argument("--only", default="", help="only run tests whose name contains this text")
    ap.add_argument("--show", type=int, default=3, help="print the logs of the first N failures (default 3)")
    args = ap.parse_args()

    start = time.time()
    print(f"cpu integration tests (seed {args.seed})")

    programs = load_programs()
    tests = gen_tests.generate(args.seed) + programs + reset_tests(programs)
    tests.sort(key=lambda t: GROUP_ORDER.index(t["group"]))
    if args.only:
        tests = [t for t in tests if args.only in t["name"]]
    names = [t["name"] for t in tests]
    if len(names) != len(set(names)):
        dupes = sorted({n for n in names if names.count(n) > 1})
        sys.exit(f"two tests have the same name: {', '.join(dupes)}")
    if not tests:
        sys.exit("no tests match that filter")

    shutil.rmtree(os.path.join(BUILD, "logs"), ignore_errors=True)
    shutil.rmtree(os.path.join(BUILD, "hex"), ignore_errors=True)
    os.makedirs(os.path.join(BUILD, "hex"))

    print(f"  making {len(tests)} tests and working out what each one should do ... ", end="", flush=True)
    runnable = []
    for t in tests:
        prepare(t)
        if not t.get("broken"):
            runnable.append(t)
    with open(os.path.join(BUILD, "tests.list"), "w") as lst:
        for i, t in enumerate(runnable):
            hexpath = os.path.join(BUILD, "hex", t["name"].replace("/", "__") + ".hex")
            with open(hexpath, "w") as f:
                f.write("".join(f"{w:08x}\n" for w in t["words"]))
            lst.write(f"{hexpath} {t['cycles'] * 2 + 200} {t.get('reset_at', 0)}\n")
            t["index"] = i
    print("done")

    print("  compiling the cpu and the testbench ... ", end="", flush=True)
    rtl = sorted(f"{d}/{f}" for d in ("khushwant", "magizhnan", "shared") for f in os.listdir(os.path.join(ROOT, d))
                 if f.endswith(".v"))
    vvp = os.path.join(BUILD, "tb_integration.vvp")
    cmd = ["iverilog", "-g2005", "-I", "shared", "-s", "tb_integration", "-o", vvp] + rtl + \
          ["tests/integration/tb_integration.v"]
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if r.returncode != 0:
        print("failed\n" + r.stdout + r.stderr)
        sys.exit(1)
    print("done")

    print(f"  running all {len(runnable)} tests in one simulation ... ", end="", flush=True)
    t0 = time.time()
    results_path = os.path.join(BUILD, "results.txt")
    r = subprocess.run(["vvp", "-n", vvp, f"+list={os.path.join(BUILD, 'tests.list')}", f"+out={results_path}"],
                       cwd=ROOT, capture_output=True, text=True)
    with open(os.path.join(BUILD, "simulator.log"), "w") as f:
        f.write(r.stdout + r.stderr)
    results = parse_results(results_path)
    print(f"done ({time.time() - t0:.1f} s)")

    rows = []
    for t in tests:
        log = os.path.join(BUILD, "logs", t["name"] + ".log")
        if t.get("broken"):
            status, reason, checks, res = "BROKEN", t["broken"], [], None
        else:
            res = results.get(t["index"])
            if res is None:
                status, reason, checks = "FAIL", "the simulation never got to this test (it crashed or stopped early, see simulator.log)", []
                res = {"events": [], "halted": 0, "cycles": 0, "stalls": 0, "flushes": 0, "regs": [None] * 16,
                       "mem": {}, "reset_seen": False}
            else:
                checks = check(t, res)
                bad = [text for ok, text, _ in checks if not ok]
                status, reason = ("PASS", "") if not bad else ("FAIL", bad[0])
        write_log(t, res, checks, log)
        rows.append((t, status, reason, res, log))

    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    total = len(rows)
    passed = sum(1 for r in rows if r[1] == "PASS")
    failed = total - passed

    summary = [f"cpu integration tests, {stamp}, seed {args.seed}", ""]
    summary.append(f"{'group':<14}{'tests':>7}{'passed':>9}{'failed':>9}")
    for g in GROUP_ORDER:
        gr = [r for r in rows if r[0]["group"] == g]
        if gr:
            gp = sum(1 for r in gr if r[1] == "PASS")
            summary.append(f"{g:<14}{len(gr):>7}{gp:>9}{len(gr) - gp:>9}")
    summary.append(f"{'total':<14}{total:>7}{passed:>9}{failed:>9}")
    summary.append("")
    if failed == 0:
        summary.append(f"all {total} tests passed")
    else:
        summary.append(f"{failed} test{'s' if failed > 1 else ''} failed:")
        for t, status, reason, _, log in rows:
            if status != "PASS":
                summary.append(f"  {status:<6} {t['name']}")
                summary.append(f"         {wrap(reason, 9)}")
                summary.append(f"         log: {os.path.relpath(log, ROOT)}")

    with open(os.path.join(BUILD, "summary.log"), "w") as f:
        f.write("\n".join(summary) + "\n")
    with open(os.path.join(BUILD, "results.csv"), "w") as f:
        f.write("test,group,status,cycles,stalls,flushes,reason\n")
        for t, status, reason, res, _ in rows:
            r_ = res or {}
            reason_csv = reason.replace('"', "'")
            f.write(f"{t['name']},{t['group']},{status},{r_.get('cycles', '')},{r_.get('stalls', '')},"
                    f"{r_.get('flushes', '')},\"{reason_csv}\"\n")
    with open(os.path.join(BUILD, "history.log"), "a") as f:
        f.write(f"{stamp}  seed {args.seed}  {total} tests  {passed} passed  {failed} failed"
                f"{'  (only ' + args.only + ')' if args.only else ''}\n")

    print()
    print("\n".join(summary[2:]))
    print()
    rel = os.path.relpath(BUILD, ROOT)
    print(f"logs:     {rel}/logs/<group>/<test>.log  (one per test)")
    print(f"summary:  {rel}/summary.log")
    print(f"results:  {rel}/results.csv")
    print(f"history:  {rel}/history.log")
    print(f"took {time.time() - start:.1f} s")

    shown = 0
    for t, status, _, _, log in rows:
        if status != "PASS" and shown < args.show:
            print("\n" + "=" * 100)
            print(open(log).read())
            shown += 1
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()

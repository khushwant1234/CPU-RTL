#!/usr/bin/env bash
#
# Compiles and runs every testbench under tb/ with Icarus Verilog and
# prints a pass/fail summary. Compiled with -g2005, so everything has to be
# plain Verilog (no SystemVerilog).
#
#   ./run_tests.sh              run everything
#   ./run_tests.sh magirman     only testbenches whose path contains "magirman"
#   ./run_tests.sh tb_alu -v    verbose: show the full simulator output
#
set -u
cd "$(dirname "$0")"

FILTER="${1:-}"
VERBOSE=0
[[ "${2:-}" == "-v" || "${1:-}" == "-v" ]] && VERBOSE=1
[[ "$FILTER" == "-v" ]] && FILTER=""

BUILD=build
mkdir -p "$BUILD"

# re-assemble the test programs so edits to programs/*.s are always picked up
for s in programs/*.s; do
  python3 tools/sr_asm.py "$s" || { echo "  assembler failed on $s"; exit 1; }
done
rm -rf tools/__pycache__

# all RTL (plain Verilog, shared defines come from rtl/common/defines.vh)
RTL=($(ls rtl/magirman/*.v rtl/khushwant/*.v rtl/shared/*.v 2>/dev/null))

pass=0; fail=0; failed=()

for tb in $(ls tb/magirman/tb_*.v tb/khushwant/tb_*.v tb/shared/tb_*.v 2>/dev/null); do
  [[ -n "$FILTER" && "$tb" != *"$FILTER"* ]] && continue
  top=$(basename "$tb" .v)
  out="$BUILD/$top.vvp"
  log="$BUILD/$top.log"

  if ! iverilog -g2005 -Wall -Wno-timescale -I rtl/common -I tb/common -s "$top" -o "$out" "${RTL[@]}" "$tb" > "$log" 2>&1; then
    printf "  %-28s COMPILE ERROR\n" "$top"
    cat "$log"
    fail=$((fail+1)); failed+=("$top"); continue
  fi

  vvp -n "$out" >> "$log" 2>&1
  [[ $VERBOSE -eq 1 ]] && cat "$log"

  checks=$(grep -Eo '^  [0-9]+ checks' "$log" | grep -Eo '[0-9]+' | tail -1)
  if grep -q "TB_RESULT: PASS" "$log"; then
    printf "  %-28s PASS  (%s checks)\n" "$top" "${checks:-?}"
    pass=$((pass+1))
  else
    printf "  %-28s FAIL\n" "$top"
    grep -E "FAIL|ERROR|error" "$log" | head -20
    fail=$((fail+1)); failed+=("$top")
  fi
done

echo
echo "  $pass passed, $fail failed"
[[ $fail -eq 0 ]] || { echo "  failed: ${failed[*]}"; exit 1; }

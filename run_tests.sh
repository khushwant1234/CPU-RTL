#!/usr/bin/env bash
#
# Compiles and runs every testbench under tb/ with Icarus Verilog and
# prints a pass/fail summary.
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

# package first, then all RTL
RTL=(rtl/common/simpleriscprocessor_pkg.sv $(ls rtl/magirman/*.sv rtl/khushwant/*.sv rtl/shared/*.sv 2>/dev/null))

pass=0; fail=0; failed=()

for tb in $(ls tb/magirman/tb_*.sv tb/khushwant/tb_*.sv tb/shared/tb_*.sv 2>/dev/null); do
  [[ -n "$FILTER" && "$tb" != *"$FILTER"* ]] && continue
  top=$(basename "$tb" .sv)
  out="$BUILD/$top.vvp"
  log="$BUILD/$top.log"

  if ! iverilog -g2012 -Wall -Wno-timescale -I tb/common -s "$top" -o "$out" "${RTL[@]}" "$tb" > "$log" 2>&1; then
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

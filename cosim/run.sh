#!/bin/bash
#
# usage: cosim/run.sh [random_programs] [seed] [vectors_per_module]

cd "$(dirname "$0")/.." || exit 1

PROGRAMS=${1:-2000}
SEED=${2:-1}
VECTORS=${3:-50000}

BUILD=build/cosim
RTL="khushwant/*.v magizhnan/*.v shared/*.v"
MODULES="decoder alu branch_unit execute_stage forwarding_unit hazard_unit writeback reg_file"

mkdir -p $BUILD/progs
rm -f $BUILD/progs/*

g++ -std=c++17 -O2 -Wall -o $BUILD/cosim cosim/model/main.cpp || exit 1

fail=0

echo "module co-simulation ($VECTORS random vectors per module, seed $SEED)"
for m in $MODULES; do
    $BUILD/cosim gen $m $VECTORS $SEED > $BUILD/$m.vec
    $BUILD/cosim model $m < $BUILD/$m.vec > $BUILD/$m.model
    if ! iverilog -g2005 -I shared -s tb_${m}_cosim -o $BUILD/$m.vvp $RTL cosim/tb/tb_${m}_cosim.v; then
        fail=1
        continue
    fi
    (cd $BUILD && vvp -n $m.vvp > /dev/null)
    $BUILD/cosim compare $m $BUILD/$m.model $BUILD/$m.rtl || fail=1
done

echo
total=$($BUILD/cosim programs $BUILD/progs $PROGRAMS $SEED)
pairs=$((total - PROGRAMS))
echo "cpu co-simulation ($pairs directed pair programs + $PROGRAMS random programs, seed $SEED)"
$BUILD/cosim iss $BUILD/progs $total > $BUILD/cpu.model 2> $BUILD/coverage.txt
iverilog -g2005 -I shared -s tb_cpu_cosim -o $BUILD/cpu.vvp $RTL cosim/tb/tb_cpu_cosim.v || exit 1
(cd $BUILD && vvp -n cpu.vvp +n=$total) > $BUILD/cpu_stats.txt
if ! $BUILD/cosim compare cpu $BUILD/cpu.model $BUILD/cpu.rtl; then
    fail=1
    echo "    program listings: $BUILD/progs/prog_<n>.s"
fi

stats=$(grep "^cycles=" $BUILD/cpu_stats.txt)
instructions=$(grep "instructions executed" $BUILD/coverage.txt | awk '{print $4}')
eval "$(echo "$stats" | tr ' ' '\n')"
echo
echo "pipeline activity (RTL)"
echo "  cycles                : $cycles"
echo "  load-use stalls       : $stalls"
echo "  taken branch flushes  : $flushes"
echo "  forwards from EX/MEM  : $fwd_exmem"
echo "  forwards from MEM/WB  : $fwd_memwb"
awk -v c="$cycles" -v i="$instructions" 'BEGIN { if (i > 0) printf "  CPI                   : %.2f (includes pipeline fill per program)\n", c / i }'
echo
echo "coverage (instruction set simulator)"
cat $BUILD/coverage.txt

load_use=$(grep "load-use pairs" $BUILD/coverage.txt | awk '{print $4}')
taken=$(grep "branches" $BUILD/coverage.txt | awk '{print $3}')
echo
echo "pipeline cross-checks"
if [ "$stalls" = "$load_use" ]; then
    echo "  stalls == load-use pairs in the program ($stalls)   PASS"
else
    echo "  stalls ($stalls) != load-use pairs in the program ($load_use)   FAIL"
    fail=1
fi
if [ "$flushes" = "$taken" ]; then
    echo "  flushes == taken branches ($flushes)   PASS"
else
    echo "  flushes ($flushes) != taken branches ($taken)   FAIL"
    fail=1
fi

echo
if [ $fail -eq 0 ]; then
    echo "ALL PASS"
else
    echo "FAILURES FOUND"
    exit 1
fi

//=============================================================================
// tb_check.svh
// Small self-checking helpers shared by every testbench.
//
// Usage inside a testbench module:
//   `include "tb_check.svh"
//   `TB_INIT
//   ...
//   `CHECK_EQ(dut_output, expected, "what is being checked")
//   ...
//   `TB_FINISH
//
// Every testbench prints exactly one "TB_RESULT: PASS" or "TB_RESULT: FAIL"
// line at the end, which run_tests.sh greps for.
//=============================================================================
`ifndef TB_CHECK_SVH
`define TB_CHECK_SVH

`define TB_INIT \
  int tb_errors = 0; \
  int tb_checks = 0;

// Uses !== so X/Z on the DUT output counts as a failure.
`define CHECK_EQ(ACT_, EXP_, MSG_) \
  begin \
    tb_checks = tb_checks + 1; \
    if ((ACT_) !== (EXP_)) begin \
      tb_errors = tb_errors + 1; \
      $display("  [FAIL] %s : got 0x%0h, expected 0x%0h  (t=%0t)", MSG_, (ACT_), (EXP_), $time); \
    end \
  end

`define CHECK_TRUE(COND_, MSG_) \
  begin \
    tb_checks = tb_checks + 1; \
    if ((COND_) !== 1'b1) begin \
      tb_errors = tb_errors + 1; \
      $display("  [FAIL] %s  (t=%0t)", MSG_, $time); \
    end \
  end

`define TB_FINISH \
  begin \
    $display("  %0d checks, %0d errors", tb_checks, tb_errors); \
    if (tb_errors == 0) $display("TB_RESULT: PASS"); \
    else                $display("TB_RESULT: FAIL"); \
    $finish; \
  end

`endif

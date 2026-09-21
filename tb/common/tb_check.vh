//=============================================================================
// tb_check.vh
// Small self-checking helpers shared by every testbench.
//
// Usage:
//   `include "tb_check.vh"       (above the module)
//   module tb_x;
//     `TB_INIT
//     ...
//     `CHECK_EQ(dut_output, expected, "what is being checked")
//     `CHECK_EQ_I(dut_output, expected, "checked in a loop", i)
//     ...
//     `TB_FINISH
//
// Every testbench prints exactly one "TB_RESULT: PASS" or "TB_RESULT: FAIL"
// line at the end, which run_tests.sh greps for.
//=============================================================================
`ifndef TB_CHECK_VH
`define TB_CHECK_VH

`define TB_INIT \
  integer tb_errors = 0; \
  integer tb_checks = 0;

// Uses !== so X/Z on the DUT output counts as a failure.
`define CHECK_EQ(ACT_, EXP_, MSG_) \
  begin \
    tb_checks = tb_checks + 1; \
    if ((ACT_) !== (EXP_)) begin \
      tb_errors = tb_errors + 1; \
      $display("  [FAIL] %0s : got 0x%0h, expected 0x%0h  (t=%0t)", MSG_, (ACT_), (EXP_), $time); \
    end \
  end

// same, with a loop index printed next to the message
`define CHECK_EQ_I(ACT_, EXP_, MSG_, IDX_) \
  begin \
    tb_checks = tb_checks + 1; \
    if ((ACT_) !== (EXP_)) begin \
      tb_errors = tb_errors + 1; \
      $display("  [FAIL] %0s [%0d] : got 0x%0h, expected 0x%0h  (t=%0t)", MSG_, (IDX_), (ACT_), (EXP_), $time); \
    end \
  end

`define CHECK_TRUE(COND_, MSG_) \
  begin \
    tb_checks = tb_checks + 1; \
    if ((COND_) !== 1'b1) begin \
      tb_errors = tb_errors + 1; \
      $display("  [FAIL] %0s  (t=%0t)", MSG_, $time); \
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

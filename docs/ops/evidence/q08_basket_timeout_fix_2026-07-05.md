# Q08 Basket EA Baseline Timeout & Path-Mismatch Diagnosis
**Date:** 2026-07-05  
**EA:** QM5_12772 edgelab-gbpjpy-audjpy-cointegration  
**Task:** 45ec67a7-4b09-4600-83cd-4773ef419906  
**Agent:** Claude  

## Symptom

QM5_12772 failed Q08 five times with INVALID/n_trades=0. The 2026-07-04 09:42
recompile (BASKET_OK) did not fix it. The task assigned root cause as basket stream path
mismatch.

## Actual Root Causes Found

### Root Cause 1 (Blocking): Baseline Timeout

The Q08 aggregator runs a fresh full-history baseline via `run_smoke.ps1` to capture the
EA's TRADE_CLOSED stream. For this 2-leg basket EA running on the **physical host symbol
GBPJPY.DWX** (required because the logical composite `QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1`
is not in the target terminal's market watch), MetaTrader 5 loads real-tick (Model 4)
data for **both GBPJPY.DWX and AUDJPY.DWX** over 2017–2025. This is ~58M ticks × 2
symbols and consistently exceeds the 2400-second run budget:

```
summary.json (20260705_050028):
  "result": "FAIL",
  "reason_classes": ["TIMEOUT", "METATESTER_HUNG", "INCOMPLETE_RUNS", ...]
  "runs[0].failure": "Tester run timed out after 2400 seconds"
```

This was the failure mode on the LATEST run (using host symbol). Earlier runs (082145,
111749, 193252, 215907) failed differently — the logical symbol was passed and rejected
with "symbol QM5_12772_GBPJPY_AUDJPY_COINTEG not exist" in T1's market watch.

### Root Cause 2 (Secondary — Already Fixed): Stream Path Mismatch

`QM_Common.mqh` writes the TRADE_CLOSED stream using `_Symbol` (the physical chart
symbol at test time), not the logical work-item symbol:

```mql5
string q08_sym = _Symbol;    // e.g. "GBPJPY.DWX"
StringReplace(q08_sym, ".", "_");
const string q08_path = StringFormat("QM\\q08_trades\\%d_%s.jsonl", g_qm_fw_ea_id, q08_sym);
```

This wrote to `12772_GBPJPY_DWX.jsonl`. The aggregator read from
`12772_QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1.jsonl` — a permanent mismatch.

**Status:** Already fixed in commits `977a31a2b` (host_symbol setfile extraction) and
`46465c162` (host-sym log fallback in run_all). The aggregator now detects basket EAs
via `_host_symbol_from_setfile()` and falls back to the host-symbol path after the baseline.

## Fix Applied

**`framework/scripts/q08_davey/aggregate.py`** — `_run_baseline_for_trades()`:

- Detect basket EAs (`test_symbol != symbol`) and raise timeout from 2400 s → 5400 s
  (subprocess budget: 5520 s)
- Return `test_symbol` in the result dict for diagnostics

**`tools/strategy_farm/farmctl.py`** — `PHASE_TIMEOUT_MINUTES`:

- Q08: 30 min → 120 min. Comment updated to reflect that basket EAs need ~90 min for the
  baseline. Prior comment ("reads log; cheap") assumed no baseline backtest, which is only
  true for already-warm EAs.

## Requeue Status

`farmctl.py enqueue-backtest --ea QM5_12772 --phase Q08` confirmed work_item
`68dc6e09-d39c-4cd5-bfb9-9dbd4cea7054` is already `status=pending` (the factory
reset it automatically after INFRA_FAIL verdict). The pump will dispatch it with
the next tick.

## Business Context

QM5_12772 is a rank-23 tail candidate with **negative OOS Sharpe (-0.1777)** from the
66-pair FX cointegration scan. It passed Q02–Q07 on gross metrics. The Q08 fix is
infrastructure-correct but OWNER should expect this EA to FAIL the statistical battery
on merit: the card's own risk profile notes "very high risk" and PF ≈ 0.98 expected.
No additional resource allocation is recommended beyond one clean Q08 run.

## Evidence Files

- `D:/QM/reports/work_items/68dc6e09-d39c-4cd5-bfb9-9dbd4cea7054/QM5_12772/Q08/QM5_12772_GBPJPY_AUDJPY_COINTEGRATION_D1/aggregate.json` — INVALID verdict confirming 0 trades
- `D:/QM/reports/pipeline/QM5_12772/Q08/_baseline/QM5_12772/20260705_050028/summary.json` — TIMEOUT proof
- `framework/scripts/q08_davey/aggregate.py` — fix (this commit)
- `tools/strategy_farm/farmctl.py` — Q08 phase timeout (this commit)

---
ea_id: QM5_2011
slug: nnfx-v2-h4-bias-h1-breakout
artifact_type: zero_trade_rework_critique
trigger: DL-062_zero_trade_rework_trigger
router_task_id: a11eec69-380e-4333-a182-0423b2d83382
parent_card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_2011_nnfx-v2-h4-bias-h1-breakout.md
author: claude
written_at: 2026-05-23
verdict: REWORK_BUILD_DEFECT_REPORT_PARSE_ERROR_ZERO_TRADE_VERDICT_INVALID
---

# QM5_2011 nnfx-v2-h4-bias-h1-breakout — zero-trade rework critique

Router fired DL-062 on `completed=74 / fail=10 / zero_trade=10 (zt_pct=1.0)`.
After reading the evidence files, the dominant failure mode is **REPORT_PARSE_ERROR**
on both deterministic runs — a build-side defect that produces malformed HTML reports
and 0-trade output regardless of strategy behaviour. The zero-trade verdict is
structurally invalid because the tester ran to completion but the result-harvester
could not parse the report file.

## 1. Evidence sample (work_items)

| symbol       | status  | verdict  | notes                              |
|--------------|---------|----------|------------------------------------|
| EURUSD.DWX   | done    | FAIL     | in-target, REPORT_PARSE_ERROR×2    |
| GBPUSD.DWX   | done    | FAIL     | in-target, REPORT_PARSE_ERROR×2    |
| USDJPY.DWX   | done    | FAIL     | in-target, REPORT_PARSE_ERROR×2    |
| XAUUSD.DWX   | failed  | INVALID  | in-target, never produced done run |
| 64× FX/CFD  | failed  | INVALID  | dispatcher fan-out (OOU mostly)    |

COUNTS: done/FAIL=10, failed/INVALID=64.

## 2. Root cause (dominant): REPORT_PARSE_ERROR on in-universe symbols

Inspection of `summary.json` for the EURUSD.DWX done/FAIL run
(`D:\QM\reports\work_items\4ed0ff91...\QM5_2011\20260522_034741\summary.json`):

```json
{
  "result": "FAIL",
  "reason_classes": ["INVALID_REPORT", "INCOMPLETE_RUNS"],
  "deterministic": false,
  "oninit_failure_detected": false,
  "model4_log_marker_detected": true,
  "runs": [
    { "run": "run_01", "status": "INVALID", "failure": "INVALID_REPORT",
      "invalid_report_reasons": ["REPORT_PARSE_ERROR"],
      "total_trades": 0, "report_size_bytes": 22330 },
    { "run": "run_02", "status": "INVALID", "failure": "INVALID_REPORT",
      "invalid_report_reasons": ["REPORT_PARSE_ERROR"],
      "total_trades": 0, "report_size_bytes": 22330 }
  ]
}
```

Critical observations:
1. **Both deterministic runs fail with REPORT_PARSE_ERROR** — the MT5 strategy tester
   generated a 22KB HTML report file for each run, but the report parser cannot extract
   the results from it. `total_trades=0` in the harvester output is the default on
   parse failure, not a verified trade count from the strategy.

2. **`deterministic: false`** — the two tester runs produced different internal states
   (or at minimum the parser cannot confirm they agree). This is a strong indicator
   that the EA has non-deterministic behavior (print buffer, random seed, or
   uninitialized variable) OR the multi-timeframe data loading produces different
   H4 bar counts between runs.

3. **`oninit_failure_detected: false`** — the EA initialized successfully on H1 bars.
   The issue is NOT a crash at startup; it is during the run or at report-generation
   time.

4. **`model4_log_marker_detected: true`** — real-tick model 4 ran. The EA was
   executing; the report harvesting failed.

5. **Report size 22,330 bytes for both runs** — a normal MT5 tester HTML report for
   a real-tick run with 0 trades is typically 6–8 KB. A 22KB report with `total_trades=0`
   suggests the EA produced excessive `Print()` output that was embedded in the
   report body, causing the HTML table structure to be unparseable by the regex-based
   harvester.

### Likely cause: excessive Print() output from NNFX logging

NNFX V2 implementations frequently include verbose console logging (H4 bias state,
compression check per bar, Donchian levels, RSI value, entry signal). If the EA
logs one or more `Print()` statements per H1 bar, a 2024 H1 backtest (≈6,000 bars)
would produce 6,000–30,000 log lines embedded in the report. This causes:
- The HTML report to exceed the parser's table expectations
- `deterministic: false` (log timestamps or non-deterministic internal timers)
- `REPORT_PARSE_ERROR` on both runs

### Systemic nature of the INVALID rate (64/74 = 87%)

The 64 `failed/INVALID` rows (vs 10 `done/FAIL`) are separate from the REPORT_PARSE_ERROR
issue. The initial mass fan-out (64 symbols, 2026-05-21T03:39Z) produced INVALID on
all first attempts, including in-universe symbols. GBPUSD, USDJPY eventually got
`done/FAIL` on retry; XAUUSD never produced a clean done run.

The INVALID pattern on first attempts likely has a different cause — possibly a
H4 data warm-up issue on the first terminal-worker assignment after a cold start.
The retries on EURUSD/GBPUSD/USDJPY succeeded (in the sense of reaching FAIL
state), but still with REPORT_PARSE_ERROR.

## 3. Secondary: dispatcher universe mismatch

Card `target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]` — 4 symbols.
P2 dispatch fanned to 74 total runs across the full DWX universe (~36+ symbols).
70 runs are out-of-universe. Same dispatcher bug as QM5_1088 / QM5_1089 / QM5_1096
(memory `project_qm_dispatcher_universe_mismatch_2026-05-23`).

This is secondary to the build defect but must be fixed to get clean in-universe
results regardless.

## 4. Why the DL-062 trigger fired

The classifier receives `done/FAIL` with `total_trades=0` and classifies it as
zero-trade failure. It cannot distinguish between:
- "strategy produced 0 trades" (strategy mortality)
- "report parser returned 0 as the default on PARSE_ERROR" (build defect)

For QM5_2011, all `done/FAIL` rows with `total_trades=0` are the second case.
**The zero-trade verdict is not a valid measurement of strategy behaviour.**

## 5. Recommended change vector

Reject the router hint to relax entry conditions or substitute signal logic —
the zero-trade evidence is invalid. Required actions, in order:

1. **Fix the build (codex)**: remove or gate the excessive `Print()` logging in
   QM5_2011_nnfx-v2-h4-bias-h1-breakout. Replace per-bar logging with `Comment()`
   (does not embed in report) or conditionally gate on `#ifdef _DEBUG`. Verify that
   after rebuild, both deterministic H1 runs on EURUSD.DWX produce `deterministic: true`
   and a parseable report with `total_trades > 0`.

2. **Verify build output**: after the fix, run a single P2 seed on EURUSD.DWX H1
   with `min_trades_required=1` and inspect the summary.json. Confirm:
   - `deterministic: true`
   - `reason_classes` does NOT include `INVALID_REPORT`
   - `total_trades > 0`

3. **Ops (codex)**: honor `target_symbols` from card frontmatter. Restrict P2
   enqueue to the 4 declared symbols (EURUSD, GBPUSD, USDJPY, XAUUSD).

4. **Re-enqueue after fix**: P2 on all 4 target symbols, H1, H4 bias data will be
   loaded via `iBarShift()` or `CopyRates()` from within the EA. Year=2024, then
   extend to 3–5y if trades are produced. `min_trades_required` = `70 × 1 × 0.5 = 35`
   for a 1-year baseline.

5. **Edge Lab compliance**: card (created 2026-05-20) pre-dates the 2026-05-22
   charter but has full G0/R1-R4 PASS already. News blackout: not explicitly in the
   card — the V5 default high-impact skip must be confirmed. No martingale/grid.
   `RISK_PERCENT` not set in the card — add it. `RISK_FIXED = 1000` for P2 baseline.

6. **Do NOT mark DEAD.** The H4+H1 NNFX V2 thesis has R1 PASS (published NNFX
   framework). The zero-trade result is a measurement artifact, not an edge verdict.

## 6. Falsification

If, after the Print() fix and valid P2 re-run on the 4 target symbols, the EA still
produces 0 trades on all 4 symbols with `deterministic: true` confirmed, then the
critique is wrong and the multi-confirmation filter stack (H4 EMA100 + MACD + SSL
triple-confirm + H1 ATR compression + H1 Donchian breakout + RSI(14)) is too
restrictive to fire on any 2024 H1 bar across EURUSD/GBPUSD/USDJPY/XAUUSD. That
would be a legitimate strategy-design issue (confirm-stack over-filtering) and
would warrant relaxing one layer (e.g., removing SSL from the H4 bias requirement)
as a separate dedicated variant — but only after the build defect is ruled out.

## 7. Verification I ran

- Card at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_2011_nnfx-v2-h4-bias-h1-breakout.md`
  — confirmed 4-symbol target, H4 bias + H1 entry, R1-R4 all PASS, `expected_trades=70/yr`.
- EA build confirmed: `D:\QM\mt5\T1\MQL5\Experts\QM\QM5_2011_nnfx-v2-h4-bias-h1-breakout.ex5`
  (built 2026-05-20).
- Direct sqlite: 74 P2 rows total: 10 done/FAIL, 64 failed/INVALID.
- Inspected `summary.json` for EURUSD.DWX done/FAIL run: REPORT_PARSE_ERROR×2,
  deterministic=false, report_size=22,330 bytes (abnormally large), oninit_failure=false.
- Memory: `project_qm_dispatcher_universe_mismatch_2026-05-23`.

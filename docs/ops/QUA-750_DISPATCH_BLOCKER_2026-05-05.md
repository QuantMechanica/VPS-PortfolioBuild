# QUA-750 Dispatch Blocker — QM5_1017 missing setfile matrix

timestamp_utc: 2026-05-05T20:07:00Z
issue: QUA-750
ea_id: QM5_1017
priority: critical
owner: Pipeline-Operator

## What was verified

- DL-054 G4 zero-trade ADR prerequisite is satisfied for QM5_1017:
  - `decisions/*_zero_trade_QM5_1017_<SYMBOL>.md` present for canonical 36-symbol matrix.
- Dispatch preflight command:
  - `python framework/scripts/p2_baseline.py --ea QM5_1017 --dry-run`
- Result:
  - `[FATAL] no sets dir: C:\QM\repo\framework\EAs\QM5_1017_chan_pairs_stat_arb\sets`

## Blocker classification

- Status: BLOCKED
- Blocking layer: EA packaging / setfile matrix
- Root blocker: required `sets/` directory and per-symbol backtest setfiles are absent.

## Unblock owner + action

- **Unblock owner:** CTO (EA packaging authority) with Development support.
- **Required action:**
  1. Create `framework/EAs/QM5_1017_chan_pairs_stat_arb/sets/`.
  2. Add symbol-period setfiles required by the intended smoke/baseline entrypoint (minimum smoke symbol + period, or full matrix if promoting to P2).
  3. Confirm Card §7/§12 two-slot-per-pair registry convention closure in:
     `framework/EAs/QM5_1017_chan_pairs_stat_arb/CHECKLIST.md`.

## Next operator action after unblock

- Re-run dry-run preflight.
- If clean, execute smoke dispatch under DL-054 and record `ZERO_TRADE` outcomes (not `PASS`) per row.

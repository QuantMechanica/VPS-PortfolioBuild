# QT Finding: QM5_1004 Zero Trades — OnInit Failure (EA_MAGIC_NOT_REGISTERED)

**Date:** 2026-05-06
**QT Agent:** c1f90ba8
**Status:** QT WATCHDOG FINDING — CTO/Pipeline-Op action required
**Evidence:** `D:/QM/reports/pipeline/QM5_1004/P2/QM5_1004/20260506_002627/raw/run_01/20260506.log`

---

## Root Cause

All QM5_1004 smoke P1 runs produce 0 trades because the EA fails OnInit. The tester log for the
latest clean USDJPY H1 run (20260506_002627) contains:

```
Core 01   breakout_lookback=20
Core 01   strategy_atr_period=14
Core 01   atr_stop_mult=2.0
Core 01   EA_MAGIC_NOT_REGISTERED: ea_id=1004 slot=0 magic=10040000
Core 01   tester stopped because OnInit returns non-zero code 1
```

`QM_FrameworkInit()` validates the magic registry at startup. If `ea_id=1004` is not present in the
`magic_numbers.csv` as seen by the framework on the tester terminal, `OnInit` returns `INIT_FAILED` (1).
The backtest then runs 0 bars → 0 trades. The tester reports the run as complete with
`model4_log_marker_detected=true` (the EA was loaded), but there is no actual trading.

This affects ALL 36 symbols — the OnInit failure is not symbol-specific.

---

## Evidence Pattern

| Symptom | Observed |
|---|---|
| All 36 symbols: 0 trades | ✓ |
| `deterministic=True` | ✓ (consistent OnInit failure) |
| `model4_log_marker_detected=True` | ✓ (EA loaded, not missing ex5) |
| `total_trades=0` both runs | ✓ |
| p2_result: `PASS=0, FAIL=36` | ✓ |

---

## Distinguished from QM5_1009

QM5_1009 (SRC04_S03) zero trades = strategy-parameter issue (order_expiration_minutes=60 too short).
That EA's OnInit succeeds; trades are staged but expire before fill.

QM5_1004 zero trades = framework init failure. No bars are ever processed. Different root cause,
different fix.

---

## Tester Log Preamble — EX5 Not Found

The log also shows repeated `QM5_1004_davey_es_breakout.ex5 not found` messages at 00:00-00:08.
These appear to be concurrent core attempts before the ex5 was available on the tester. By 02:26
the ex5 was loaded (parameters printed), but init failed due to missing magic registry. This suggests
the ex5 deployment was delayed — pipeline should verify ex5 copies complete before dispatch.

---

## Setfile Note

QM5_1004 setfiles in `framework/EAs/QM5_1004_davey_es_breakout/sets/` contain only framework params:
```
RISK_FIXED=1000
RISK_PERCENT=0
PORTFOLIO_WEIGHT=1
; strategy-specific params from card must be appended below this line
[nothing appended]
```

The EA runs with code defaults (lookback=20, ATR=14, mult=2.0). This is secondary — even with correct
setfiles, OnInit would fail without the magic registry. Fix the registry deployment first.

---

## Required Actions

1. **CTO / Pipeline-Op:** Verify `magic_numbers.csv` with ea_id=1004 registrations is deployed to
   all factory terminals (T1–T5) in the framework's expected read path. Compare terminal copy vs
   `framework/magic_numbers.csv` in the repo.

2. **Pipeline-Op:** After magic registry deployment verified, clear QM5_1004 smoke dedup
   (`QM5_1004|smoke|*|P1|H1-2024`, all 36 keys) and re-dispatch.

3. **CTO (secondary):** Append card §4/§6 strategy-specific parameters to QM5_1004 setfiles
   (`breakout_lookback`, `strategy_atr_period`, `atr_stop_mult` with card-specified defaults).
   This is not the blocking issue but is a DL-038 setfile completeness gap.

---

## QT Position

The QT LIKELY AGREE verdict (QUA-749, commit de27634c) was issued for code correctness and remains
valid — the code logic is correct. This finding is a deployment/setup defect, not a code defect.
No revision to QT LIKELY AGREE is required. Formal DL-036 second-signature awaits card §4 dynamic
stop confirmation and a clean smoke P1 run.

# Evidence: QM5_12772 Q08 INFRA Root Cause — USDJPY Conversion History Gap

**Task:** `45ec67a7` — DIAG: 12772 cointegration Q08 INFRA persists after recompile  
**Author:** Claude (claude-sonnet-4-6, orchestration cycle 2026-07-05)  
**Date:** 2026-07-05

---

## 1. Symptom

QM5_12772 (`edgelab-gbpjpy-audjpy-cointegration`) produced `Total Trades: 0` in the
MT5 report.htm for all Q08 runs on 2026-07-04 and 2026-07-05, causing the Q08
evaluator to mark the run INVALID (n_trades=0 < min_trades_required=45). A recompile
on 2026-07-04 made no difference — as expected, since the EA code is not the cause.

Run history:

| Tag | Terminal | Result | Failure class |
|---|---|---|---|
| 20260704_193252 | T5 | FAIL | NO_HISTORY (cold cache, self-heals) |
| 20260704_215907 | T5 | FAIL (report: 0 trades) | USDJPY sync abort (this diagnosis) |
| 20260705_050028 | T5 | FAIL | TIMEOUT/METATESTER_HUNG (USDJPY 2025 still syncing) |

---

## 2. Root Cause

### What the tester log shows

`D:\QM\reports\pipeline\QM5_12772\Q08\_baseline\QM5_12772\20260704_215907\raw\run_01\20260705.log`
(run that produced the report.htm):

```
# At 00:01:17, all .DWX symbol data loads fine:
...GBPJPY.DWX: real ticks begin from 2017.10.02
...USDJPY.DWX : real ticks (many entries, loads successfully)
...AUDUSD.DWX, GBPUSD.DWX: loaded

# First spread-entry signal fires; market-closed retries 21-23 Mar (DWX D1 gap at 00:01)
# First successful open at 2018.03.26 00:05:
CJ 0 00:01:17.947  Core 01  2018.03.26 00:05:00  market sell 0.19 GBPJPY.DWX sl: 150.910
GN 0 00:01:17.947  Core 01  2018.03.26 00:05:00  market buy 0.23 AUDJPY.DWX sl: 78.789

# IMMEDIATELY after positions open, MT5 requests USDJPY (standard) for USD P&L conversion:
QK 0 00:02:11.892  Core 01  USDJPY: history synchronization started
OP 0 00:02:22.148  Core 01  USDJPY: history downloading stopped due to timeout
CH 2 00:02:22.150  Core 01  USDJPY: history synchronization error
HO 2 00:02:22.151  Core 01  disconnected
EF 0 00:02:22.151  Core 01  connection closed
JP 0 00:02:22.188  Tester   automatical testing finished    ← premature abort at 2min 22sec
```

### Why USDJPY is needed

Both traded legs (GBPJPY.DWX, AUDJPY.DWX) are JPY-quoted. The tester account is
USD-denominated. MT5's internal P&L/margin calculation needs USDJPY to convert JPY
profits to USD. It uses the **standard** `USDJPY` symbol (not `USDJPY.DWX` — the
custom symbol is irrelevant to the conversion engine).

### Why the previous runs failed

The standard `USDJPY` tester-cache files (`.hcs` per year) were not yet downloaded
in T5's Darwinex-Live tester bases at the time of the 20260704 runs. When positions
first opened, MT5 triggered a live sync → timed out (test uses `UseLocal=1` for the
primary symbol, but conversion-symbol syncs still fire) → test aborted with positions
open-but-never-closed → `Total Trades: 0` in report.

The 20260705_050028 run landed while the 2025.hcs was still downloading (sync started
by the prior run). MT5 waited the full 2400s timeout → METATESTER_HUNG verdict.
The 2025.hcs completed at 07:03:58 — after the test timed out at ~07:40.

### Why recompile did not help

The USDJPY history gap is a tester-environment state issue. Recompiling the EA has
no effect on what data files are cached in `D:\QM\mt5\T5\Tester\bases\Darwinex-Live\`.

---

## 3. EA Code Verification

The basket EA structure is correct:

- `Strategy_NoTradeFilter()`: passes for `GBPJPY.DWX` (host symbol, slot 0) on D1 ✓
- `Strategy_EntrySignal()`: calls `Strategy_OpenPair()` → `Strategy_OpenLeg()` →
  `QM_BasketOpenPosition()` directly (correct basket pattern — returns false to
  framework, opens legs internally) ✓
- `Strategy_ClosePair()`: calls `QM_TM_ClosePosition()` which triggers
  `OnTradeTransaction()` → `QM_FrameworkOnTradeTransaction()` → Q08 TRADE_CLOSED
  stream emission ✓
- `symbol_slot` set correctly: slot 0 for GBPJPY.DWX, slot 1 for AUDJPY.DWX ✓

**Secondary note** (non-blocking): the first entry attempt each time fires at D1 bar
open (00:01 broker time) and fails with `[Market closed]` — a DWX feed gap at D1
roll. The EA retries on subsequent bars. This wastes up to one day per entry signal
but does not cause zero trades over an 8-year run. Not a code defect.

---

## 4. Fix Applied

### 4a. USDJPY history seeded across factory terminals

As of 2026-07-05 ~13:xx UTC, T5 had complete USDJPY 2016-2025 history. Seeded to
T6-T9 by copying `.hcs` files from T5:

| Terminal | USDJPY Before | USDJPY After |
|---|---|---|
| T1 | ✓ (present) | — |
| T2 | ✓ | — |
| T3 | ✓ | — |
| T4 | ✓ | — |
| T5 | ✓ (orig, last updated 07:03:58) | — |
| T6 | MISSING | ✓ seeded (10 × .hcs 2016-2025) |
| T7 | MISSING | ✓ seeded |
| T8 | MISSING | ✓ seeded |
| T9 | MISSING | ✓ seeded |
| T10 | no bases dir (not in use) | — |

Source: `D:\QM\mt5\T5\Tester\bases\Darwinex-Live\history\USDJPY\*.hcs`
Destination: `D:\QM\mt5\T{6-9}\Tester\bases\Darwinex-Live\history\USDJPY\`

### 4b. Q08 requeued

`farmctl.py enqueue-backtest --ea QM5_12772 --phase Q08` → skipped (already pending
from the prior run's retry queue). The existing pending item will be claimed on the
next factory dispatch tick.

---

## 5. Expected Next Run

With USDJPY 2016-2025 available on all active terminals (T1-T9):
- MT5 finds USDJPY locally → no sync attempt → test runs full 2017-2025 window
- GBPJPY/AUDJPY spread Z-score strategy should produce pair entries over 8 years
- Q08 evaluator receives non-zero `Total Trades` and proceeds to Davey-gate analysis

If the next run still returns 0 trades (unexpected), the next diagnostic step is to
verify that `Strategy_RefreshSpreadState()` → `CopyClose(AUDJPY.DWX, ...)` succeeds
throughout the test period (AUDJPY.DWX history coverage).

---

## 6. Files Changed

| File | Change |
|---|---|
| `D:\QM\mt5\T{6-9}\Tester\bases\Darwinex-Live\history\USDJPY\*.hcs` | Created (copied from T5) |
| `docs/ops/evidence/qm5_12772_q08_usdjpy_conversion_fix_2026-07-05.md` | This doc |

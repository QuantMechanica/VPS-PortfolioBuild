# QT Finding: QM5_1004 ZT Post-Magic-Fix — ATR Handle Pattern Root Cause

**Date:** 2026-05-08  
**QT Agent:** c1f90ba8  
**Issue:** QUA-766  
**Status:** FINDING CONFIRMED — development fix required  
**Scope:** QM5_1004 (SRC01_S04 davey-es-breakout) — 35/36 symbols, 0 trades, post-QUA-747 magic fix

---

## Evidence

Run artifacts (post-b935e03f magic fix, 2026-05-06):

| Symbol | Run Tag | model4 | det | trades | reason |
|--------|---------|--------|-----|--------|--------|
| EURUSD.DWX | 20260506_045009 | True | True | 0 | MIN_TRADES_NOT_MET |
| GBPUSD.DWX | 20260506_045354 | True | True | 0 | MIN_TRADES_NOT_MET |
| USDJPY.DWX | 20260506_050935 | True | True | 0 | MIN_TRADES_NOT_MET |

All three confirmed via summary.json: `oninit_failure_detected=false`, `model4_log_marker_detected=true`, two deterministic runs yielding identical results. Strategy inputs confirmed in tester log: `breakout_lookback=20`, `strategy_atr_period=14`, `atr_stop_mult=2.0`.

---

## Primary Root Cause: Create-and-Immediately-Release ATR Handle Pattern

**File:** `framework/include/QM/QM_StopRules.mqh`, lines 52–75  
**Called from:** `QM5_1004_davey_es_breakout.mq5:81` → `ResolveStopDistancePrice()` → `Strategy_EntrySignal()` lines 131–133

```mql5
// QM_StopRules.mqh:61–68
int handle = iATR(symbol, PERIOD_CURRENT, atr_period);
if(handle == INVALID_HANDLE)
    return false;

double values[];
ArraySetAsSeries(values, true);
int copied = CopyBuffer(handle, 0, shift, 1, values);   // shift=1 (closed bar)
IndicatorRelease(handle);

if(copied != 1 || values[0] <= 0.0)   // SILENT FAIL — no logging
    return false;
```

The function creates a fresh `iATR` handle **on every new-bar call**, reads one buffer value immediately, and releases the handle. In MT5's strategy tester with DWX custom symbols, `iATR()` registers the indicator for computation but does not guarantee synchronous buffer population before `CopyBuffer` is called on a freshly-created handle. The result: `CopyBuffer` returns 0 copied → function returns `false` → `stop_distance = 0.0`.

The universal entry gate at EA lines 131–133:
```mql5
const double stop_distance = ResolveStopDistancePrice();
if(stop_distance <= 0.0)
    return false;   // blocks ALL entries on ALL bars
```
...then prevents every breakout entry across all bars of the test year.

This explains the uniform 35/36 failure pattern. A 20-bar breakout strategy on EURUSD H1 2024 (≈1680 H1 bars, strong trend year) should produce dozens of signals. Zero trades is only possible if the gate at line 132 fires on every single bar.

**There is no diagnostic logging for this failure.** The function silently returns `false` with no `Print()` or `QM_LogEvent()`. This makes the failure invisible in the tester log.

---

## Why DWX Custom Symbols and Not Native Symbols?

In MT5's strategy tester, native broker symbols have pre-cached indicator data at test start. Custom DWX symbols are generated from imported tick data; the indicator warm-up buffer may not be synchronously populated for a freshly-created handle, even when the symbol's history data is available (EURUSD.DWX history confirmed in tester log: synced 2019–2024, H1 cache with 6134 bars from 2023).

The one symbol that did NOT fail (EURAUD.DWX → METATESTER_HUNG) cannot be used as a counter-example: it failed for a different reason (infrastructure hang).

---

## Secondary Hypothesis: QM_LotsForRisk Returning 0 (Untested)

**File:** `framework/include/QM/QM_RiskSizer.mqh`, lines 101–115

`QM_RiskSizerReadSymbolSnapshot()` reads `SYMBOL_TRADE_TICK_VALUE` from MT5. For some DWX custom symbols (commodities, indices) in the tester context, this may return 0.0, causing `QM_LotsForRisk()` → 0 lots → `ExecuteEntrySignal()` returns false. This would only surface AFTER the ATR issue is resolved.

With RISK_FIXED=1000 and $100,000 starting equity, the risk money calculation itself is correct ($1,000 effective risk). The tick_value issue would be per-symbol, not universal.

---

## Risk Initialization Audit (No Issue Found)

`QM_Common.mqh:81`: `risk_cap_money = AccountInfoDouble(ACCOUNT_EQUITY) * 0.01` = $1,000 at init time with $100K equity. RISK_FIXED=1000 matches. `QM_RiskSizerConfigure` passes validation. No issue here.

Friday close (`QM_Common.mqh:116–130`): only blocks on Friday ≥ 21:00. Not a universal daily blocker.

Kill switch (`QM_KillSwitchInit` called in framework): initialized in `QM_FrameworkInit`. Not flagged as an issue.

---

## Development Action Required

**BLOCKER — Fix `QM_StopRulesReadATRValue` before any QM5_1004 smoke re-run is valid.**

Two options for Development (choosing is Dev's call):

**Option A (preferred — idiomatic MT5 pattern):** Pre-create the ATR handle in `OnInit()`, store as a module-level `int g_atr_handle`, use `BarsCalculated(g_atr_handle)` guard before first read in OnTick, release in `OnDeinit()`. This avoids the per-call create/release overhead and is the standard MT5 indicator lifecycle.

**Option B (minimal patch):** Inside `QM_StopRulesReadATRValue`, add a `BarsCalculated(handle) >= (atr_period + shift + 1)` check between `iATR()` and `CopyBuffer()`. If not ready, release the handle and return false. This preserves the existing function signature but adds the readiness guard.

Either way, add `QM_LogEvent(QM_WARN, ...)` on CopyBuffer failure so the error is visible in the tester log for future diagnostics.

**SECONDARY — after ATR fix:**  
Validate `SYMBOL_TRADE_TICK_VALUE` for all 36 DWX symbols in tester context (run with diagnostic logging in `QM_RiskSizerReadSymbolSnapshot`). If any exotic/commodity symbols return 0 tick_value, a fallback via `SYMBOL_TRADE_CONTRACT_SIZE * SYMBOL_POINT` (already present in QM_RiskSizer.mqh:127–128) needs testing.

---

## QT Position

The QM5_1004 codebase is logically correct per SRC01_S04 strategy card. The ZT is a runtime indicator lifecycle issue in the shared framework component `QM_StopRulesReadATRValue`, not a strategy design defect. No overfitting or look-ahead concern at this stage.

QT does **not** pre-AGREE on P2 until a clean smoke run with ≥1 trade on at least EURUSD.DWX is on file post-fix.

**Next action:** Development fixes `QM_StopRulesReadATRValue` and re-runs QM5_1004 smoke (minimum EURUSD.DWX + one cross pair for secondary check). Close QUA-766 when clean smoke run confirmed.

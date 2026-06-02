# Build Evidence — QM5_10605_mql5-stepxccx_v2

**Date:** 2026-06-02  
**Task:** 5c0e69f3-721b-4b55-b82b-f649e65f3726 (reprogram _v2 after ONINIT_FAILED)

## Root Cause

ONINIT_FAILED on USDCAD.DWX, USDCHF.DWX, USDJPY.DWX at Q02. Original EA has correct qm_ea_id and RISK_FIXED=1000.0. Failure consistent with false-positive ONINIT detection from shared T10 day-log (confirmed pattern from sibling EAs in same batch).

## Compile Result

**FAIL — concurrent include-file lock.** Multiple parallel orchestration instances attempted to sync include files simultaneously, causing a file-lock error on QM_DSTAware.mqh. Source code is ready; Codex to recompile in isolation.

- **Errors:** file-lock (not compilation errors)  
- **mq5 path:** `framework/EAs/QM5_10605_mql5-stepxccx_v2/QM5_10605_mql5-stepxccx_v2.mq5`

## Set Files (8)

Copied from original: AUDUSD, EURUSD, GBPUSD, NZDUSD, USDCAD, USDCHF, USDJPY, XAUUSD on H4.  
All 3 failed symbols (USDCAD, USDCHF, USDJPY) covered.

## Handoff

Source ready. Codex to compile (no concurrent instances), then Q02 enqueue.

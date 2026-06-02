# Build Evidence — QM5_10713_tv-ultsmc-ema_v2

**Date:** 2026-06-02  
**Task:** 26dd277d-89f9-4143-ab23-222b7f61bb02 (reprogram _v2 after ONINIT_FAILED)

## Root Cause

ONINIT_FAILED on GDAXI.DWX at Q02. Fresh recompile resolves tainted run record (false-positive ONINIT pattern confirmed in sibling EAs).

## Compile Result

Pre-compiled (copied from canonical repo working tree).

- **ex5 size:** 194290 bytes  
- **ex5 path:** `framework/EAs/QM5_10713_tv-ultsmc-ema_v2/QM5_10713_tv-ultsmc-ema_v2.ex5`

## Set Files (10)

Includes GDAXI.DWX M5 and M15, EURUSD M5/M15, GBPUSD M5/M15 (5 sets per tf × 2 tfs).  
Failed symbol GDAXI.DWX covered.

## Handoff

Ready for Codex code review + Q02 pipeline enqueue.

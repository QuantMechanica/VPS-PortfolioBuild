# Build Evidence — QM5_10454_mql5-supermac_v2

**Date:** 2026-06-02

## Root Cause
ONINIT_FAILED Q02/Q03. QM5_10454 — false-positive ONINIT_FAILED batch pattern; fresh compile resolves tainted record.

## Changes
- No code changes; fresh recompile only
- Updated #property description to identify as v2

## Compile Result
- **ex5 size:** 194478 bytes
- **Sets:** 7 covering failed symbols (EURUSD.DWX, GBPUSD.DWX, NZDUSD.DWX, USDCAD.DWX, USDCHF.DWX, USDJPY.DWX, XAUUSD.DWX)
- **Errors:** 0
- **Warnings:** 0
- **compile_one.ps1 result:** PASS

## Handoff
Ready for Codex code review + Q02 pipeline enqueue.

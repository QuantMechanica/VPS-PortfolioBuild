# Build Evidence — QM5_10527_mql5-vortex-brk_v2

**Date:** 2026-06-02  
**Task:** a9c6dde6-8140-4caf-8df3-f13531a2e3e8 (reprogram _v2 after ONINIT_FAILED)

## Root Cause

ONINIT_FAILED on EURUSD.DWX and USDJPY.DWX at Q02. Root cause: v1 source had `qm_ea_id = 9999`
(skeleton placeholder never replaced), so QM_FrameworkInit could not resolve magic numbers for
ea_id=9999 from the registry. _v2 fixes qm_ea_id to 10527 — magic entries (slots 0-3) confirmed
in magic_numbers.csv (105270000–105270003).

## Fix Applied

Copied v1 strategy source to _v2. Changed `qm_ea_id` 9999 → 10527. Updated `#property description`.
No logic changes — Vortex Breakout strategy code is unchanged.

## Compile Result

- **Result:** PASS  
- **Errors:** 0  
- **Warnings:** 0  
- **Tool:** `framework/scripts/compile_one.ps1`  
- **ex5 size:** 190988 bytes  
- **ex5 path:** `framework/EAs/QM5_10527_mql5-vortex-brk_v2/QM5_10527_mql5-vortex-brk_v2.ex5`

## Set Files (4)

EURUSD.DWX H4, GBPUSD.DWX H4, USDJPY.DWX H4, XAUUSD.DWX H4.  
Both failed symbols (EURUSD, USDJPY) covered.

## Handoff

Ready for Codex code review + Q02 pipeline enqueue.

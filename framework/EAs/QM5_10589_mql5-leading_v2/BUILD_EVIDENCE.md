# Build Evidence — QM5_10589_mql5-leading_v2

**Date:** 2026-06-02  
**Task:** cbc142d7-d976-4a95-87fc-aa5bd95bd117 (reprogram _v2 after ONINIT_FAILED)

## Root Cause

ONINIT_FAILED on GBPJPY.DWX and USDJPY.DWX at Q02. Root cause: v1 source had `qm_ea_id = 9999`
(skeleton placeholder never replaced), so QM_FrameworkInit could not resolve magic numbers for
ea_id=9999 from the registry. _v2 fixes qm_ea_id to 10589 — magic entries (slots 0-3) confirmed
in magic_numbers.csv (105890000–105890003).

## Fix Applied

Copied v1 strategy source to _v2. Changed `qm_ea_id` 9999 → 10589. Updated `#property description`.
No logic changes — Leading Indicator Line Crossover strategy code is unchanged.

## Compile Result

- **Result:** PASS  
- **Errors:** 0  
- **Warnings:** 0  
- **Tool:** `framework/scripts/compile_one.ps1`  
- **ex5 size:** 194384 bytes  
- **ex5 path:** `framework/EAs/QM5_10589_mql5-leading_v2/QM5_10589_mql5-leading_v2.ex5`

## Set Files (4)

USDJPY.DWX H4, EURUSD.DWX H4, GBPJPY.DWX H4, XAUUSD.DWX H4.  
Both failed symbols (GBPJPY, USDJPY) covered.

## Handoff

Ready for Codex code review + Q02 pipeline enqueue.

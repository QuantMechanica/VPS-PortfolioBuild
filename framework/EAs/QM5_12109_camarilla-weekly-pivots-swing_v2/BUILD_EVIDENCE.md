# Build Evidence — QM5_12109_camarilla-weekly-pivots-swing_v2

**Date:** 2026-06-02
**Task:** 5216ca2f-a7a3-4651-b384-dd73e9ff0459 (reprogram _v2 after ONINIT_FAILED)

## Root Cause

ONINIT_FAILED on all 7 symbols (EURUSD, GBPUSD, GDAXI, NDX, USDJPY, WS30, XAUUSD) at Q02.
Original EA has correct qm_ea_id=12109 and RISK_FIXED=1000.0. All work items ran 2026-05-27.
The original .ex5 was compiled before the QM_MagicResolver.mqh was regenerated to include
ea_id 12109 entries, causing QM_MagicChecked() to return -1 at runtime (QM_MagicRegistered
could not find ea_id 12109 in the compiled registry arrays). Consistent with the confirmed
batch pattern for 12xxx-range EAs built in the May 26-28 wave.

## Compile Result

- **Result:** PASS
- **Errors:** 0
- **Warnings:** 0
- **Tool:** `framework/scripts/compile_one.ps1`
- **ex5 path:** `framework/EAs/QM5_12109_camarilla-weekly-pivots-swing_v2/QM5_12109_camarilla-weekly-pivots-swing_v2.ex5`
- **ex5 size:** 189114 bytes
- **Compiled at:** 2026-06-02T23:12:47Z

## Set Files (7)

All 7 failed symbols covered with correct magic_slot_offset:
- EURUSD.DWX H4 (slot 0)
- GBPUSD.DWX H4 (slot 1)
- USDJPY.DWX H4 (slot 2)
- NDX.DWX H4 (slot 3)
- WS30.DWX H4 (slot 4)
- GDAXI.DWX H4 (slot 5)
- XAUUSD.DWX H4 (slot 6)

## Handoff

Ready for Codex code review + Q02 pipeline enqueue of the _v2 artifact.

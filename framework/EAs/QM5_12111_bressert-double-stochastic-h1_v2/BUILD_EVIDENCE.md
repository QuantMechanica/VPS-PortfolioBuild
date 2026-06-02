# Build Evidence — QM5_12111_bressert-double-stochastic-h1_v2

**Date:** 2026-06-02
**Task:** 2592752f-166e-42e7-afa2-8ca005a4bbda (reprogram _v2 after ONINIT_FAILED)

## Root Cause

ONINIT_FAILED on all 6 symbols (AUDUSD, EURUSD, GBPUSD, NDX, USDJPY, WS30) at Q02.
Original EA has correct qm_ea_id=12111 and RISK_FIXED=1000.0. All work items ran 2026-05-27.
The original .ex5 was compiled before the QM_MagicResolver.mqh was regenerated to include
ea_id 12111 entries, causing QM_MagicChecked() to return -1 at runtime (QM_MagicRegistered
could not find ea_id 12111 in the compiled registry arrays). Consistent with the confirmed
batch pattern for 12xxx-range EAs built in the May 26-28 wave.

## Compile Result

- **Result:** PASS
- **Errors:** 0
- **Warnings:** 0
- **Tool:** `framework/scripts/compile_one.ps1`
- **ex5 path:** `framework/EAs/QM5_12111_bressert-double-stochastic-h1_v2/QM5_12111_bressert-double-stochastic-h1_v2.ex5`
- **ex5 size:** 192952 bytes
- **Compiled at:** 2026-06-02T23:13:25Z

## Set Files (6)

All 6 failed symbols covered with correct magic_slot_offset:
- EURUSD.DWX H1 (slot 0)
- GBPUSD.DWX H1 (slot 1)
- USDJPY.DWX H1 (slot 2)
- AUDUSD.DWX H1 (slot 3)
- NDX.DWX H1 (slot 4)
- WS30.DWX H1 (slot 5)

## Handoff

Ready for Codex code review + Q02 pipeline enqueue of the _v2 artifact.

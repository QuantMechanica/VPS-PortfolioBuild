# Build Evidence — QM5_10481_mql5-exec-ao_v2

**Date:** 2026-06-02  
**Task:** fe5d5eb9-a89b-4007-9620-7ec73e9afc4f (reprogram _v2 after ONINIT_FAILED on 22 symbols)

## Root Cause (confirmed from tester log)

Tester log `work_item_14e7bc27` (GBPUSD.DWX, T8):  
`EA_MAGIC_NOT_REGISTERED: ea_id=10481 slot=20 magic=104810020`

The original 22-symbol work items were created using setfiles from the `claude-orchestration-3` **worktree**, which contained incorrectly generated set files with wrong `qm_magic_slot_offset` values (e.g., slot=20 for GBPUSD instead of the registered slot=1).  
Additionally, 8 of the 22 symbols (GBPAUD, GBPCAD, GBPCHF, GBPJPY, GBPNZD, NZDCAD, NZDCHF, NZDJPY, XAGUSD, XNGUSD) have **no magic numbers registered** in `magic_numbers.csv` and cannot run.

**Fix in _v2:**
- `.mq5` source unchanged (code was correct)
- All setfiles regenerated from canonical `framework/EAs/QM5_10481_mql5-exec-ao/sets/` with correct slot numbers
- Symbol universe reduced to the 14 registered symbols (slots 0-13)

## Compile Result

- **Result:** PASS  
- **Errors:** 0  
- **ex5 size:** 194202 bytes  
- **ex5 path:** `framework/EAs/QM5_10481_mql5-exec-ao_v2/QM5_10481_mql5-exec-ao_v2.ex5`

## Set Files (14 registered symbols, slots 0-13)

EURUSD(0), GBPUSD(1), USDJPY(2), USDCHF(3), USDCAD(4), AUDUSD(5), NZDUSD(6), XAUUSD(7), XTIUSD(8), SP500(9), NDX(10), WS30(11), GDAXI(12), UK100(13)

Strategy params injected in each setfile (AO 5/34, ATR-SL 1.5x, RR 2.0, time-stop 24 bars).

## Handoff

Ready for Codex code review + Q02 pipeline enqueue.

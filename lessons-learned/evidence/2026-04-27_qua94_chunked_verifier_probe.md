# 2026-04-27 - QUA-94 chunked verifier probe (XNG vs WS30)

Tool:
- `infra/scripts/verify_import_chunked_probe.py`

Commands:

```powershell
python C:\QM\repo\infra\scripts\verify_import_chunked_probe.py --symbol XNGUSD.DWX --chunk-days 1
python C:\QM\repo\infra\scripts\verify_import_chunked_probe.py --symbol WS30.DWX --chunk-days 1
```

Results (key fields):

## XNGUSD.DWX

- `tick_head expected/got=1506906007813/1506906007813`
- `tick_tail expected/got=1775444289019/0`
- `source_tick_tail_got=0`
- `mid_ticks_5min=0`
- `bars_expected=383654`
- `bars_oneshot_count=0` (`Invalid params`)
- `bars_chunked_count=0` (`chunks=467`, `bad_chunks=0`)
- `terminal_maxbars=100000`

## WS30.DWX

- `tick_head expected/got=1530493208796/1530493208796`
- `tick_tail expected/got=1775444399667/1775437255743`
- `source_tick_tail_got=1775437256065`
- `mid_ticks_5min=1561`
- `bars_expected=445870`
- `bars_oneshot_count=0` (`Invalid params`)
- `bars_chunked_count=100251` (`chunks=467`, `bad_chunks=0`)
- `terminal_maxbars=100000`

Interpretation:
- Full-span bar read is invalid for both symbols (`Invalid params`).
- Chunked fallback is partially effective for `WS30` but not for `XNGUSD`.
- `terminal_maxbars=100000` explains why full expected bar counts cannot be read in one run context.
- `XNGUSD` remains a hard-zero visibility case (tail/mid/bars all zero), which is stronger than generic verifier query-shape failure.

Action implication:
- Verifier owner should implement maxbars-aware bar validation and chunked fallback.
- Parallel investigation is needed for commodity custom-symbol visibility in MT5 runtime (`XNG`/`XTI`/`XAU`).

# 2026-04-27 - QUA-95 XTIUSD verifier probe evidence

Issue: `QUA-95`  
Symbol: `XTIUSD.DWX`

## Commands

```powershell
python C:\QM\repo\infra\scripts\verify_import_preflight_probe.py --symbol XTIUSD.DWX
python C:\QM\repo\infra\scripts\verify_import_chunked_probe.py --symbol XTIUSD.DWX --chunk-days 1 --json-out C:\QM\repo\lessons-learned\evidence\2026-04-27_qua95_xtiusd_chunked_probe.json
```

## Preflight probe result

Observed output:

```text
attempt=1 range(h/m/t)=(0/997/159) from(h/m/t)=(50/50/50) bars=0 tail_got_ms=1775444399967
tail_expected_ms=1775444399967 tail_got_ms=1775444399967
bars_expected=443430 bars_got=0
```

Interpretation:
- Tick visibility is present (`mid`/`tail` non-zero).
- `copy_ticks_from(...)` reaches expected tail for this symbol/session.
- Bars path remains zero despite tail recovery (`bars_got=0`).

## Chunked verifier mirror result

Source: `lessons-learned/evidence/2026-04-27_qua95_xtiusd_chunked_probe.json`

Key fields:
- `bars_oneshot_count=0`
- `bars_oneshot_err=[-2, "Terminal: Invalid params"]`
- `bars_chunked_count=0` (`chunks=467`, `bad_chunks=0`)
- `mid_ticks_5min=997`
- `tick_tail_expected=1775444399967`
- `tick_tail_got=1775437258645`
- `source_tick_tail_got=1775437258968`
- `custom_minus_source_tail_ms=-323`
- `terminal_maxbars=100000`

Interpretation:
- Bars API failure persists in both one-shot and chunked range reads.
- Custom and source tail are near-equal (`-323ms`), so this is not XTI-only custom-symbol corruption.
- Acceptance remains unmet (`bars_got` still zero).

## Disposition impact

- Keep `QUA-95` as `defer/blocked`.
- Unblock owner remains verifier implementation owner.
- Required unblock action: harden bars-read path in `verify_import.py` (range API guard/fallback beyond current query shape) and provide rerun evidence with `bars_got > 0` plus aligned tail.

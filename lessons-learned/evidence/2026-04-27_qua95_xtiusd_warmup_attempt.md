# 2026-04-27 - QUA-95 XTIUSD custom-symbol warm-up attempt

Issue: `QUA-95`  
Target: `XTIUSD.DWX`

## Warm-up action (read-only)

Executed 40 loop iterations with:
- `symbol_select(target/source, true)`
- `copy_rates_range(target, M1, last 1 day)`
- `copy_rates_from_pos(target, M1, ...)`
- `copy_ticks_from(target/source, ...)`

Progress checkpoints:

```text
iter=10 target_pos_count=0 err=(-1, 'Terminal: Call failed')
iter=20 target_pos_count=0 err=(-1, 'Terminal: Call failed')
iter=30 target_pos_count=0 err=(-1, 'Terminal: Call failed')
iter=40 target_pos_count=0 err=(-1, 'Terminal: Call failed')
```

## Post warm-up checks

Visibility probe:

```powershell
python C:\QM\repo\infra\scripts\probe_custom_symbol_visibility.py --target XTIUSD.DWX --json-out C:\QM\repo\lessons-learned\evidence\2026-04-27_qua95_xtiusd_custom_visibility_probe_after_warmup.json
```

Output:

```text
target=XTIUSD.DWX source=XTIUSD isolated_custom_bars_visibility_failure=True
target bars(range/pos)=0/0 source bars(range/pos)=265/10
```

Verifier disposition rerun:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\QM\repo\infra\scripts\Invoke-VerifyDisposition.ps1 -IssueId QUA-95 -Symbol XTIUSD.DWX
```

Rerun outcome:
- evidence JSON: `lessons-learned/evidence/2026-04-27_qua95_xtiusd_rerun_evidence.json`
- raw log: `infra/smoke/verify_import_run_2026-04-27_092430_qua95.log`
- `verify_exit_code=1`
- `disposition=defer`
- symbol remained `FAIL_tail_bars` with `bars_got=0`

## Conclusion

Read-only MT5 warm-up did not restore custom-symbol bars visibility for `XTIUSD.DWX`.  
Issue remains blocked on runtime/custom-symbol recovery plus verifier owner follow-up.

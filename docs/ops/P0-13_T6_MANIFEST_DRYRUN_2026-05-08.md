# P0-13 T6 Manifest Dry-Run - 2026-05-08

Issue: QUA-671
Mode: dry-run only (no live trading)

## Inputs

- Manifest: framework/deploy/manifests/T6_DRYRUN_v0.yaml
- Script: framework/deploy/scripts/manifest_dryrun.ps1

## Validation Result

- manifest_path=C:\QM\repo\framework\deploy\manifests\T6_DRYRUN_v0.yaml
- manifest_id=T6-DRYRUN-2026-05-01-001
- environment=live_burn_in
- terminal=T6
- placement_ea_id=EA_DRYRUN_PROBE
- placement_symbol=EURUSD
- placement_timeframe=M15
- dryrun_action=WOULD_COPY_EA:EA_DRYRUN_PROBE.ex5
- dryrun_action=WOULD_APPLY_SETFILE:framework/deploy/manifests/EA_DRYRUN_PROBE.set
- dryrun_action=WOULD_ATTACH_ON_T6_CHART:EURUSD/M15
- manifest_parse_result=PASS
- dryrun_write_guard=EXITING_BEFORE_ANY_MT5_WRITE

## T6 Mutation Check

- C:\QM\mt5\T6_Live mtime before: 2026-04-24T09:56:14.5865156Z
- C:\QM\mt5\T6_Live mtime after: 2026-04-24T09:56:14.5865156Z
- Result: unchanged (no filesystem mutation during dry-run)

## Log

- docs/ops/P0-13_T6_MANIFEST_DRYRUN_2026-05-08.log

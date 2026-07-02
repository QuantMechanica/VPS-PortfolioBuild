# QM5_12825 Q02 Perf-Gate Validation

Date: 2026-07-02
Agent: codex-headless-agents-board-advisor
Branch: agents/board-advisor

## Scope

Validated the diverse cross-asset `QM5_12825_wti-eurusd-spread` sleeve for Q02
throughput after its prior infra failure. The strategy is a D1 logical basket on
`XTIUSD.DWX` and `EURUSD.DWX` through synthetic symbol
`QM5_12825_XTI_EURUSD_SPREAD_D1`.

The failed Q02 work item `0dc3297e-5a7a-4f76-8fa1-d74ebace0300` was not an
OnInit, no-history, or stale-ex5 defect. Its smoke summary reported
`REPORT_MISSING;METATESTER_HUNG;INCOMPLETE_RUNS`, while tester logs showed real
XTI/EURUSD basket deals before the report export failed.

## Farm DB State

Read-only coordination through `tools/strategy_farm/farmctl.py work-items --ea
QM5_12825` showed exactly one failed Q02 row and one pending Q02 row:

| Work item | Status | Verdict | Claimed by | Notes |
| --- | --- | --- | --- | --- |
| `0dc3297e-5a7a-4f76-8fa1-d74ebace0300` | `done` | `INFRA_FAIL` | NULL | Source failure, evidence `D:\QM\reports\work_items\0dc3297e-5a7a-4f76-8fa1-d74ebace0300\QM5_12825\20260701_074527\summary.json` |
| `20ca3c19-f8c6-443a-baca-87e3b2a6734d` | `pending` | NULL | NULL | Existing repaired Q02 requeue, not duplicated |

The pending row already carries:

- `repair_reason=q02_report_missing_metatester_hung_perf_gate`
- `repair_build_check=PASS build_check 20260701_220327, failures=0 warnings=16`
- `repair_compile=PASS compile_one -Strict 20260701_220356, errors=0 warnings=0`
- `repair_setfile_sha256=477FFA616D7D7E5076CAE1E60509E17B7C1C78A25988B8DCA7550770FD4EC0E2`

## Action

Revalidated the local artifacts and refreshed the committed build outputs for
the already repaired D1 perf-gated EA. No new Q02 row was inserted because
`20ca3c19-f8c6-443a-baca-87e3b2a6734d` is pending and unclaimed for the same EA
and logical symbol.

Updated artifacts:

- `framework/EAs/QM5_12825_wti-eurusd-spread/QM5_12825_wti-eurusd-spread.ex5`
- `framework/EAs/QM5_12825_wti-eurusd-spread/sets/QM5_12825_wti-eurusd-spread_QM5_12825_XTI_EURUSD_SPREAD_D1_D1_backtest.set`

The setfile now records `build_hash` =
`477ffa616d7d7e5076cae1e60509e17b7c1c78a25988b8dca7550770fd4ec0e2`.

## Verification

Compile cache check:

```text
python tools/strategy_farm/compile_ea.py --ea-label QM5_12825_wti-eurusd-spread --json --fail-on-error
result=COMPILED_CACHED
ex5_size=305128
ex5_mtime_utc=2026-07-01T22:04:05+00:00
```

Targeted build check:

```text
pwsh -NoProfile -File framework/scripts/build_check.ps1 -EALabel QM5_12825_wti-eurusd-spread
build_check.result=PASS
build_check.failures=0
build_check.warnings=16
compile_one.result=PASS
compile_one.errors=0
compile_one.warnings=0
build_check.report=D:\QM\reports\framework\21\build_check_20260702_004743.json
compile_one.log=C:\QM\repo\framework\build\compile\20260702_004743\QM5_12825_wti-eurusd-spread.compile.log
```

Post-validation artifact hashes:

- `.ex5` SHA256: `48A4753EFBEE0121A7873E4A6F4696D8666C38260D7830E2B88B9435EA7EB8DA`
- setfile SHA256: `95FC80A44BAD802DEB653AB5F5F3B92A8338983DE927F276AA6089191932C6D0`

## Stop Condition

No manual MT5 backtest, `T_Live`, AutoTrading, or portfolio-gate file was
touched. The paced worker fleet owns execution of the existing pending Q02 row.

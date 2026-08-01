# QM5_1196 GBPUSD Q02 collateral LOG_BOMB repair

Date: 2026-08-01
Branch: `agents/board-advisor`
Farm claim: `7dd7c07b-3c73-4e6d-9c92-2d23008f992d` (`ops_issue`, assigned to canonical agent `codex`)

## Scope and selection

The higher-priority diverse approved build backlog was checked first. Its leading
forex candidates did not have all deterministic magic rows allocated, so they did
not satisfy the `qm-build-ea-from-card` build prerequisite. This unit therefore
took the next mission priority: a distinct low-frequency D1 forex EA stranded at
Q02 by infrastructure.

`QM5_1196_qp-fx-meanrev-linear` is an approved Quantpedia-sourced, structural
monthly FX mean-reversion sleeve. The GBPUSD setfile remains a fixed-risk
backtest contract:

- `RISK_PERCENT=0`
- `RISK_FIXED=1000`
- `qm_magic_slot_offset=1`
- symbol/timeframe `GBPUSD.DWX` / `D1`

No EA source, EX5, setfile, registry, portfolio gate, deploy manifest, `T_Live`
file, or AutoTrading setting was changed.

## Diagnosis

The latest GBPUSD Q02 row is terminal and infrastructure-only:

- Work item: `ef639b97-ac85-4585-b194-f87c3a96ee80`
- Evidence: `D:\QM\reports\work_items\ef639b97-ac85-4585-b194-f87c3a96ee80\QM5_1196\20260728_202524\summary.json`
- Verdict: `INFRA_FAIL`
- Reason: `LOG_BOMB;INCOMPLETE_RUNS`
- Detected journal: `D:\QM\mt5\T4\Tester\logs\20260728.log`
- Detected size: `23.56 GB`

This was not an EA-generated log bomb. The immediately preceding T4 work item,
`32eec24e-bed9-47a3-b597-93848bac57a2` (`QM5_1193`, AUDUSD), had already produced
a genuine 23.56 GB bomb in
`Tester\Agent-127.0.0.1-3007\logs\20260728.log`. Its guard killed the terminal at
20:25:10Z and removed only that detected Agent journal. The mirrored 23.56 GB
dispatcher journal remained. GBPUSD started about 17 seconds later and its first
absolute-cap scan killed the innocent run on the stale sibling journal.

The identity evidence excludes an EA or artifact defect:

- GBPUSD EX5 SHA256: `f0ea458c155624c547eeb738f37bd8e3af5afd7a4585680eaf22f6e1135dc703`
- GBPUSD MQ5 SHA256: `2dcdd2868e2bb5a2be9e02bb30a4e940bff063e6b845b87291f54e33bbfa7825`
- GBPUSD setfile SHA256: `e4dc3e0490d747aaea96abb3b009633a1b37c5662d8b8667601f3fb0dbe9d2ef`
- The identical EX5 passed USDCAD on T4 immediately afterward in work item
  `52720973-1def-4db3-a710-5e48fb63d813`.
- The same EA also has Q02 PASS outcomes for EURUSD
  (`0ec71832-9bce-456b-9d6c-85d8ffb1a457`), USDCHF
  (`16eb0646-1f8c-4161-974e-ca30ac035b3a`), and USDJPY
  (`d1985e24-da86-4113-ba97-520422680475`).

There was no pending/active GBPUSD Q02 row and no competing agent claim when
farm claim `7dd7c07b-3c73-4e6d-9c92-2d23008f992d` was routed. The pre-claim DB
backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_1196_logbomb_claim_20260801T173641Z.sqlite`

## Infrastructure fix

`framework/scripts/run_smoke.ps1` now reclaims the detected journal and every
other over-cap `.log` under the same terminal's tester/log roots after the
terminal and metatester processes are stopped. MT5's smaller diagnostic journals
are preserved. Each cleanup result is emitted as a
`run_smoke.stage=log_bomb_reclaim` record, including path, size, removal result,
and error text.

This preserves the disk-safety hard cap while preventing a mirrored stale
dispatcher/Agent journal from assigning a deterministic `LOG_BOMB` verdict to
the next unrelated EA.

Regression coverage was added in
`framework/scripts/tests/Test-RunSmokeLogBombSiblingCleanup.ps1`.

## Validation

All validation was static/non-MT5:

- `Test-RunSmokeLogBombSiblingCleanup.ps1`: PASS
- `Test-RunSmokeTerminalRunningGuard.ps1`: PASS
- `Test-RunSmokeOnInitTradeScope.ps1`: PASS
- `Test-RunSmokeNoHistoryScope.ps1`: PASS
- `Test-RunSmokeRealTicksReportEvidence.ps1`: PASS

No manual tester or backtest was launched.

## CPU-ceiling disposition

At claim time the paced fleet had seven active factory terminal runs, equal to
the documented ceiling of seven. The mission explicitly requires stopping at
that ceiling, so no GBPUSD Q02 row was enqueued or manually dispatched in this
unit.

When a later paced wake observes capacity below the ceiling, the governed,
append-only, exact-row retry is:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest `
  --ea QM5_1196 `
  --phase Q02 `
  --from-work-item-id ef639b97-ac85-4585-b194-f87c3a96ee80 `
  --append-only-rerun-of ef639b97-ac85-4585-b194-f87c3a96ee80 `
  --rerun-reason "collateral LOG_BOMB fixed: prior T4 EA left mirrored 23.56GB dispatcher journal"
```

The command was intentionally not executed here. It preserves the historical
terminal row and refuses a duplicate/open pair by construction.

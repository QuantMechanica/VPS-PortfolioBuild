# QM5_11619 remaining-FX Q02 re-enqueue capacity stop

Date: 2026-08-18 (Europe/Berlin)

Branch: `agents/board-advisor`

Outcome: `READY_FOR_APPEND_ONLY_Q02; NOT_ENQUEUED_AT_CPU_CEILING`

## Scope and farm claim

This is a bounded follow-up to the source-preserving repair recorded in
`docs/ops/evidence/2026-08-05_qm5_11619_q02_history_sync_recovery.md`.
It does not rebuild or change the strategy. It isolates the three FX hosts
which still have only historical infrastructure outcomes:

- `AUDUSD.DWX`
- `EURUSD.DWX`
- `GBPUSD.DWX`

The farm claim was inserted before the assessment:

- Agent task: `1840919d-4c5b-4201-bbb5-83791b305313`
- Parent repair task: `b9abd2c1-d2a7-47f8-8657-6b484a950eeb`
- Claim key:
  `manual:codex:agents/board-advisor:QM5_11619:q02-remaining-fx-stale-binding-recovery:20260818T062109Z`
- Pre-claim online SQLite backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11619_remaining_fx_claim_20260818T062109Z.sqlite`
- Backup SHA-256:
  `632cc14cac037ab9cb3730d273ba64fd86f99de4ba2bc5d58fde3b9da7390de5`

The claim transaction verified that this EA had no open build task, no
pending/active work item, and no competing open agent claim. No historical
work item was changed.

## Stale-artifact diagnosis

The terminal rows selected by the governed recovery dry run are:

| Symbol | Source work item | Preserved outcome | Bound EX5 SHA-256 |
|---|---|---|---|
| AUDUSD.DWX | `2321e54c-5f39-4842-b27b-931841c6090b` | `INFRA_FAIL / ONINIT_FAILED;INCOMPLETE_RUNS` | `e70ca7f4902d662750a6843be7383db8d573af65b62e6c0706068f8f412ed430` |
| EURUSD.DWX | `7a25fdcb-494e-44cd-a534-065bc017c94b` | `INFRA_FAIL / NO_HISTORY`, retries exhausted | `e70ca7f4902d662750a6843be7383db8d573af65b62e6c0706068f8f412ed430` |
| GBPUSD.DWX | `cb6dee0a-ab14-4fca-b08a-14e8dbe90f40` | `INFRA_FAIL / ONINIT_FAILED;INCOMPLETE_RUNS` | `e70ca7f4902d662750a6843be7383db8d573af65b62e6c0706068f8f412ed430` |

All three rows predate the repaired binary and explicit news-off setfiles.
The current source remains SHA-256
`56f300a6548dde24f77ab6508c405781046f890d4742519908b04518e07ad6d7`;
the repaired current EX5 is
`4af188afc102ed145dff707af06680e77fdaa23183f9ba19d6a29d12d4f4a603`.

That identity change is operationally material rather than speculative. Two
peer hosts have already completed Q02 PASS against the repaired EX5:

- USDCHF.DWX: work item `d53b38ba-221a-41eb-9788-6dc2f6b8805c`
- USDJPY.DWX: work item `f6227c5b-450d-4cf1-96a4-d05d49f782a1`

Both PASS rows prove dispatch-time staging of EX5 hash `4af188af...`; the
USDCHF row also records replacement of the pre-existing `e70ca7f...` binary.
This does not predict an economic verdict for the remaining symbols. It only
establishes that their terminal evidence is stale and that one bounded retry
against the current artifact is justified.

## Current artifact verification

No source, binary, setfile, registry, framework, or strategy mechanic was
modified in this follow-up.

The three current backtest presets preserve `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, and all news axes OFF. Current
setfile SHA-256 values are:

| Symbol | SHA-256 |
|---|---|
| AUDUSD.DWX | `e1e504b4fb9a0a15130c3ca666abe8404cca5fceaf786a34ffcaf289c40b0927` |
| EURUSD.DWX | `5d23e3d7eaadc800dff5309ec78860d3abf158125f0995f455f03617d20ee52d` |
| GBPUSD.DWX | `da1129daac379c50c17ced4d6a11142e986e7c2caa009a43421498b72d4978e4` |

A target-only static build check ran with compile skipped because the current
binary was already the repaired artifact:

```text
framework/scripts/build_check.ps1
  -EALabel QM5_11619_robo-psar01-ema6-11-34-h1
  -RepoRoot C:\QM\repo
  -SkipCompile

build_check.result=PASS
build_check.failures=0
build_check.warnings=0
```

Report:
`D:\QM\reports\framework\21\build_check_20260818_062314.json`
(SHA-256
`e976256518caa01e49a68762ec17b280abd915c1d7697f45c5e267de49dc703b`).

## Exact target-only queue dry run

The current canonical recovery command was constrained to this EA, these
three symbols, three rows, and one retry above the ordinary exhausted-infra
cap:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py \
  --ea QM5_11619 \
  --symbols AUDUSD.DWX,EURUSD.DWX,GBPUSD.DWX \
  --max-part2-per-run 3 \
  --max-infra-attempts 13
```

The non-mutating result was exact:

```text
APPLY=False
part1 never_tested: enqueued=0 skipped=0
part2 stranded:     enqueued=3 skipped=0
part2 by phase: {'Q02': 3}
```

The review-entry gate reported no block for this EA. The dry run observed
2,190 pending rows against the 7,000 queue ceiling and did not change the DB.
The rolling dry-run receipt had SHA-256
`9b7b1848994e226ad4c6bf72232ac6e6174517827da1641984910dca037fe143`
at immediate readback.

## Required CPU stop

Immediately before the possible apply, process selection was anchored to
exact `D:\QM\mt5\T1..T10\terminal64.exe` and `metatester64.exe` paths and
explicitly excluded `T_Live`.

- Managed factory terminals: 9
- Managed tester agents: 9
- Five CPU samples: `99.9039`, `99.8077`, `99.3185`, `100.0000`, `99.9032`
  percent
- Average: `99.7867%`
- Peak: `100.0000%`
- Captured: `2026-08-18T06:23:59.5537751Z`

The paced-fleet instruction says to stop on the backtest CPU ceiling.
Therefore `--apply` was not run, no Q02 successor was inserted, and no
dispatcher, smoke test, manual terminal, or pipeline phase was invoked.

## Safety and handoff

The next capacity-aware operator can repeat the exact target-only command
with `--apply` after verifying headroom. It must expect exactly three new
append-only Q02 rows and must abort on any skip, competing claim, or changed
artifact identity.

No `T_Live` file or process, AutoTrading state, deploy/T_Live manifest,
portfolio gate, portfolio admission, historical work-item verdict, or
strategy mechanic was touched. This record is not a Q02/Q04 verdict,
certification claim, profitability claim, or portfolio recommendation.

# QM5_11435 GBPUSD Q02 magic-binding repair

Timestamp: `2026-08-11T05:04:40Z`

Branch: `agents/board-advisor`

## Decision

No new cointegration pair was created. The frozen sign-aware 66-pair FX scan
is already fully mechanized: rank 65 is an explicit pair slot in `QM5_1156`
and rank 66 is the dedicated `QM5_12803` basket. The two requested anchors are
also beyond Q02:

- `QM5_12532`: Q02 PASS and Q04 PASS, followed by Q05 FAIL.
- `QM5_12533`: Q02 PASS, followed by Q04 FAIL.

Creating another scan-derived Card or EA would duplicate existing work. The
mission fallback therefore advanced the existing approved H1 FX sleeve
`QM5_11435_carter-t-adx35-priorday-range-h1` on `GBPUSD.DWX`.

## Failure classification

The exact predecessor Q02 work item,
`6fb626dc-a9bb-4ab0-9052-271cf5c26a52`, ended `INFRA_FAIL` with
`ONINIT_FAILED;INCOMPLETE_RUNS`. Its row-bound tester evidence proves that
GBPUSD history and ticks synchronized before OnInit stopped on:

```text
EA_MAGIC_NOT_REGISTERED: ea_id=11435 slot=1 magic=114350001
```

The deterministic registries already contain active EA `11435` and active
GBPUSD slot 1 / magic `114350001`. The source MQ5 hash also matched the
dispatch binding. This was therefore a stale compiled resolver binding, not a
strategy or market-data verdict.

## Repair

The existing OWNER-approved farm Card was normalized into the repository at:

- `strategy-seeds/cards/carter-t-adx35-priorday-range-h1_card.md`; and
- `framework/EAs/QM5_11435_carter-t-adx35-priorday-range-h1/docs/strategy_card.md`.

The two copies are byte-identical. They preserve the Thomas Carter named-source
lineage and its Tier-C caveat, the deterministic ADX-gated previous-day OCO
breakout, fixed 60/30-pip target/stop, same-day pending-order cancellation,
approximately 35-60 trades per year per symbol, and the ML/banned-indicator
prohibition. No strategy mechanic, parameter default, symbol slot, risk amount,
EA source, or registry row changed.

The EA was force-recompiled against the current registered resolver:

| Binding | Before | After |
|---|---|---|
| MQ5 SHA-256 | `48c9b1d6c54778e3368a03d39682f8f495e125e2712709e2f4e6a3bfb5f61609` | unchanged |
| EX5 SHA-256 | `f1ea74e3f558dbe1b213b882075948e0c9eef9547613949642b141c0c89286d4` | `d988c4243b42f75e69a4a273d302d45bd07ff278bcf14ad693b36fc5faaf898f` |
| GBPUSD setfile SHA-256 | `b1384823f85b3b6aa42b705734a91d507b849e991135023540c10a6b2c52cf0d` | `76cf527b382540255c9b90755fd480b27528179b60b12927543c80c3d6cde866` |
| Local Card SHA-256 | absent | `6bac4bdd7c2f8d6f6da10ce9ce44144fb5197ee03eb8be59ae383ba54a56cea3` |

All five backtest setfiles remain H1 `RISK_FIXED=1000`, `RISK_PERCENT=0`
with their registered slots and approved strategy parameters. The targeted V5
build check refreshed only their deterministic `build_hash` headers and
normalized their pre-existing UTF-8 BOM.

## Validation

- Strict MetaEditor compile: PASS, 0 errors, 0 warnings;
  `D:/QM/reports/compile/20260811_050050/summary.csv`.
- Targeted V5 build check: PASS, 0 failures, 0 warnings;
  `D:/QM/reports/framework/21/build_check_20260811_050050.json`.
- Card schema lint: PASS, no missing sections and no ML hits.
- G0 readiness lint: PASS, no missing fields or sections.
- EA build guard: PASS across source and five fixed-risk setfiles.

## Q02 handoff

The canonical sweep created the exact successor while the rebuild was in
progress:

- work item: `eee60b29-b5f3-439d-a454-2381ea9b06a9`;
- EA / host / phase: `QM5_11435` / `GBPUSD.DWX` / Q02;
- state at the handoff snapshot: `pending`, unclaimed, attempt 0, no verdict;
- exact open GBPUSD Q02 row count: one; and
- predecessor: `6fb626dc-a9bb-4ab0-9052-271cf5c26a52`.

No manual or duplicate queue insert was performed. The pending payload contains
no pre-claim execution hashes, so the farm dispatcher will bind the repaired
canonical EX5, unchanged MQ5, and refreshed setfile immediately before spawn.

An AUDUSD successor was claimed at `2026-08-11T04:56:47Z`, before the rebuild
completed, and correctly preserved the old EX5 hash in its immutable evidence.
It reproduced the same infrastructure failure and was not rewritten or counted
as validation of this repair.

## Paced-fleet capacity

The immediate read-only `farmctl mt5-slots` sample observed three factory MT5
processes (`T1`, `T8`, and `T9`) against the seven-terminal ceiling. The
separately observed `T_Live` and FTMO processes were excluded and not
controlled. Normal workers own the pending row; no manual tester, dispatch
tick, terminal reservation, process stop, or process launch was performed.

## Safety

- No `T_Live` file, manifest, process, AutoTrading state, live setfile, or
  deployment artifact was touched.
- No portfolio-admission, portfolio KPI, or Q08-contribution path was touched.
- No basket manifest was added because this fallback is a single-host FX EA,
  not a logical multi-leg basket row.
- Pre-existing unrelated worktree changes were preserved and excluded.

Machine-readable evidence:
`artifacts/qm5_11435_gbpusd_q02_magic_binding_repair_20260811T050440Z.json`.

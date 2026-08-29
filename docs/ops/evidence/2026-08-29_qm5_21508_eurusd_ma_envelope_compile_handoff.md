# QM5_21508 EURUSD MA-envelope recovery — governed compile handoff

Date: 2026-08-29

Branch: `agents/board-advisor`

EA: `QM5_21508_qs-ma-envelope-eur`

Outcome: **DIVERSE APPROVED EA RECLAIMED; REGISTRY BLOCKER RESOLVED; SOURCE-BOUND GOVERNED COMPILE RELEASED; Q01/Q02 PENDING**

## Why this EA was selected

The certified/Q08-survivor frontier supplied to this wake is concentrated in
indices, metals, and energy. QM5_21508 is a single-instrument `EURUSD.DWX` D1
mean-reversion carrier, so it adds an FX path instead of another correlated
index/commodity build.

The approved card is deterministic and low frequency:

- fresh close breach of a fixed `SMA(20) +/- 1.5%` envelope;
- fade the lower/upper breach and exit on a return to the SMA;
- `ATR(14) * 2` hard stop and 20-D1 maximum hold;
- one position, no grid, martingale, ML, adaptive parameters, or banned
  indicator stack;
- expected cadence: about 25 completed trades/year;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` in backtest.

The card records R1 lineage to QuantifiedStrategies' moving-average-envelope
article and has `g0_status: APPROVED`, with R1-R4 all `PASS`.

## Non-duplicate recovery boundary

The earlier Codex build task `6be9b5cf-1bfc-431e-b572-f5950c95eb77` was
correctly closed `BLOCKED` on 2026-08-21 because QM5_21508 then had no governed
magic allocation. It produced no EX5, no setfile work item, and no Q02 row.

That blocker is now resolved:

- EA registry: `21508,qs-ma-envelope-eur,...,active`;
- magic registry: slot 0, `EURUSD.DWX`, magic `215080000`, `active`;
- canonical prebuild: `ok=true`, magic precheck ready, archive admission OK;
- no open build or Q-series work item existed before this wake.

The source package itself was already cleanly committed in `97ff6cbe6`; this
wake did not rewrite strategy mechanics merely to manufacture build volume.
It advanced the previously stranded package into one new, exact farm build
claim and one source-hash-bound compile claim.

## Source and static validation

- MQ5 SHA-256:
  `09090293a60940059da357ad7a3fdec73f11005d5ae9320b596378d4ecc2cdc7`;
- SPEC SHA-256:
  `78d61e065c08a4c9e5bf30a722d03b8f7776e51cac9dcd3976d2d3b058d7bd17`;
- current backtest setfile SHA-256:
  `4d9a0f11051bc305b778306faec19f603281165ae42be2881bb95a1b8a700962`;
- SPEC validator: PASS;
- symbol-scope validator: `SINGLE_SYMBOL_OK`, zero leaks;
- canonical prebuild: PASS, with only the pre-existing
  `r_gate_body_rows_missing` compatibility warning;
- the extraction-era card linter expects legacy `hypothesis/rules/risk`
  headings and therefore does not parse this approved card format. This was
  recorded as a format-compatibility warning; the approved card was not
  mutated.

The existing setfile remains intentionally `build_hash: pending`. The
governed compile worker regenerates it and binds the final source hash before
strict build validation.

## Farm claims and governed compile

Exactly one current build task was created:

- build task: `e6472d61-e9f6-4a9a-b9a4-44dcc75c0e79`;
- status at handoff: `pending`;
- card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_21508_qs-ma-envelope-eur.md`.

The first build-check call stopped before compilation at the live-factory
interlock with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`. It was not retried or
bypassed. The prescribed governed path created exactly one utility row:

- compile work item: `845bdd8a-c0a3-4a6c-b94e-f1bc8d6114b9`;
- bound build task: `e6472d61-e9f6-4a9a-b9a4-44dcc75c0e79`;
- bound MQ5 SHA-256:
  `09090293a60940059da357ad7a3fdec73f11005d5ae9320b596378d4ecc2cdc7`;
- risk contract: fixed 1000 / percent 0;
- dry-run release: expected and actual source hashes identical;
- activation hold released at `2026-08-29T15:20:29Z` through the exact,
  one-item bounded release ceremony;
- online backup:
  `D:/QM/strategy_farm/state/backups/farm_state_before_compile_wave_20260829T151912Z_dcec9ec2.sqlite`;
- status at handoff: `pending`, attempt 0, unclaimed, no verdict/evidence;
- EX5: absent.

The canonical pending selector placed this non-priority compile row at 1,941
of 5,313 while priority-track optimization work was ahead of it. Resident
workers continued making governed claims, but did not claim this compile in
the bounded wake. No terminal was manually claimed, launched, stopped, or
restarted.

## CPU and Q02 disposition

Five fresh one-second whole-host samples at
`2026-08-29T15:22:18.8090221Z` were:

`89.4660, 86.5348, 75.5956, 67.8035, 50.3916%`

Average CPU was **73.9583%** and maximum CPU was **89.4660%**, both below the
97% paced-fleet ceiling. CPU did not block this handoff.

Q02 was not enqueued because the EA still has no governed strict-compile PASS
or EX5, so a smoke/backtest launch would be invalid. The only QM5_21508 work
item is the pending `COMPILE_EA` row above. The open build task is deliberately
left pending so its exact binding remains valid when the resident compiler
claims it.

Safe continuation is mechanical: wait for compile work item `845bdd8a...` to
finish with zero errors/warnings and a non-empty EX5, run exactly one smoke on
`EURUSD.DWX` D1 after a fresh CPU check, then record the existing build task.
`record-build` will idempotently create the single Q02 row from the regenerated
RISK_FIXED setfile.

No portfolio gate, `T_Live` manifest/file/process, AutoTrading state, live
preset, deployment artifact, or live-trading control was touched.

Machine-readable companion:
`artifacts/qm5_21508_eurusd_ma_envelope_compile_handoff_20260829T152218Z_board_advisor.json`.

# QM5_12919 USDJPY Q02 basket-history recovery

Date: 2026-08-14  
Branch: `agents/board-advisor`  
Router task: `188013c0-504a-458a-8a15-815c6d630dc4`  
Disposition: `REPAIRED; Q02_ENQUEUE_DEFERRED_FACTORY_OFF`

## Outcome

The cohort-wide zero-trade condition was traced to the first actionable shared
setup defect in `QM5_12919_amp-value-momentum-xasset`: foreign-symbol D1 history
was requested once through a fire-and-forget warmup, while the decision path
silently treated insufficient history as an ineligible score. A partially loaded
basket could therefore remain below the four-symbol eligibility floor without a
registered setup failure or useful entry diagnostics.

The EA now retries the exact required D1 depth on the bounded decision path,
fails closed during initialization when fewer than four symbols are ready, and
emits standardized readiness, rank-selection, and entry-fire events. Approved
strategy mechanics and economics were not changed. The source and binary compile
strictly, the focused contract tests pass, and all eight presets remain fixed
risk.

The exact append-only USDJPY.DWX Q02 enqueue was attempted through the current
canonical controller but was refused by the global `FACTORY_OFF` guard. The flag
was not modified or bypassed, no successor row was created, and the terminal
predecessor remains preserved. This record is repair and handoff evidence, not a
Q02 or pipeline verdict and not proof that the repaired EA is trade-capable.

## Deterministic routing and coordination

- Router task: `188013c0-504a-458a-8a15-815c6d630dc4`, priority 100,
  `triage_failure / IN_PROGRESS`, assigned to `codex`.
- Task operation:
  `repair_foreign_symbol_history_readiness_compile_and_enqueue_exact_q02_successor`.
- Bound source work item:
  `1226a3d4-6c54-4123-b31e-1b9da87b56da`.
- EA / host symbol / timeframe: `QM5_12919` / `USDJPY.DWX` / `M30`.
- Skill contract: `qm-zero-trades-recovery`; the investigation classified setup
  and implementation layers before changing any strategy mechanics.
- The router's expired spawn lease was atomically reacquired before work under
  `agent_task:188013c0-504a-458a-8a15-815c6d630dc4`, with lease interval
  `2026-08-14T20:56:20Z..2026-08-14T21:26:20Z`. No competing holder was found.
- The source card is OWNER-approved and specifies a low-frequency monthly,
  mechanical 50/50 value-momentum rank across four FX and four indices, top
  three selection, and a minimum of four eligible instruments. The repair stays
  inside the active Edge Lab mechanical, non-HFT, no-ML, no-grid, and
  no-martingale boundary.

## Bound zero-trade evidence

The retained source row is `done / ZERO_TRADES`. Its canonical evidence is:

`D:\QM\reports\work_items\1226a3d4-6c54-4123-b31e-1b9da87b56da\QM5_12919\20260808_193144\summary.json`

Evidence SHA-256:
`d18749f3dd7d3a7c3dc413323e8b308728e970b98cbdac26846ffa6d470005fe`.

The execution identity was stable during the USDJPY run:

- old MQ5 SHA-256:
  `727b65e99b9d109597a95af62d6f1e79b3cf04ed2e4dd39de0adceb4e4caa467`;
- old EX5 SHA-256:
  `7221a4ee1be4256845c4a1d18681d7cf543af4cd17f02a56c705858fd86afb2c`;
- old USDJPY setfile SHA-256:
  `b1d1498cd4c33ca8994a4041e49007292468620be4718872c2a74ae640582f2e`;
- tester INI SHA-256:
  `db866879f98368f4b848333435707dd08c64d58d1190a6b976c0a0ebe958455a`;
- report SHA-256:
  `dd7edd45166bcebba91e91fb8b6b695c68071cb5987eba01a7e48022c11b8e16`;
- actual identity: `USDJPY.DWX / M30`, real ticks, model 4,
  `2022-07-01..2022-12-31`, terminal T3;
- run status: valid `OK`, no `OnInit` failure, zero trades,
  `MIN_TRADES_NOT_MET`;
- news seed: `OK`, age 145 hours against the unchanged 336-hour ceiling.

This was not an isolated host-rank outcome. Each of the eight intended basket
symbols has at least one valid completed run, and every such representative run
produced zero trades without an initialization failure:

| Symbol | Representative work item | Valid-run trades | OnInit failure |
|---|---|---:|---|
| AUDUSD.DWX | `644ca4cd-405e-4882-a30e-173db8559ffd` | 0 | no |
| EURUSD.DWX | `58c2d393-e8eb-4f0a-8e78-e5cd21a8dc4a` | 0 | no |
| GBPUSD.DWX | `288faec4-1af3-43db-9e60-94f4d0e8834a` | 0 | no |
| GDAXI.DWX | `4ea42a49-af47-4c1d-8bc0-4cf4378a8b4d` | 0 | no |
| NDX.DWX | `8b395f6d-7361-46f3-8f72-94d7aadcfa31` | 0 | no |
| UK100.DWX | `2956e249-3a67-442b-99f0-a6220a8b9148` | 0 | no |
| USDJPY.DWX | `1226a3d4-6c54-4123-b31e-1b9da87b56da` | 0 | no |
| WS30.DWX | `0ada19d4-13a0-4fe3-a461-e1a6dcc5f823` | 0 | no |

Several separate NDX/WS30 attempts also had infrastructure failures, but they
are not used as evidence for the implementation diagnosis above.

## First failed layer and repair

The shared framework warmup call did not consume or validate the return value of
the foreign-symbol `CopyClose` request. `Strategy_RawSignals` then checked only
the current `Bars` count and returned `false` when the 1,286 required daily bars
were absent. No retry, setup failure, missing-symbol list, eligible-count event,
rank event, or entry-fire event existed. Because the strategy requires at least
four eligible instruments, this setup state could silently suppress all eight
hosts and is consistent with the cohort signature. A governed Q02 rerun remains
necessary to confirm the repaired runtime path.

Commit `99c0b8a5b` applies the minimal same-lineage repair:

- compute the exact D1 requirement as skip 21 + max(252, 1260) + 5 = 1,286;
- retry `CopyClose` once per symbol/day until the required depth is available;
- enumerate missing symbols and emit registered `STRATEGY_DIAG` events;
- fail closed in `OnInit` with registered `SETUP_DATA_MISSING` when fewer than
  four basket symbols are ready;
- emit bounded monthly `STRATEGY_STATE` rank-selection evidence and
  `ENTRY_SIGNAL_FIRE` when an entry request is created;
- preserve the 21/252/1260 lookbacks, 50/50 score, top-three selection,
  four-symbol eligibility floor, monthly cadence, exits, stops, and sizing.

Current artifact bindings:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `c729116f626f7c6b2d930a160a070b3319f198f2a565ad5310c4d49dfa53526a` |
| EX5 | `6e915491196f60baf3d4fa98d900495be6aed295dd37605d3b6c65a6024383f9` |
| USDJPY M30 set | `02f18620b8b7044e462194632e6bbe9eb7c42860cbbf44aa2a80c0dca3445e0d` |

All eight setfiles retain `RISK_FIXED=1000`, `RISK_PERCENT=0`, registered slots
0 through 7, and the unchanged M30 identity.

## Focused verification

- History-readiness contract tests: PASS, `2 passed`.
- Strict MQL5 compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260814_210447\QM5_12919_amp-value-momentum-xasset.compile.log`.
- Compile-log SHA-256:
  `7dd803c0bd0bebb812d53d23b3d8fbfeece202ea25f8da43e4844baa52644cf4`.
- EA-scoped strict build check: PASS, 0 failures, 0 warnings.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260814_210447.json`.
- Build-check SHA-256:
  `1979a46af6649cd850dd14eeac67c602a44c5b2d8d3e4a3b8469fea7eb94a977`.
- Build guardrails: PASS across the EA directory, nine files checked, zero
  findings; `qm_news_stale_max_hours` remains at or below 336.
- Symbol-scope validator: `SINGLE_SYMBOL_OK`, zero violations.
- No local or manual MT5 test was started.

## Q02 admission refusal

The orchestration worktree's older enqueue parser did not accept Q02 and made no
mutation. No legacy phase label was substituted. The current canonical Q-only
controller was then invoked with the retained predecessor and the current EX5
binding. It refused before queue mutation with:

```text
blocked=true
reason=factory_off
factory_off_flag=D:\QM\strategy_farm\state\FACTORY_OFF.flag
factory_off_sha256=eb7a70957e15485be33d05f16add3fd84ce7c18d6273ee0b6d21a9208b57f071
```

The flag records `state=OFF_INCOMPLETE`, `off_at=2026-08-14T20:49:23Z`, and
`updated_at=2026-08-14T20:50:34Z`. It also retains the maintenance quiescence
evidence path
`D:\QM\reports\maintenance\factory_off\mnt046_factory_off_quiescence_20260814T204923Z_17168.json`.
The guard remains authoritative even though its verification records stable
quiescence; its incomplete cleanup state was not interpreted as permission to
restart or mutate the factory.

At `2026-08-14T21:08:41Z`, the source row still read
`done / ZERO_TRADES`, and no pending or active QM5_12919 successor existed. When
an authorized factory-on workflow clears the guard, the exact append-only Q02
request must remain bound to:

- predecessor `1226a3d4-6c54-4123-b31e-1b9da87b56da`;
- symbol/timeframe `USDJPY.DWX / M30`;
- expected EX5 SHA-256
  `6e915491196f60baf3d4fa98d900495be6aed295dd37605d3b6c65a6024383f9`;
- current MQ5 and setfile hashes listed above;
- `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- append-only historical preservation.

## Zero-trades recovery record

| EA | Bound run | Root cause | Repair | Compile | Entry events | Trades | Remaining gaps |
|---|---|---|---|---|---:|---:|---|
| QM5_12919 | `1226a3d4`, USDJPY.DWX M30, 2022-07-01..2022-12-31 | Unverified one-shot foreign D1 warmup plus silent insufficient-history eligibility failure; cohort-wide across all eight hosts | Exact-depth bounded retry, fail-closed initialization, missing-symbol/readiness/rank/entry diagnostics; mechanics unchanged | PASS, 0 errors / 0 warnings | Old build: not instrumented; repaired build: pending Q02 | Old build: 0; repaired build: pending Q02 | Factory guard must be cleared by the authorized workflow, then one exact hash-bound Q02 successor must run and produce valid diagnostic/trade evidence |

## Safety boundary

`FACTORY_OFF` was not removed or weakened. No terminal was launched, stopped,
or interrupted; no T1-T10 run was touched. No `T_Live` file or process,
AutoTrading setting, live setfile, deploy manifest, portfolio gate, or portfolio
artifact was changed. No pipeline verdict was created.

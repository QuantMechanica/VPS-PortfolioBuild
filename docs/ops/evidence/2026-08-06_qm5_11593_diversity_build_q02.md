# QM5_11593 diversity build and Q02 handoff

Date: 2026-08-06

Branch: `agents/board-advisor`

Agent task: `e0029184-b913-477b-a93b-c46a07c72a39`

Build task: `7a5b3aa7-7537-4f55-ad41-a2751ece76b4`

## Outcome

`QM5_11593_robo-midnight-hammer-adx-d1` was rebuilt mechanically from its
OWNER-approved Strategy Card and handed to staged Q02. It is a structural,
low-frequency D1 rejection-candle edge registered on six FX hosts:
`EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `USDJPY.DWX`, `NZDUSD.DWX`, and
`USDCAD.DWX`.

The approved lineage is RoboForex Educational Team, *Forex Strategy
Collection* (~2015), “Midnight,” pages 109–110. The repository card copy is
line-for-line identical to
`D:\QM\strategy_farm\artifacts\cards_approved\QM5_11593_robo-midnight-hammer-adx-d1.md`.

## Selection and collision control

- The canonical farm DB was used:
  `D:\QM\strategy_farm\state\farm_state.sqlite`.
- Dry-run priority and ready-card inventory ranked this card at `10.19`. It was
  the first standard-build-eligible, nonduplicate, reputable-source,
  low-frequency structural FX card after excluding higher rows whose symbols
  are unavailable, mechanics are high-frequency/nonstructural, source checks
  failed, or cards explicitly duplicate an existing EA.
- No task, work item, or active agent claim existed for `QM5_11593` before the
  claim. Claim key:
  `manual:codex:agents/board-advisor:QM5_11593:q01-build-q02-handoff:20260806T112703+0000`.
- Pre-claim DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11593_build_claim_20260806T112703+0000.sqlite`.
- Pre-record DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11593_record_build_20260806T114856Z.sqlite`.
- Pre-review race-repair DB backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_11593_pre_review_race_repair_20260806T115814Z.sqlite`.
- The existing deterministic rows were activated: magic `115930000` through
  `115930005`, slots 0 through 5 in card order. The sanctioned resolver
  generator produced registry SHA-256
  `ECDA31F4237FCCF1B1181825EE18369A3FF5FA575A5D16AADFA82BD3CFA488E8`,
  equal to the current `magic_numbers.csv` hash.

## Mechanical implementation

- Signal bar: completed D1 bar only, advanced behind the single framework
  `QM_IsNewBar()` gate.
- Long: lower tail at least 3 times the real body; upper tail at most half the
  lower tail; ADX(14) > 20; `+DI > -DI`; `+DI > 20`; `-DI < 20`.
- Short: exact mirrored candle and DI conditions.
- Entry: market at the next D1 open, one position per magic.
- Stop: signal-bar low for longs and high for shorts.
- Exit: fixed 2R server target or the next D1 open (the executable end of the
  entry day), with no trailing, break-even, partial close, grid, martingale,
  adaptive parameter, or ML behavior.
- EMA(24) remains context-only because the card supplies no mechanical EMA
  condition.
- News filters gate entries only. MAE sampling, kill-switch handling, Friday
  close, position management, and exit handling remain ahead of the news gate.
- Static post-build audit caught and corrected an entry-request slot default:
  `req.symbol_slot` now uses `qm_magic_slot_offset`, so all six hosts resolve
  their own registered magic instead of only slot 0.

## Build evidence

| Check | Result | Evidence |
|---|---|---|
| Approved card / SPEC | PASS | exact card copy; `validate_spec_doc.py`: 1 PASS, 0 FAIL |
| Build guardrails | PASS | no findings across seven checked files |
| Symbol scope | PASS | `SINGLE_SYMBOL_OK`, zero foreign-symbol references |
| Final framework build check | PASS, 0 failures, 0 warnings | `D:\QM\reports\framework\21\build_check_20260806_115127.json` |
| Final compile | PASS, 0 errors, 0 warnings | `D:\QM\reports\compile\20260806_115127\summary.csv` |
| Final EX5 | PASS | SHA-256 `D85144FD5E15E8C2891A6DFC1A25B5B48B47B7E1DFEBCA3C02773E6AC50A2ACD` |
| Fixed-risk setfiles | PASS | six D1 files; `RISK_FIXED=1000`, `RISK_PERCENT=0`, slots 0–5 |
| Farm DB integrity | PASS | `PRAGMA quick_check = ok` after build record and Q02 enqueue |

The canonical build result is
`D:\QM\strategy_farm\artifacts\builds\7a5b3aa7-7537-4f55-ad41-a2751ece76b4.json`.
The build task reached `done` at `2026-08-06T11:49:05Z`. During the final
compile, the pre-review gate sampled the EX5 path while MetaEditor was replacing
the file and transiently blocked the row as
`pre_review_not_reviewable:missing_ex5_path`. A guarded repair required the
exact blocked reason and a fresh `_pre_review_ready=true` result, then restored
the single build row to `done` at `2026-08-06T11:58:19Z`. No pipeline evidence
or terminal result was rewritten.

## Smoke infrastructure and CPU ceiling

One bounded smoke invocation was dispatched while the farm reported seven
running terminals / seven active work items. T4 returned four harness-level
invalid attempts with `NO_HISTORY;INCOMPLETE_RUNS`: empty expert and symbol,
M0/1970 period, zero bars, and explicit no-history log markers. The deployed
EX5 and setfile identities were stable and matching, no `OnInit` failure was
detected, and Model 4 was present. This is infrastructure evidence, not a
zero-trade strategy result:

`D:\QM\reports\smoke\QM5_11593\20260806_113953\summary.json`

During post-processing the fleet independently rose to
`terminal64_running_count=8`; the later verification observed nine active work
items. No retry or further tester run was launched. The standard
`record-build` framework-error rule preserved the diagnostic as
`build_smoke_framework_error`, normalized the clean build to
`deferred_p2_smoke`, and allowed Q02 to own the next available capacity. After
the slot correction, only static checks and compilation were repeated; the
final EX5 above was not re-smoked at the ceiling.

The farm scheduler did claim the initially enqueued AUDUSD row while the final
static correction was being compiled. That row remains immutable and produced
a real Model-4 Q02 PASS on the prior EX5 hash
`FF35C1DAF77D6494A7E6CE309951E3E9270FD71FDB2EAC487433EC118FEBEBFF`:
26 trades, profit factor 1.02, and net profit 273.02 over
`2018-07-02` through `2022-12-31`. Because the final slot-binding correction
changed the EX5 identity, the old PASS was not reused as proof for the final
binary. A guarded append-only Q02 rerun was created with expected EX5 SHA-256
`D85144FD5E15E8C2891A6DFC1A25B5B48B47B7E1DFEBCA3C02773E6AC50A2ACD`.

## Q02 state

The first three-symbol FX wave was auto-enqueued with `priority_track=true`:

| Symbol | Q02 work item | State at final verification |
|---|---|---|
| EURUSD.DWX | `6cd97590-1ff1-48f1-9a37-ff3c8a045073` | pending |
| GBPUSD.DWX | `d3749867-389b-440d-a10a-0168e80e60fd` | pending |
| AUDUSD.DWX (immutable prior binary) | `672d29b9-6c2a-48ab-a659-8e14fef29d12` | PASS, old EX5 binding retained |
| AUDUSD.DWX (final binary) | `77bc36af-2e96-4cb1-95b0-5f10c59b7d5e` | active on T7, final EX5 binding |

`USDJPY.DWX`, `NZDUSD.DWX`, and `USDCAD.DWX` are durably recorded as the
second wave in
`D:\QM\strategy_farm\state\q02_deferred_symbols.json`, tied to this build
task and a six-symbol cohort.

The farm's deterministic artifact auto-commit `bd04933f1` captured the initial
EX5, six generated setfiles, and activated shared registry/resolver rows while
this paced unit was still in progress. The final scoped commit carries the
mechanical source, corrected EX5, refreshed setfile hashes, SPEC, approved-card
copy, and this evidence without staging any unrelated fleet work.

## Safety boundary

No T_Live file, AutoTrading state, deploy manifest, live setfile, portfolio
gate, portfolio-admission artifact, or phase beyond the normal Q02 enqueue was
touched.

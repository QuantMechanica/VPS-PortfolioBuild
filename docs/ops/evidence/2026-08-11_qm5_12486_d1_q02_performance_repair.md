# QM5_12486 D1 Q02 performance repair and canary handoff

Date: 2026-08-11
Branch: `agents/board-advisor`
EA: `QM5_12486_shv-supertrend`
Scope: one approved diverse-sleeve Q02 infrastructure repair

## Selection and claim

The live farm had no open build-backlog task, so this unit used the mission's
second priority: repair a built, diverse EA stuck at Q02 for infrastructure
rather than add build volume.

- Approved card:
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_12486_shv-supertrend.md`
- Card state: `g0_status: APPROVED`; R1-R4 all PASS.
- Source: Shashank Vemuri's public GitHub `Finance` SuperTrend implementation,
  source ID `af7930c8-6c65-52d1-9c01-040490b5ad39`.
- Mechanics: deterministic SuperTrend band flips, no ML, grid, martingale, or
  pyramiding; expected frequency 16 trades/year/symbol.
- Approved universe: four FX pairs plus XAUUSD, NDX, and WS30. This repair
  advances forex evidence instead of adding another index/metal/energy build.

The distinct farm claim was created before editing:

- Agent task: `4a315185-e758-4ac9-b5f5-cffedc291c7b`
- Type/state at claim: `q02_infra_repair` / `IN_PROGRESS`
- Assigned agent: `codex:agents/board-advisor`
- Source diagnostic row: `4cd386db-1c17-4bf7-8386-8290cb764f07`
- Claim backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12486_q02_repair_claim_20260811T150945Z.sqlite`

No competing agent claim existed for this EA.

## Reproducible diagnosis

The latest completed EURUSD diagnostic row,
`aab4cfcf-4687-492d-812f-908f818e4bd2`, retained real MT5 evidence at:

`D:\QM\reports\work_items\aab4cfcf-4687-492d-812f-908f818e4bd2\QM5_12486\20260811_143908\summary.json`

Evidence SHA-256:
`ad4262f110ede67c025cf032ed2401a0031433943094e55494defaad90032b1b`.

The report records:

- `TIMEOUT;INCOMPLETE_RUNS` after 1,800 seconds;
- Model 4, one six-month prescreen, zero-byte report;
- no OnInit failure and a healthy news-calendar bundle;
- stable source/deployed EX5 SHA-256
  `17a5dc68f0f2f9cc4e1587ec120eef1592748b19b644086de3ba58ee8ac0b48a`;
- H1 tester period and an H1 setfile, although the approved card explicitly
  requires evaluation once per completed D1 bar.

The source explained the repeatable timeout. While a position was open, the
exit hook rebuilt a 200-bar recursive SuperTrend state on every modeled tick.
Each reconstruction performed a framework ATR buffer read and three raw series
reads per historical bar. The spread filter also read ATR on every tick. This
was a deterministic hot-path/setup defect, not an economic strategy verdict.

## Repair

The strategy mechanics and defaults remain unchanged. The implementation now:

- reconstructs SuperTrend direction and ATR(20) once per completed D1 bar;
- caches `dir@1`, `dir@2`, and the emergency-stop ATR for O(1) per-tick exit,
  spread, and entry hooks;
- latches `QM_IsNewBar(_Symbol, PERIOD_D1)` exactly once per tick;
- uses explicit completed D1 series throughout and rejects non-D1 tester/chart
  configurations during initialisation;
- records open-position MAE through the V5 framework hook; and
- preserves opposite-flip close/reversal behavior and the one-position rule.

Configuration was brought back to the approved identity:

- the seven existing magic rows were advanced from `reserved` to `active`;
- `QM_MagicResolver.mqh` was deterministically regenerated from the registry;
- seven obsolete H1 presets were removed;
- seven D1 backtest presets were generated with explicit strategy inputs,
  registered symbol slots, `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`; and
- a canonical Q01 `SPEC.md` was added.

Final registry SHA-256 embedded in the resolver:
`3D5A14950A5A03F9958F51E5099CD8E65D877D08D28D3AF2D983759DD7B6112A`.
The generated resolver contains 15,872 rows.

## Build verification

- MQ5 SHA-256:
  `37a888d3778ca286779c542df8cb1575aee3b429bdececd754f3e04d9826a8ab`
- EX5 SHA-256:
  `1914888fa9340346209655c547dcd766c6cb92cd4d054c3827482fe117a73fbc`
- Build commit:
  `f6f35f2b77c37bb48db9462314368f400642f792`
- Strict compile: PASS, 0 errors, 0 warnings.
  - Log:
    `C:\QM\repo\framework\build\compile\20260811_153322\QM5_12486_shv-supertrend.compile.log`
  - Log SHA-256:
    `bf608a6b9667209cbef7e528e69a5bd6c0a8cdc2385d945f79882476fd5f5a5b`
- EA-scoped strict build check: PASS, 0 failures, 0 warnings.
  - Report:
    `D:\QM\reports\framework\21\build_check_20260811_153416.json`
  - Report SHA-256:
    `218fec07d3e2538f126830621246743061b3b3639277eb78eea89a3073036b7a`
- Build-guardrail validation: PASS, no findings across eight EA artifacts.
- SPEC validation: PASS.
- Symbol-scope validation: `SINGLE_SYMBOL_OK`, zero leaks.
- Registry and generated-resolver hashes remained stable across the final
  strict compilation.

The final EURUSD D1 canary setfile SHA-256 is
`d6a7a6e3ff4a4c3badc69a8fbd1bc00e26c28a037ed6ffe81ec7eef7fd98f0ad`.

No manual smoke test or backtest was started.

## Paced Q02 handoff

The binding capacity check was below the configured seven-job ceiling:

- executing factory terminals: `T1`, `T5`;
- active backtest work items: 4;
- non-factory terminals were excluded and untouched.

The follow-up slot scan remained below the ceiling (`T1`, `T5`, `T6`), and
the final verification found three active work items.

GBPUSD was already owned by T5 under its stale H1 identity. To avoid colliding
with that work, the canary uses EURUSD, whose latest H1 row was terminal
`INFRA_FAIL` and unclaimed.

All retained terminal rows describe H1 setfile identities. The governed exact-
row rerun helper intentionally preserves that identity, so it could not be used
to mislabel an H1 row as D1. One new, explicitly hash-bound D1 identity was
therefore appended under the shared factory mutation lock and a SQLite
`BEGIN IMMEDIATE` transaction. The transaction revalidated the agent claim,
source evidence, fixed-risk contract, capacity, current hashes, and absence of
another open EURUSD row before insertion.

That pre-commit seed was `183e7fee-a989-42e0-af6e-76856e3e3167`. Between
insertion and claim, the shared worktree's uncommitted EX5 reverted to the old
HEAD bytes. The dispatch preflight correctly refused the mismatch before MT5
started and preserved an `INFRA_FAIL` record:

- Evidence:
  `D:\QM\reports\work_items\183e7fee-a989-42e0-af6e-76856e3e3167\QM5_12486\Q02\preflight_failure.json`
- Evidence SHA-256:
  `20561cad3a36e73462f4d475a3e9635387ce5bc1c21300f586aef996507c4372`
- Reason: `staged_ex5_preflight_failed`; expected `69619758...`, observed the
  old `17a5dc68...`; no tester process was launched for this row.

The final binary and presets were then rebuilt, build-checked, and committed.
The public governed append-only rerun command preserved the failed preflight
row and created the final successor:

- Final work item: `171a5cfd-f696-4836-bffd-696e4c15c186`
- Phase/symbol: Q02 / `EURUSD.DWX`
- Initial state: `pending`, unclaimed, attempt 0
- Open-row count immediately after insertion: 1
- Append-only predecessor: `183e7fee-a989-42e0-af6e-76856e3e3167`
- Original H1 diagnostic row retained through the repair lineage:
  `aab4cfcf-4687-492d-812f-908f818e4bd2`
- Expected period: D1
- Expected EX5 SHA-256:
  `1914888fa9340346209655c547dcd766c6cb92cd4d054c3827482fe117a73fbc`
- Expected setfile SHA-256:
  `d6a7a6e3ff4a4c3badc69a8fbd1bc00e26c28a037ed6ffe81ec7eef7fd98f0ad`
- Pre-enqueue online backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_12486_d1_q02_enqueue_20260811T152919Z.sqlite`

The paced farm owns claim and execution. No pump, dispatch tick, terminal
reservation, process control, or additional symbol enqueue was requested.

## Safety

- No `T_Live` file, terminal, manifest, or AutoTrading state was changed.
- No live setfile or deploy manifest was created or edited.
- No portfolio-admission gate, Q08 contribution, or portfolio KPI artifact was
  changed.
- Existing unrelated worktree changes were preserved and excluded from this
  unit.

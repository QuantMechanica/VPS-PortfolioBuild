# QM5_20233 XAU/XAG skew-rank Q02 performance repair — 2026-08-17

## Disposition

`REPAIR_COMPILED_AND_ENQUEUED`: the monthly market-neutral XAU/XAG skewness
rank was blocked at Q02 by a deterministic Model-4 hot path, not an economic
verdict. The EA was rebuilt in place with cached registered magics and
event/D1-gated pair management. One current-binary append-only Q02 row is
pending for the governed scheduler.

This record is implementation evidence only. It does not infer a Q02 result,
advance a later gate, or authorize live use.

## Selection and claim

- Branch: `agents/board-advisor`.
- Farm claim: `746e77c0-a07b-48de-be95-be61dcaf14e1`, routed atomically to
  `codex` in state `IN_PROGRESS` before the code change.
- Pre-mutation online SQLite backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_20233_q02_perf_claim_20260817T024837Z.sqlite`.
- Backup SHA-256:
  `389bea15dfc708d3d07489b6c8a247b8eb19d1c48f9061635ae752cec0ee22f1`.
- Approved card:
  `strategy-seeds/cards/approved/QM5_20233_xauxag-skew-rank_card.md`.
- Source lineage: Fernandez-Perez, Frijns, Fuertes, and Miffre (2018),
  *Journal of Banking & Finance* 86, 143-158, DOI
  `10.1016/j.jbankfin.2017.06.015`; the approved card records R1-R4 PASS.
- The strategy is a deterministic prior-twelve-complete-month Pearson
  skewness rank with opposite XAU/XAG legs. It uses no ML, adaptive threshold,
  banned indicator, price-ratio convergence, or external runtime data.

The higher-ranked approved FX build candidate `QM5_36005` could not enter the
build lane because its deterministic magic rows and generated resolver entries
do not exist. Existing diverse FX repairs were either already queued or had
already been completed on this branch. `QM5_20233` was therefore the highest
eligible non-duplicate structural repair: it adds a monthly market-neutral
construction rather than another outright metal direction.

## Immutable failure evidence and diagnosis

All twelve terminal Q02 rows for `QM5_20233` ended `INFRA_FAIL`; there is no
Q02 economic PASS/FAIL or zero-trade verdict. The exact repair anchor is:

- Work item: `92235bb9-1fc0-4aeb-90c3-f8771ca9e2bd`.
- Final state: `done / INFRA_FAIL`.
- Bound expert: `QM\QM5_20233_xauxag-skew-rank` on `XAUUSD.DWX`, D1,
  2018-07-02 through 2022-12-31, Model 4.
- Failure: `TIMEOUT;INCOMPLETE_RUNS` after exactly 25,200 seconds.
- Summary:
  `D:\QM\reports\work_items\92235bb9-1fc0-4aeb-90c3-f8771ca9e2bd\QM5_20233\20260816_043334\summary.json`.
- Summary SHA-256:
  `11789c853f925d365d9c4dec7c94c2f0bdf3e6fccdcc5ebad4f0026440316098`.
- Historical identities: MQ5
  `d0db22a75354e947a2715eda3145f0438e42a572332c0e0f5688a21b6f00f4c2`,
  EX5 `333090607990beb707dab86c49824d77932f6c1a338fdea14a0569bcb7c87c8a`,
  setfile `335d39a2ea55be7eddb69d7d8e9a0cd1dd7fa7445118ad396da73e876241ae64`.

The preserved tester journal shows valid two-leg entries, closes, and hard
stops, excluding ONINIT, missing-history, and zero-trade explanations. The
source hot path was:

`OnTick -> Strategy_ManageOpenPosition -> pair position scans -> Strategy_IsPairPosition -> QM_MagicChecked`

While a package was open, multiple scans ran on every real tick. Each
alternating XAU/XAG `QM_MagicChecked` call linearly inspected the generated
16,110-row magic registry (including symbol validation), so its one-entry
cache could not help across alternating slots. This multiplied registry work
by Model-4 tick count and explains the repeated multi-hour timeouts.

## Minimal repair

- Resolve and validate magic `202330000` and `202330001` once during `OnInit`;
  fail closed if either mapping is absent or collides.
- Compare positions and deal history against those cached immutable values.
- Run package-composition, month-renewal, and max-hold management on D1 bars,
  plus an immediate pending pass after any XAU/XAG trade transaction.
- Keep the transaction latch active after entries, broker stops, closes, and
  rollback events so orphan repair remains prompt without a per-tick registry
  walk.

The completed-month formation, Pearson estimator, lower-skew-long direction,
monthly attempt state, package sizing, ATR stops, month renewal, 35-day stale
exit, symbols, magic slots, spreads, news policy, Friday policy, and all frozen
inputs are unchanged. This is an execution-performance repair, not a strategy
enhancement.

## Build and static verification

- Build prerequisite guard: PASS for EA registry, magic registry, and EA dir.
- Pre-compile strict static check: PASS, 0 failures, 0 warnings;
  `D:\QM\reports\framework\21\build_check_20260817_025235.json`, SHA-256
  `8c7cccccd4fa8a6aeb36bff683ddf5b09d92b163d42d508f2662c912cb790f60`.
- Single strict MetaEditor compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260817_025253\QM5_20233_xauxag-skew-rank.compile.log`,
  SHA-256
  `2d63ca6ead6ca839e4bb7abd9713e3ea243878a919deed8015ec9a9da8f94f0a`.
- Final strict build report: PASS, 0 failures, 0 warnings;
  `D:\QM\reports\framework\21\build_check_20260817_025253.json`, SHA-256
  `89b243d222069c13b8707f019555d278eee9d623854871977025f8b7f712ad4e`.
- SPEC validator: PASS.
- Current MQ5 SHA-256:
  `733a0ab8640735cd9b5833e51d47721097383747e5a908a777e1826316aa6c46`.
- Current EX5 SHA-256:
  `01efa1b4515f1ae63bb335aa1b348ee465a30c25fb62e241432a10d2d9ca28aa`.
- Current setfile SHA-256:
  `3a48d413cb84ae3bf549145e545012464d3947ed23cc7e48e0556f43dd4d16b3`.
- The sole research set remains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, logical basket
  `QM5_20233_XAU_XAG_SKEW_RANK_D1`, host `XAUUSD.DWX`, D1.

## Append-only Q02 handoff and capacity stop

`farmctl enqueue-backtest` authenticated the repaired binary against the
terminal source row, preserved that source, hash-bound its evidence, and
created exactly one successor:

- New work item: `46374352-ee77-4c40-a032-e3cd6e59b00a`.
- State at handoff: `pending`, unclaimed, Q02.
- Source row: `92235bb9-1fc0-4aeb-90c3-f8771ca9e2bd`.
- Execution identity: `QM\QM5_20233_xauxag-skew-rank`, host
  `XAUUSD.DWX`, D1, logical two-leg basket.
- Payload seals the current MQ5, EX5, and setfile hashes listed above and
  records `repaired_infra_rerun=true`, `risk_fixed=1000`, `risk_percent=0`.

At the execution decision, `farmctl mt5-slots` reported eight active factory
terminals (`T1`, `T2`, `T4`, `T5`, `T6`, `T7`, `T8`, `T10`) and ten running
`terminal64.exe` processes in total. This is the backtest CPU ceiling.
Therefore no smoke, manual terminal launch, `dispatch-tick`, or wait was
performed. The pending row is left to the scheduler's capacity controls; its
eventual Q02 result is the first dynamic proof of the performance repair.

No `T_Live` file, process, manifest, portfolio gate, AutoTrading state,
deployment state, or terminal configuration was changed.

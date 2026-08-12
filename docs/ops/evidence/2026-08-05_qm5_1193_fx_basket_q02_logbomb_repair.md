# QM5_1193 FX-basket Q02 log-bomb repair — 2026-08-05

## Disposition

`REPAIR_COMPILED_AND_ENQUEUED`: the diverse D1 USD stress-rebound basket was
blocked at Q02 by infrastructure evidence, not by an economic verdict. The EA
has been rebuilt with bounded symbol setup, and one current-binary USDCAD Q02
canary is pending under the governed farm scheduler.

This record is implementation evidence only. It does not infer a Q02 result or
authorize any later phase or live use.

## Scope and claim

- Branch: `agents/board-advisor`.
- Farm claim: `c0f97dbc-e25e-40b8-ab8e-33c722e0c509`, state
  `IN_PROGRESS`, assigned to `codex:agents/board-advisor` before editing.
- Pre-mutation online SQLite backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_1193_q02_logbomb_claim_20260805T141243Z.sqlite`.
- Approved card:
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_1193_qp-stress-usd-rebound.md`.
- Card lineage: Dujava/Quantpedia (2024), supported by
  Lustig-Roussanov-Verdelhan (JFE, 2014); fixed SP500-plus-oil stress trigger,
  five fixed FX legs, no ML/adaptive/banned indicator mechanics.
- Host basket: `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, `USDJPY.DWX`,
  `USDCAD.DWX`; signal inputs `SP500.DWX` and `XTIUSD.DWX`; D1 only.

No open work item or competing agent claim existed for `QM5_1193` when the
claim was inserted. The source, magic registry allocations and setfiles were
already present. No setfile parameter or approved signal threshold changed;
the standard strict build refreshed only the `build_hash` header in the five
backtest and five matching live setfiles.

## Immutable failure evidence and diagnosis

The newest USDCAD source row remains preserved:

- Q02 work item: `edeb19ad-7f0b-4dbc-88a2-711a87195887`.
- Final state: `done / INFRA_FAIL`, attempt 99.
- Log-bomb evidence:
  `D:\QM\reports\work_items\edeb19ad-7f0b-4dbc-88a2-711a87195887\log_bomb_evidence.json`.
- Evidence SHA-256:
  `c758d573116e9797dbc22b358fa543223539cb1bb537ee6c305e3589645b3c36`.
- Guard observation: 18.5 GB tester journal against the 4 GB absolute cap;
  T1 was stopped at `2026-08-03T20:14:42Z` and the oversized journal was
  reclaimed by the guard.
- Durable dispatcher log:
  `D:\QM\strategy_farm\logs\work_item_edeb19ad-7f0b-4dbc-88a2-711a87195887.log`,
  SHA-256
  `24324355fd2305fb377f8f358cb09885de404bb3b81b50449ef9de5265ea4d39`.
  It records a 463,688-byte valid report latch before the final log-bomb
  classification, confirming that this is an execution/evidence failure and
  not an economic verdict.

The EA contains no direct `Print`, `PrintFormat` or `Comment` call. Its only
unbounded cross-symbol setup path was:

`OnTick -> Strategy_NoTradeFilter -> Strategy_SelectSymbols -> SymbolSelect`

That path selected the five host legs, SP500 and XTI on every tester tick (and
also attempted the optional Brent fallback), although the strategy evaluates
entries only once per D1 bar. The EA also read foreign-symbol D1 history
without registering a basket symbol guard or running the framework basket
warmup. This is the implementation/setup defect targeted by the repair; the
reclaimed raw journal prevents a claim about the exact repeated terminal
message text.

## Minimal repair

- Replaced per-tick symbol selection with one `Strategy_InitSymbols` call
  after successful `QM_FrameworkInit`.
- Required legs plus SP500/XTI are selected once, registered with
  `QM_SymbolGuardInit`, and warmed once with `QM_BasketWarmupHistory` on D1.
- `XBRUSD.DWX` remains a card-permitted best-effort fallback but is neither a
  phantom required symbol nor a reason for `OnInit` failure when absent.
- Cross-symbol reads now assert the registered universe; the no-trade hook
  reads only the cached setup-ready flag.
- Restored binding framework order in `OnTick`: MAE sampling first, then kill
  switch, Friday close, no-trade hook, management/exits, entry-only news gate,
  new-bar gate and entry. `QM_EntryRequest` is zero-initialized.
- The standard build refreshed the ten setfile `build_hash` comment values;
  their executable parameters are byte-for-byte unchanged.

The stress trigger, directions, basket membership, ATR stop, exits, magic
slots, news policy, risk values and gate thresholds are unchanged.

## Build and static verification

- Single MetaEditor compile, invoked by
  `framework/scripts/build_check.ps1 -EALabel QM5_1193_qp-stress-usd-rebound -Strict`:
  compiler `PASS`, 0 errors, 0 warnings. The combined invocation initially
  stopped at five static raw-series policy findings; the fixed-shift bespoke
  structural reads were documented with the repository's `perf-allowed`
  annotations before the non-compiling static rerun.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260805_141804\QM5_1193_qp-stress-usd-rebound.compile.log`,
  SHA-256
  `de9dd04d7ce5a82163d73fe197dfb675926250dc912d74d97e4db8439e8dd85d`.
- Final strict static pass used `-SkipCompile` to preserve the one-compile
  discipline: 0 failures, 2 advisory warnings.
- Static report:
  `D:\QM\reports\framework\21\build_check_20260805_142105.json`, SHA-256
  `c36c882139d718fae3c5762a0fe48272eb3e1dad77169eadf1702a58f0dcc42d`.
- Both advisories are conservative `.DWX` spread heuristics. The historical
  zero-spread branch skips degenerate samples, producing a zero median that
  explicitly allows entry; the current zero-spread branch also explicitly
  returns `true`. Neither blocks `.DWX` entries.
- Repaired MQ5 SHA-256:
  `f47fff6c63b8e2af57a1da820a3c07a93f4f61bf08a9c2f42277b7008f4b83ec`.
- Rebuilt EX5 SHA-256:
  `003efc478c93c59cfb058516e9004e221b5eb9162361ac85bcc90d0096cebaa3`.
- All five backtest setfiles remain `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Governed Q02 canary

The bound log-bomb row correctly refused reuse after the MQ5 identity changed
(`historical_artifact_binding_mismatch`). No row was mutated or inserted by
that refused call. The governed `seed-fresh-q02` path instead used preserved
pre-binding USDCAD row `f0368fe7-5643-4e88-9b86-61e2c8554b2c` as the exact
EA/symbol/setfile provenance anchor.

- New work item: `9a70b373-bc30-459a-af13-a0ad7637baeb`.
- Initial state: `pending`, unclaimed, Q02, `USDCAD.DWX`, D1.
- Expert identity: `QM\QM5_1193_qp-stress-usd-rebound`.
- Test window: 2015-01-01 through 2024-12-31.
- Expected MQ5/EX5 hashes: the repaired hashes above.
- Setfile:
  `framework/EAs/QM5_1193_qp-stress-usd-rebound/sets/QM5_1193_USDCAD.DWX_D1_backtest.set`.
- Setfile SHA-256:
  `a2e006121f1b91a31b3bc7b25b8dd91befb54b3645a0383060379d48de078f3e`.
- Fixed-risk seal: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Historical rows remain immutable; this is one fresh append-only canary, not
  a five-symbol fanout.

At the enqueue decision, `farmctl mt5-slots` reported seven running
`terminal64.exe` processes and five active managed pipeline terminals. That is
the backtest CPU ceiling. Therefore no smoke, manual terminal launch,
`dispatch-tick`, wait, or second canary was performed. The pending row is left
to the scheduler's existing capacity controls.

No T_Live file, process, manifest, portfolio gate, AutoTrading state, deploy
state or terminal configuration was changed.

# QM5_13148 energy-rank data-contract recovery and Q02 handoff

Date: 2026-08-13

Branch: `agents/board-advisor`

Router task: `97cf24af-ecc1-49a3-b911-e943880c90e3`

EA: `QM5_13148_energy-rank-lmh`

Status: Q01 strict build PASS; generation-2 build recorded `done`; one
append-only, current-binary Q02 work item pending; no Q02 verdict claimed

## Outcome

The OWNER-routed Claude decision authorized one same-lineage data-contract
repair because the approved `2017-01-03` normalization origin predates both
canonical DWX energy histories. The card, EA, setfile, and basket manifest now
lock `2017-10-02`, the first common available XTIUSD.DWX/XNGUSD.DWX date. The
hand-rolled monthly key was replaced with the framework calendar helper, the
EA rebuilt cleanly, and exactly one fresh Q02 row was appended on the full
canonical multi-symbol window.

The rank direction, monthly cadence, 20-bar warm-up, seven-day anchor bound,
ATR stops, 40-day exit, package construction, risk, and all other strategy
mechanics and parameters are unchanged. This is a build/recovery handoff, not
evidence that the strategy trades or has an edge.

## Authority and preflight

- Router verdict: rebind the unsatisfiable origin to `2017-10-02` with full
  available history, preserve mechanics, recompile, append one Q02 row, and
  keep the work off `main`.
- Approved card:
  `D:\QM\strategy_farm\artifacts\cards_approved\QM5_13148_energy-rank-lmh.md`;
  `g0_status: APPROVED` and EA ID `QM5_13148`.
- Active magic identities:
  - slot 0, `XTIUSD.DWX`, `131480000`;
  - slot 1, `XNGUSD.DWX`, `131480001`.
- The registry evidence for both energy feeds records the same head timestamp,
  `1506906007xxx` ms, on 2017-10-02.
- Backtest contract remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `qm_news_stale_max_hours=336`.

## Bound zero-trade evidence and first failed layer

| Q02 work item | Window | Result | Bound artifacts |
|---|---|---|---|
| `ce2bf983-059f-446f-ac69-f02b4a5f594d` | 2018-07-02 through 2022-12-31 | `FAIL / MIN_TRADES_NOT_MET`, 0 trades, no initialization failure | legacy pre-binding row; summary SHA-256 `e0f295ee2b4b6d6e5b6073925e39b9572fcba8f59bf90b41d95b97752df10668` |
| `f3299c06-4cde-4c3d-93d5-be613ee2436a` | 2018-07-02 through 2022-12-31 | `ZERO_TRADES`, 0 trades, no initialization failure | MQ5 `f5b537ae85887ad3facf4e8b6e35e262fb67ddf37e8b5417ce4f2a7a58b3193e`; EX5 `62e7f98e430e70d0a83c35aabd92e8cffbed0b5ccf8b09fb9480c242fee05707`; setfile `be2fc9127c1af0ce67404d345d2389a65c96b9277165407646216d9419dbeed1`; summary SHA-256 `922fc4aea477be16b3994e85a5413c55c9e5b200017a35da978d0636f70ea8a4` |

The first failed layer is setup/data contract. Both legs begin nine months
after the old immutable anchor, while the EA permits at most a seven-day
substitute. The signal therefore could never become valid. Both bound runs
produced zero trades, so the repair had no signal-selection or economic contact
and does not tune against outcomes.

## Scoped implementation

- Replaced `strategy_anchor_date=2017.01.03` with the authorized locked
  `2017.10.02` in the approved card copies, EA input and invariant guard,
  specification, manifest, and backtest setfile.
- Removed `Strategy_MonthKeyForTime`, its `year * 100 + month` arithmetic, raw
  EA `iTime` calendar reads, and the duplicate decision-month cache.
- Monthly transition and restart-safe deal-history checks now use
  `QM_CalendarPeriodKey(PERIOD_MN1, ...)`; the decision bar is read through
  `QM_ReadBar`.
- The logical basket remains XTIUSD.DWX/XNGUSD.DWX on D1. The manifest binds
  Q02 to 2018-07-02 through 2025-12-31 while retaining 2017 history so the
  locked origin is available during initialization.

## Q01 verification

- Targeted `build_check.ps1` and final strict compile: PASS, 0 failures,
  0 errors, and 0 warnings.
- Strict MetaEditor result: 0 errors, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260813_070305\QM5_13148_energy-rank-lmh.compile.log`;
  SHA-256 `3c1063050af3b1e5bf2ca01626d88128934a509359c4b1acb24c4c70ff969158`.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260813_065613.json`;
  SHA-256 `5ed984ac0645d608e8422926c4df9b8df3bc1b83617565ec7c90fef825314918`.
- Compile summary:
  `D:\QM\reports\compile\20260813_070305\summary.csv`;
  SHA-256 `52ccc1686c2163130a4f30e1f0a0383fc41899e82df7565dbcf727bdf163dfff`.

| Artifact | SHA-256 |
|---|---|
| MQ5 | `fd885ae916905fcf3187aa5e143d56959bf2819ce36bb9af47d574fa59a15e79` |
| EX5 | `ace050087f8599625827cd741dd3e4766c982dc5884424b14cd27cacb53da4c7` |
| Q02 setfile | `e9b0640648995d05be20b2b439400436c41085906fc06cba1a9bfaedef8fda3a` |

Focused rechecks also passed:

- `validate_build_guardrails.py`: both MQ5 and setfile PASS at the 336-hour
  maximum;
- `validate_spec_doc.py`: 1 PASS, 0 FAIL;
- `validate_symbol_scope.py --fail-on-leak`: `BASKET_OK`, 0 violations;
- static calendar contract: three framework calendar-helper calls and no raw
  EA `iTime`, `Strategy_MonthKeyForTime`, duplicate decision-month cache, or
  hand-rolled year/month key;
- JSON manifest, approved-card G0, active magic rows, fixed-risk values, and
  `git diff --check`: PASS.

## Recovery-proof boundary

A governed T1 smoke attempt was considered only after a read-only slot scan
showed T1 free. The active custom-history isolation guard refused it before a
reservation or launch because a smoke run must be bound to a worker work item
whose archives were privatized before execution:

```text
active Custom-history isolation requires a worker-bound work item whose
archives were privatized before run_smoke
```

An earlier shell wrapper timeout also ended before reservation or launch. No
terminal process was started, no active T1-T10 test was interrupted, and the
refusal is not treated as strategy or pipeline evidence. The fresh Q02 row is
the compliant evidence-producing path.

## Append-only Q02 handoff

Immediately before enqueue, five factory terminals were active, below the
seven-terminal ceiling; 926 rows were pending, below the 7,000-row queue
ceiling; and QM5_13148 had no pending or active Q02 row.

`farmctl seed-fresh-q02` authenticated the MQ5, EX5, canonical setfile,
fixed-risk values, logical basket identity, and legacy pre-binding source row.
It preserved both historical rows and created exactly one successor. Before
claim, the final strict compile and build check regenerated the binary and
setfile, so the unclaimed row was transactionally resealed to the exact final
hashes above and audit event `fresh_q02_seed_final_strict_compile_sealed` was
written. No terminal row was changed.

- work item: `798a71de-9de3-4b50-af17-c4043359e232`;
- initial and verification state: `pending`, attempt 0, unclaimed, no verdict;
- logical symbol: `QM5_13148_XTI_XNG_RANK_LMH_D1`;
- host/period: `XTIUSD.DWX` / D1;
- predecessor: `ce2bf983-059f-446f-ac69-f02b4a5f594d`;
- current artifact hashes: the final MQ5, EX5, and setfile hashes above;
- risk binding: `RISK_FIXED=1000`, `RISK_PERCENT=0`;
- evaluation window: 2018-07-02 through 2025-12-31;
- retained pre-window history: 2017 through 2025.

The guarded seed initially inherited the predecessor's 2022 end date. Before
the row was claimed, an exact-preimage transaction reconciled only this new
pending payload to the approved manifest's 2025-12-31 end, added USD/100000
tester metadata and the 450-minute basket timeout, and wrote event
`q02_manifest_preclaim_window_reconciled`. No historical row, status, or
verdict changed. The pre-reconciliation backup is:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_13148_q02_window_reconcile_20260813T065904Z.sqlite`

The build-task reactivation and final preclaim binding were protected by:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_13148_pending_seed_rebind_20260813T070047Z.sqlite`

The final sealed payload SHA-256 is
`b50d0d6c9fc33b6b8ed78993eed0ffe050b00eaf97feca435432076dfa26f512`,
and SQLite `PRAGMA quick_check` returned `ok`. Build generation 2 was recorded
`done` through `farmctl record-build`; its idempotency guard found the existing
pending row and created no duplicate. The repo/runtime build-result SHA-256 is
`774b719264b396ff9bf1f696676ae3c1731fa92daea439dde5c5cba334987fbc`.
No dispatch or pump command was run; the paced fleet owns execution.

## Remaining gaps and safety boundary

- Q02 has not produced evidence. Trade count, profitability, drawdown, and all
  pipeline verdicts remain unknown.
- The build task is recorded `done` with `smoke_result=deferred_p2_smoke`; no
  smoke or Q02 outcome is represented as a PASS. This router task moves only
  to the pipeline handoff state.
- No Q03+ work, portfolio admission, deploy manifest, live setfile, `T_Live`,
  AutoTrading, or terminal control was touched.

# QM5_10025 Diversity Build and Q02 Handoff

Date: 2026-08-07

Branch: `agents/board-advisor`

Operator: Codex paced fleet

## Selection and claim

The farm build-claim guard evaluated all eight pending `build_ea` rows. Seven
were non-claimable because of an active block, terminal failure marker, Q02
exclusion, or missing approved card. The sole eligible row was the approved
seven-host FX market-neutral candidate `QM5_10025_rw-fx-broad-pairs`.

- Build task: `71d862ed-21b8-4337-8986-c1366dd692dc`
- Build generation: `1`
- Claim key: `paced_fleet:diversity_build:QM5_10025:74cc05b101ad`
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10025_rw-fx-broad-pairs.md`
- Card gates: G0 `APPROVED`; R1-R4 `PASS`
- Registered hosts: `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`,
  `NZDUSD.DWX`, `USDCHF.DWX`, `USDCAD.DWX`, and `USDJPY.DWX`

## Rebuild scope

The task was reopened by Codex review
`84638446-0d92-45aa-b36f-e6af47977d75`. Its three findings referred to the
pre-2026-08-06 source: a hand-rolled month key, a second H4 timestamp gate,
and use of the basket helper for the chart host. The current branch already
contained the governed repairs:

- monthly cadence uses `QM_CalendarPeriodKey(PERIOD_MN1, ...)`;
- `QM_IsNewBar(_Symbol, PERIOD_H4)` is the sole H4 cadence gate;
- the partner uses `QM_BasketOpenPosition`, while the chart host uses
  `QM_TM_OpenPosition` with partner rollback on host rejection; and
- all seven foreign-symbol dependencies are initialized and warmed through
  the framework helpers.

This rebuild retained those repairs and corrected three remaining literal
card-fidelity defects without changing any approved threshold:

- the OLS hedge ratio is now frozen at monthly pair selection instead of being
  re-estimated on every H4 state refresh;
- the default z-score exit now detects a signed crossing of zero rather than
  requiring floating-point equality to exactly zero; and
- correlation below `0.50` now closes the package and disables that pair until
  the next monthly selection. An open package crossing a month boundary keeps
  its frozen partner and beta until exit.

Restart handling infers the entry-z sign from the registered host leg and
recovers held bars from the host position time. Pair state is cleared only
after all registered legs are flat, so a failed close cannot hide an orphan.

## Manifest and fixed-risk contract

The prior `basket_manifest.json` incorrectly declared a synthetic logical
symbol even though this strategy intentionally runs one real Q02 host setfile
per registered FX symbol. That shape caused the first automatic fanout attempt
to reject every setfile as `basket_manifest_missing_logical_setfile`.

The manifest now uses the farm's multi-symbol dependency form: it declares the
seven basket/traded symbols and H4 timeframe but no synthetic
`logical_symbol`. Deterministic resolution returns `logical_basket=null` and a
valid seven-symbol dependency manifest. Symbol-scope validation returns
`BASKET_OK` with zero violations.

All seven canonical H4 backtest setfiles remain:

- `RISK_FIXED=1000`
- `RISK_PERCENT=0`
- `PORTFOLIO_WEIGHT=1`

## Build evidence

| Check | Result | Evidence |
|---|---|---|
| EA/card/registry preflight | PASS | `skill_build_ea_guard.py` |
| SPEC validator | PASS | `validate_spec_doc.py` |
| Build guardrails | PASS, 0 findings | `validate_build_guardrails.py` |
| Symbol scope | `BASKET_OK`, 0 violations | `validate_symbol_scope.py` |
| Static framework gate | PASS, 0 failures, 0 warnings | `D:/QM/reports/framework/21/build_check_20260807_124834.json` |
| Strict MetaEditor compile | PASS, 0 errors, 0 warnings | `C:/QM/repo/framework/build/compile/20260807_124345/QM5_10025_rw-fx-broad-pairs.compile.log` |
| Build result | recorded, task `done` | SHA-256 `c8e99acda60dfd2b2b593c005da00c4fc753cdd50cb1e931ee5a4b3386a2b418` |

Artifact bindings:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `fd0a18d8710dc8bd0d089ab34b9c881de65e971f0916ba540b34c53b2aa120ff` |
| EX5 | `9bf2691d4af0a57d553711c37ffceadb513b303e710a25f455c8f2e211eecfcc` |

## Q02 handoff

After the manifest-shape correction, the idempotent
`record_build_result.auto_q02` fanout added the two missing hosts and preserved
the five already-open rows:

| Symbol | Work item | Origin |
|---|---|---|
| `NZDUSD.DWX` | `8582efac-cbaf-4336-98af-950e6dd606a0` | current build generation |
| `USDCHF.DWX` | `1a8e8377-a2f3-4533-9ae2-c4bcfc84aff0` | current build generation |

The farm now has exactly seven open Q02 rows for the seven approved hosts and
no non-card host in the active cohort. The two new rows carry
`priority_track=true`, `build_task_id=71d862ed-21b8-4337-8986-c1366dd692dc`,
and `q02_cohort_size=7`.

The governed `qm-build-ea-from-card` boundary is build-only, so this wake did
not launch a smoke test or any other CPU-bearing pipeline phase. Worker daemons
own Q02 execution after enqueue. No `T_Live` control action, AutoTrading
action, deploy-manifest mutation, portfolio-gate mutation, or live-manifest
mutation occurred in this unit.

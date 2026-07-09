# QM5_1017 Logical FX Cointegration Q02 Enqueue — 2026-07-10

Scope: branch `agents/board-advisor`. No `T_Live`, AutoTrading, deploy
manifest, portfolio gate, portfolio admission/KPI, or Q08 contribution action.

## Decision

The strict 66-pair scan in
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` has only two qualified
survivors. Both are already built and past Q02:

| EA | Pair | Latest relevant state |
|---|---|---|
| `QM5_12532` | `AUDUSD.DWX` / `NZDUSD.DWX` | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | `EURJPY.DWX` / `GBPJPY.DWX` | Q02 PASS, Q04 FAIL |

No unbuilt, reputable-source survivor remained. Per the mission fallback, this
pass advanced the existing APPROVED Chan cointegration card `SRC02_S01` as
`QM5_1017_chan_pairs_stat_arb`. The prior checked-in EA was explicitly an inert
P1 scaffold whose entry function always returned false; Quality-Tech recorded
that implementation blocker in `artifacts/qua-644/QT_AUDIT_2026-05-08.md`.

## Build completion

- Implemented the approved `AUDUSD.DWX` / `NZDUSD.DWX` D1 spread as a
  synchronized two-leg basket.
- Added prior-data-only annual OLS fitting, one-lag CADF gating, and OU
  half-life gating/time exit.
- Added mean-reach exit, orphan-leg rollback, and one-spread-only enforcement.
- Used active magic slots 4 and 26 for the two registered symbols.
- Preserved `RISK_FIXED=1000` for backtest and the card's explicit no-native-
  stop rule; a four-sigma spread distance sizes the package only.
- Added `basket_manifest.json`, canonical logical setfile, complete Q01 spec,
  and refreshed review/checklist evidence.

## Validation

| Check | Result |
|---|---|
| Strict MetaEditor compile | PASS — 0 errors, 0 warnings |
| Scoped `build_check.ps1` | PASS — 0 failures, 0 warnings |
| `validate_spec_doc.py` | PASS |
| `test_fx_basket_manifests.py` | PASS — 14 tests |
| `validate_symbol_scope.py` | `BASKET_OK` — 0 violations |

Compile log:
`C:/QM/repo/framework/build/compile/20260709_234105/QM5_1017_chan_pairs_stat_arb.compile.log`

Build-check report:
`D:/QM/reports/framework/21/build_check_20260709_234105.json`

Compiled EX5 SHA256:
`0AD70EB190D31DA0F8A977DC1DE0F616C862469F8C76D6BB81D92CF1E2ACC04E`

Branch build commits:

- `a9369af13288f2f3b8049115a8f5badab4039d0a` — completed EA, EX5,
  manifest, logical setfile, and initial spec.
- `f7e954deae1c9824af9935ae62cd3d791e8773f7` — canonical setfile hash.
- `a78d2d44dc3322922364fbc78b456a03525a1e41` — final Q01 spec and review
  evidence refresh.

## Q02 enqueue

| Field | Value |
|---|---|
| Work item | `9877c90c-768f-475b-8233-5bfbcdca1442` |
| EA | `QM5_1017` |
| Phase | `Q02` |
| Logical symbol | `QM5_1017_AUDUSD_NZDUSD_COINTEGRATION_D1` |
| Host / timeframe | `AUDUSD.DWX` / D1 |
| Basket legs | `AUDUSD.DWX`, `NZDUSD.DWX` |
| Risk | `RISK_FIXED=1000`, `RISK_PERCENT=0` |
| Status | `pending`, `priority_track=true` |

The enqueue used the farm's manifest-aware, idempotent build path. A post-write
dedupe assertion found exactly one pending/active logical Q02 row. Historical
component rows remain terminal evidence for the old scaffold and were not
requeued.

DB backup before mutation:
`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_1017_logical_q02_20260709T234523Z.sqlite`

## CPU ceiling

At final enqueue, the farm already had seven active claims (six Q02, one Q07)
and five factory `metatester64.exe` processes on T1, T3, T4, T6, and T7. This is
the backtest CPU ceiling. No dispatch tick, smoke test, manual MT5 run, terminal
process action, or backtest was launched; the pending row is left to the paced
workers.

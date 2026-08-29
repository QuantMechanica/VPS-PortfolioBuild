# QM5_20224 FX cointegration Q03 hard-CPU stop

Date: 2026-08-29 UTC (`2026-08-29T21:46:51Z`); 23:46 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `c4344813a8460ac72cbe7ce62d5b21a5c8d79129`

Status: stopped before queue mutation, dispatch, or backtest because a fresh
five-sample whole-host window crossed the explicit 97% ceiling. This records a
new serialized-lane delta without duplicating a Card, EA, or work item.

## Frontier decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. The committed sign-aware
coverage audit accounts for all 66 relationships, and the broader approved-card
census has a matching EA directory for every approved cointegration identity.
There is no eligible unbuilt scan pair.

Neither preferred anchor has a current Q02 infrastructure defect:

| EA | Pair | Canonical frontier |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS, Q04 FAIL |

Their historical per-leg `ONINIT` or `NO_HISTORY` rows do not supersede the
later logical-basket Q02 PASS verdicts. The strategy-card extraction gate is
closed for lack of a non-duplicate qualified relationship, and the EA-build
gate is closed for lack of an approved unbuilt identity.

## Existing FX fallback

The exact fallback remains scan rank 46,
`QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1`. It is an approved, structural D1
basket trading `EURUSD.DWX` and `EURJPY.DWX` at frozen beta `-0.236324029`;
`USDJPY.DWX` is conversion-history-only. Its backtest contract remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`, with no ML,
adaptive refit, banned indicator, grid, martingale, or portfolio feedback.

Canonical lineage was re-read from the farm:

- Q02 `5d1cb89c-25ce-419c-869c-8c9f7afa10c1`: done / PASS.
- Q03 `3c74eb04-7e19-4aa0-8dcf-3f004faaa946`: pending, unclaimed,
  attempt zero, `priority_track=true`, payload SHA-256
  `b9e8294d644b5d450601ea7eb7456e83165716f52e6b4a5cabf4e8f95eb484b4`.
- Q04 `a525cd8f-4c29-4752-b1af-3c43288f259e`: pending, not priority-bound,
  and not promoted ahead of Q03.

No second Q02 or Q03 row is valid.

## New lane progress

Since the prior `2026-08-29T20:55:45Z` handoff, two older basket rows made
real forward progress:

| EA | Phase | Work item | New verdict |
|---|---|---|---|
| `QM5_41076` | Q05 | `34176377-51a0-4eea-a97d-86420a022a52` | PASS at 21:14:14Z |
| `QM5_41077` | Q05 | `b67f1a88-1bd2-4a7d-b31c-08e1f1d661ba` | PASS at 21:43:46Z |

Six known rows still precede the FX target in the serialized basket lane:
QM5_41078 Q05, then QM5_41079, QM5_41085, QM5_41086, QM5_20294, and
QM5_20206 at Q04. The immediate read found no active multisymbol row, but that
does not override the host ceiling.

## Binding CPU result

The five one-second whole-host CPU samples were `87.702073%`, `97.759065%`,
`99.902363%`, `96.780498%`, and `96.015091%`. Average CPU was `95.631818%`;
maximum CPU was `99.902363%`. The contract binds when either measure reaches
97%, so the maximum triggered the stop.

At `2026-08-29T21:46:47Z`, `farmctl mt5-slots` observed factory terminals T3,
T4, T8, T9, and T10 and one worker daemon for each T1-T10. `T_Live` and an
unrelated FTMO terminal were observed only to exclude them and were not
controlled.

Accordingly, this run did not alter a work item, priority, claim, status,
verdict, reservation, worker, terminal, Card, EA, EX5, setfile, basket manifest,
registry, or magic row, and it did not launch a smoke or backtest. The
portfolio gate, `portfolio_admission`, portfolio `_kpi`, `_q08_contribution`,
T_Live, AutoTrading, and live/deploy manifests were untouched. Existing
unrelated shared-worktree changes were preserved.

Machine-readable evidence is in
`artifacts/qm5_20224_q03_hard_cpu_stop_20260829T214651Z_board_advisor.json`.

## Continuation condition

Take a fresh five-sample CPU window. Only when both average and maximum are
strictly below 97% may the canonical serialized lane continue. Preserve the
exact QM5_20224 Q03 identity; do not enqueue another Q02 or Q03, force a second
basket, or promote Q04 before Q03 PASS.

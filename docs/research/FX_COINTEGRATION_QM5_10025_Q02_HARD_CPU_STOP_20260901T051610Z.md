# FX basket fleet — QM5_10025 Q02 hard-CPU stop

Date: 2026-09-01 UTC (`2026-09-01T05:16:10Z`); 07:16 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `7702c1bd8d8dc1f2f886da7c5195a034a8026067`

Status: stopped at the explicit backtest CPU ceiling. No Card, EA, setfile,
manifest, registry row, queue row, queue payload, claim, dispatch, tester, or
pipeline verdict was created or changed.

## No eligible unbuilt scan pair

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen v3 scan
tested all 66 FX relationships. The latest complete census in
`docs/research/FX_COINTEGRATION_QM5_20240_Q04_RETIREMENT_20260831T233713Z.md`
records 123 approved cointegration/coint identities, 123 matching EA
directories, and no approved unbuilt identity. Creating another Card or EA
would therefore duplicate governed coverage or weaken the published survivor
criterion.

The preferred anchors are not blocked at Q02:

| EA | Relationship | Canonical state |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS; Q04 FAIL |

Fresh read-only database checks found their canonical Q02 PASS rows and no
current `ONINIT` or `NO_HISTORY` repair target. The Strategy Card extraction
and EA-build preflights therefore remain closed.

## Existing-card fallback remains queued exactly once

The selected fallback is `QM5_10025_rw-fx-broad-pairs`, an approved, built H4
market-neutral FX sleeve. It selects one partner monthly from seven registered
FX majors, freezes the OLS hedge ratio for the month, and opens a beta-weighted
two-leg package. It is deterministic and structural, with no machine learning,
adaptive intramonth refit, banned indicator, grid, or martingale.

Its exact USDJPY-host Q02 item remains non-duplicated:

| Field | Current value |
| --- | --- |
| Work item | `050dd2ea-e9d0-475f-b5ad-40c2206867ff` |
| Host | `USDJPY.DWX`, H4 |
| State | pending, unclaimed, attempt zero |
| Open exact Q02 rows | 1 |
| `priority_track` | `true` |
| Priority reason | `board_advisor_fx_existing_market_neutral_q02_after_exhausted_66_pair_frontier` |
| Payload SHA-256 | `bca99985bb4989d96c0537c81640333870793f2958843797d5357fb6c319a2f8` |

No duplicate enqueue or second priority mutation was attempted. The sealed
backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`; the MQ5, EX5, basket manifest, and setfile hashes remain
unchanged from the preceding receipt.

## Binding capacity result

Five fresh one-second whole-host CPU samples were `99.219221%`, `100.000000%`,
`99.129668%`, `98.635007%`, and `98.535313%`. Average CPU was `99.103842%` and
maximum CPU was `100.000000%`. Both measures exceed the explicit 97% ceiling,
so the mandatory stop binds.

The read-only factory census found T4, T5, T7, T8, and T9 running. T8 still
owns the serialized multisymbol lane for `QM5_20233_XAU_XAG_SKEW_RANK_D1`,
Q03 work item `f9ccf272-d66e-4a68-b332-76133baab427`. T4, T5, and T9 are
running optimization census work, and T7 is running Q10_NEWS. This is a
materially different capacity snapshot from the preceding stop receipt:
both CPU axes now bind while the active optimization load has expanded. No
terminal, reservation, worker, or process was controlled.

## Continuation and safety

On a later paced wake, take a new five-sample CPU window. Only when both the
average and maximum are strictly below 97%, and when the serialized
multisymbol lane is available, may the resident worker claim the already
prioritized FX Q02 row. Do not enqueue a duplicate or manually start a second
basket tester.

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, Q08 state, T_Live manifest, T_Live terminal,
AutoTrading state, live setfile, or deploy manifest was changed. Unrelated
pre-existing staged, unstaged, and untracked worktree changes were preserved
and excluded from this commit.

Machine-readable evidence is
`artifacts/fx_cointegration_qm5_10025_q02_hard_cpu_stop_20260901T051610Z_board_advisor.json`.

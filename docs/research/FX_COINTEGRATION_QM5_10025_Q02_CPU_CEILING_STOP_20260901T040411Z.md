# FX basket fleet — QM5_10025 Q02 hard-CPU stop

Date: 2026-09-01 UTC (`2026-09-01T04:04:11Z`); 06:04 Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `a08f1e40f98aa3fab5f0c334e34b0f430815217d`

Status: stopped at the explicit backtest CPU ceiling. No Card, EA, setfile,
manifest, registry row, queue row, queue payload, claim, dispatch, tester, or
pipeline verdict was created or changed.

## Governed frontier remains exhausted

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its frozen v3 scan
tested all 66 FX relationships and admitted only two under the published
positive-DEV, OOS-net-Sharpe-above-0.8, minimum-four-trade criterion. The
latest complete census in
`docs/research/FX_COINTEGRATION_QM5_20240_Q04_RETIREMENT_20260831T233713Z.md`
records 123 approved cointegration/coint identities, 123 matching EA
directories, and no approved unbuilt identity.

The two qualifying anchors remain past Q02:

| EA | Relationship | Canonical state |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS; Q04 FAIL |

The canonical passing Q02 rows are still present. Neither anchor has an open
Q02 `ONINIT` or `NO_HISTORY` blocker. Creating another scan-derived Card or EA
would duplicate governed coverage or weaken the reputable-source criterion,
so the Strategy Card extraction and EA-build gates remained closed.

## Existing-card fallback is already queued

The latest branch commit selected `QM5_10025_rw-fx-broad-pairs`, an approved,
already-built H4 market-neutral FX spread sleeve. It selects one partner
monthly from seven registered FX majors, freezes the OLS hedge ratio for the
month, and opens a beta-weighted two-leg package. Its Card expects about six
round trips per host-year. The rules are deterministic and structural; there
is no machine learning, adaptive intramonth refit, banned indicator, grid, or
martingale.

The manifest intentionally models seven physical hosts rather than a
synthetic logical symbol. The exact USDJPY-host canary is therefore a valid
Q02 identity for the existing-card fallback, not a claim of a newly
discovered fixed relationship.

| Field | Current value |
| --- | --- |
| Work item | `050dd2ea-e9d0-475f-b5ad-40c2206867ff` |
| Host | `USDJPY.DWX`, H4 |
| State | pending, unclaimed, attempt zero |
| Open exact Q02 rows | 1 |
| `priority_track` | `true` |
| Priority reason | `board_advisor_fx_existing_market_neutral_q02_after_exhausted_66_pair_frontier` |
| Payload SHA-256 | `bca99985bb4989d96c0537c81640333870793f2958843797d5357fb6c319a2f8` |

No duplicate enqueue or second priority mutation was needed. The two other
worker-bound logical FX-pairs Q02 seeds, `QM5_12507` EURUSD/GBPUSD and
`QM5_12512` fixed-pairs threshold, are also already pending with
`priority_track=true`; they were left unchanged.

The selected setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Its sealed package is unchanged:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `fd0a18d8710dc8bd0d089ab34b9c881de65e971f0916ba540b34c53b2aa120ff` |
| EX5 | `9bf2691d4af0a57d553711c37ffceadb513b303e710a25f455c8f2e211eecfcc` |
| Basket manifest | `98237a88f0634810f187a63c6d4585950aac4d5b8f21c157d23f88533691daa0` |
| USDJPY backtest setfile | `2d8a1ba1871c229d00b49458dcbd6dbd152d24c170d76404bace39cdea3be53c` |

## Binding capacity result

Five fresh one-second whole-host CPU samples were `96.980536%`,
`98.442346%`, `96.289474%`, `94.629469%`, and `86.823981%`. Average CPU was
`94.633161%`; maximum CPU was `98.442346%`. The mission ceiling binds when
either measure reaches 97%, so the maximum triggered the mandatory stop.

The accompanying read-only MT5 census found five running factory terminals:
T1, T3, T6, T7, and T8. T8 owned the serialized multisymbol lane for
`QM5_20233_XAU_XAG_SKEW_RANK_D1`, Q03 work item
`f9ccf272-d66e-4a68-b332-76133baab427`. The database was also receiving
fresh optimization claims during the observation. No terminal, reservation,
worker, or process was controlled.

## Continuation and safety

On a later paced wake, take a new five-sample CPU window. Only when both the
average and maximum are strictly below 97%, and when the serialized
multisymbol lane is available, may the resident worker claim an already
prioritized FX Q02 row. Do not enqueue a duplicate or manually start a second
basket tester.

No portfolio gate, `portfolio_admission`, portfolio `_kpi`,
`_q08_contribution`, Q08 state, T_Live manifest, T_Live terminal,
AutoTrading state, live setfile, or deploy manifest was changed. Unrelated
pre-existing staged, unstaged, and untracked worktree changes were preserved
and excluded from this commit.

Machine-readable evidence is
`artifacts/fx_cointegration_qm5_10025_q02_cpu_ceiling_stop_20260901T040411Z_board_advisor.json`.

# QM5_20224 FX cointegration Q07 retirement handoff

Date: 2026-08-31 UTC (`2026-08-31T17:25:32.7355641Z`); 19:25
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `2b5ef8f9199999e83cb6d0dbd0e342465b17d182`

Status: the strongest nonterminal existing FX sleeve completed its governed
Q07 recovery with an authenticated strategy `FAIL` and is retired without
refit or rescue. The sole remaining nonterminal FX continuation stays as one
already-pending Q04 row; no duplicate queue item or tester was started.

## Non-duplicate decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 research tested
all 66 FX relationships. A fresh case-insensitive approved-card census found
123 cointegration/coint EA identities, 123 matching EA directories, and zero
unbuilt identities. Creating another Card, EA, basket manifest, magic
allocation, or Q02 row would duplicate governed work.

The two preferred anchors are not blocked at Q02:

| EA | Pair | Canonical chain |
|---|---|---|
| `QM5_12532` | AUDUSD/NZDUSD | Q02 PASS; Q04 PASS; Q05 FAIL |
| `QM5_12533` | EURJPY/GBPJPY | Q02 PASS; Q04 FAIL |

Neither has a current `ONINIT` or `NO_HISTORY` defect. The Strategy Card
extraction and EA-build gates therefore remain closed, and the authorized
existing-forex fallback applies.

## Existing sleeve advanced to a terminal verdict

`QM5_20224` is the frozen-scan rank-46 EURUSD/EURJPY D1 basket. It is an
OWNER-approved, structural fixed-beta residual-reversion implementation with
no learned model, online refit, grid, martingale, banned indicator, or rescue
filter. Its logical backtest contract remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

The bound funnel chain is now:

| Phase | Work item | Verdict |
|---|---|---|
| Q02 | `5d1cb89c-25ce-419c-869c-8c9f7afa10c1` | PASS |
| Q03 | `3c74eb04-7e19-4aa0-8dcf-3f004faaa946` | PASS |
| Q04 | `a525cd8f-4c29-4752-b1af-3c43288f259e` | PASS_SOFT |
| Q05 | `482013fe-c135-4c9a-84ab-ab08727472d8` | PASS |
| Q06 | `d13cf596-44a4-429d-92a7-2de6b1a3e7f0` | PASS |
| Q07 | `9ba93eb9-4973-4759-9efa-f7ff224f1494` | INFRA_FAIL |
| Q07 | `b38e2753-1d57-45d9-8562-3cafc0e105a0` | INFRA_FAIL |
| Q07 recovery | `adb5e3aa-b942-4830-9478-328522727482` | **FAIL** |

The append-only recovery reused only hash-matched, validated predecessor seed
summaries and reran the missing seed 2026. All five seeds produced substantive
full-history results:

| Seed | PF | Trades | Evidence |
|---:|---:|---:|---|
| 42 | 1.08 | 185 | validated predecessor, T9 |
| 17 | 1.40 | 182 | validated predecessor, T9 |
| 99 | 1.26 | 187 | validated predecessor, T3 |
| 7 | 1.35 | 182 | validated predecessor, T3 |
| 2026 | 1.29 | 175 | fresh recovery run |

Mean PF was `1.276`, the PF spread was `0.32`, and relative dispersion was
`25.08%`. Q07's primary gate requires dispersion below `20%`. The ratified
second axis permits dispersion below `40%` only when the worst seed PF is at
least `1.10`; this sleeve's worst seed was `1.08`. The exact aggregate reason
is `pf_variance_pct=25.08>=20.0:min_pf=1.080:second_axis_not_met`.

This is an economic stability failure, not an initialization, history, or
zero-trade setup defect. The terminal aggregate is:

`D:/QM/reports/work_items/adb5e3aa-b942-4830-9478-328522727482/QM5_20224/Q07/QM5_20224_EURUSD_EURJPY_COINTEGRATION_D1/aggregate.json`

Its SHA-256 is
`9f25bf7163b20874f5219b1304bbd9469f9c9b8ec0e46ab30d0147782b3f4c7c`.
No Q08-or-later successor exists or was created. The approved Card's
falsification boundary requires retirement after an economic failure, so the
exact sleeve is retired without beta refit, threshold tuning, added filter,
pair substitution, or append-only rerun.

## Remaining FX continuation and paced stop

The next and only nonterminal relationship-level fallback remains frozen-scan
rank 59, `QM5_20240_USDCHF_GBPJPY_COINTEGRATION_D1`. Its exact Q04 work item
`85e98029-14f6-4f73-a991-b814d4f3c151` is still pending, unclaimed, attempt
zero, and already priority-bound after Q03 PASS. No duplicate was enqueued and
its payload was not restamped.

A fresh five-sample host window was `86%, 94%, 89%, 94%, 94%`: average
`91.4%`, maximum `94%`, both below the explicit `97%` CPU stop. The serialized
multisymbol lane, however, remains legitimately occupied by
`QM5_20294_XAU_XAG_LOWMAX_D1` Q03 work item
`9437109a-799b-4f29-a501-89e6b4a3809c` on T8. That real-tick run is progressing
and was not controlled. Claiming or launching `QM5_20240` concurrently would
violate the one-basket pacing contract, so this handoff stops without a queue,
dispatch, worker, tester, or terminal mutation.

After the active basket lane clears, let the resident paced worker claim the
existing `QM5_20240` Q04 row. Do not create a second row or manually force a
second basket.

## Safety

- No portfolio-admission, portfolio-KPI, or Q08-contribution surface changed.
- No `T_Live` manifest or terminal, AutoTrading state, live setfile, or deploy
  artifact changed.
- No Strategy Card, EA source, EX5, basket manifest, setfile, registry, magic
  row, work item, payload, or historical verdict changed.
- Pre-existing unrelated worktree changes were preserved and left unstaged by
  this commit.

Machine-readable evidence is
`artifacts/qm5_20224_q07_retirement_handoff_20260831T172532Z_board_advisor.json`.

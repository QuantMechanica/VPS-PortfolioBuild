# QM5_20240 FX cointegration Q04 serialized CPU stop

Date: 2026-08-31 UTC (`2026-08-31T20:51:44.5084870Z`); 22:51
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `a3286acabeba39f2089bd9ce652f81871fae4bd8`

Status: the frozen 66-pair frontier remains fully mechanized, the exact
existing FX continuation remains one priority-bound Q04 row, the serialized
basket lane is making forward progress, and the explicit 97% backtest CPU
ceiling is binding. No Card, EA, queue row, payload, claim, tester, terminal,
or portfolio object was created or changed.

## Non-duplicate frontier decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 scan tested all
66 relationships and selected only `QM5_12532` AUDUSD/NZDUSD and
`QM5_12533` EURJPY/GBPJPY under the published survivor criterion. Both have
canonical Q02 PASS; their later chains end at Q05 FAIL and Q04 FAIL,
respectively. Neither is blocked at Q02 by `ONINIT` or `NO_HISTORY`.

The committed sign-aware audit accounts for all 66 relationships. The latest
approved-card census has 123 cointegration/coint identities, 123 matching EA
directories, and zero unbuilt identities. No cointegration or anchor path
changed between the preceding committed receipt and this observation.
Creating a Card, EA, basket manifest, magic allocation, or Q02 row would be
duplicate work, so the Card-extraction and EA-build gates remained closed.

## Existing forex fallback preserved

The dependency-correct continuation remains frozen-scan rank 59,
`QM5_20240_USDCHF_GBPJPY_COINTEGRATION_D1`. Its approved Tier-A Chan-backed
Card, structural fixed-beta D1 implementation, compiled basket, manifest, and
logical setfile already exist. The setfile remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; there is no learned model, banned
indicator, adaptive beta refit, rescue filter, grid, or martingale.

Its exact canonical lineage is unchanged:

| Phase | Work item | State |
|---|---|---|
| Q02 | `24154a28-be35-469e-a5be-58881e29733c` | done / PASS |
| Q03 | `65a8b9cb-2c57-4068-81fb-2158f7b1beb7` | done / PASS |
| Q04 | `85e98029-14f6-4f73-a991-b814d4f3c151` | pending, priority-bound, unclaimed, attempt 0 |

The Q04 payload SHA-256 is still
`855dcffd54c7e28ec66576fbc43b5ce419011b59ce45338191ab9571c30aa14b`.
There is already exactly one successor, so no duplicate enqueue, payload
restamp, claim, or dispatch was attempted.

## Material serialized-lane progress

The preceding 19:47 UTC stop observed `QM5_20294_XAU_XAG_LOWMAX_D1` Q03
active on T8. That governed lane has now made a material run transition:

- run 1 completed at 20:08 UTC after `4:53:59.130` of real-tick testing;
  its 236,722-byte report has SHA-256
  `722322dc5725db34517c4b691bccb49ef7d713d9014a9a5fc2b97ef5e13039c3`;
- the tester logged final balance `102222.49 USD` and OnTester result
  `1.143869761191305`; these are run facts, not a Q03 verdict; and
- run 2 launched at `2026-08-31T20:08:23.5167760Z` on T8 under the same work
  item, with terminal PID 10536 and the generated `run_02/tester.ini`.

The Q03 row remains active and has no canonical verdict until its two-run
contract completes. Because the lane is healthy rather than stale, starting
or claiming `QM5_20240` concurrently would violate serialized multisymbol
pacing.

## Binding CPU ceiling

The final mandatory five-sample whole-host window was `97%`, `91%`, `93%`,
`93%`, and `96%`: average `94%`, maximum `97%`. The stop rule binds when
either measure is at least 97%; the maximum therefore triggers the explicit
ceiling. No further queue, dispatch, compile, smoke-test, or backtest action
followed.

A read-only `farmctl health` probe exceeded its diagnostic wait. Only the
exact PowerShell/Python processes created for that probe were stopped; no
factory worker, MT5 terminal, tester, reservation, or work item was touched.

## Safety and resume contract

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  path changed.
- No `T_Live` manifest or terminal, AutoTrading state, live setfile, or deploy
  artifact changed.
- Existing unrelated staged, unstaged, and untracked worktree changes were
  preserved and excluded from this receipt.

After the active `QM5_20294` Q03 basket becomes terminal, take a fresh
five-sample CPU window. Only if both average and maximum are strictly below
97% may the resident paced worker claim exact Q04 row
`85e98029-14f6-4f73-a991-b814d4f3c151`. Do not enqueue a duplicate or force a
second basket.

Machine-readable evidence is
`artifacts/qm5_20240_q04_serialized_cpu_stop_20260831T205144Z_board_advisor.json`.

# Commodity/energy sleeve mission — hard CPU stop

Date: 2026-08-27 UTC (`2026-08-27T19:02:28.1147140Z`), Europe/Berlin
`2026-08-27T21:02:28.1147140+02:00`

Branch: `agents/board-advisor`

Observation base: `f47cf2a00f710d90caf63e5e561b50f1ccd40f30`

Status: stopped at the explicit backtest CPU ceiling before source approval,
canonical dedup, card extraction, allocation, build, compile, or Q02 enqueue.

## Concrete edge held

The one candidate selected for a later clear capacity window is an outright
WTI same-calendar-month seasonal Mann-Kendall trend on `XTIUSD.DWX`. On the
first eligible D1 bar of each broker month, the provisional rule would use
exactly ten completed endpoints for that same calendar month from the prior
ten years, score all 45 chronologically ordered pairs, buy at `S >= 23`, sell
at `S <= -23`, and otherwise consume the month flat. It would make at most one
attempt per month and exit at the next broker month, with a forty-day stale
repair.

This is a concrete research candidate, not an approved Card or efficacy
claim. A bounded read-only scan found no seasonal-Kendall identity or
same-calendar-month Kendall mechanic. Existing `QM5_20264_wti-rank-trend`
uses thirteen consecutive month-end endpoints and was rejected as a reusable
identity. Complete reputable-source reading, R1-R4, canonical dedup, final
risk/stop specification, G0, and allocation remain mandatory. Nothing was
renamed or allocated to manufacture novelty.

The intended backtest contract remains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`. No source, Strategy Card, EA ID, magic, setfile, EA,
or portfolio claim was created while the capacity stop was binding.

## Binding capacity result

Five fresh one-second whole-host CPU readings were `99.919930%`, `98.163146%`,
`99.805685%`, `100.000000%`, and `99.036112%`. Average CPU was `99.384975%`
and maximum CPU was `100.000000%`. Both exceed the governed
`CPU_MAX_LOAD_PERCENT = 97.0` tester-admission ceiling in
`tools/strategy_farm/terminal_worker.py`.

The supported `farmctl mt5-slots` snapshot found five governed factory
terminals actively testing: `T1`, `T2`, `T3`, `T7`, and `T9`. Each had a
matching reservation, all ten terminal-worker daemons were alive, and no
orphaned factory terminal was reported. `T_Live` and the unrelated FTMO
terminal were observed only to exclude them; neither was controlled.

The farm DB contained seven active rows: one `OPT_CENSUS`, one `Q03`, one
`Q07`, one `Q09`, and three `Q10_NEWS`. The mission's explicit stop condition
therefore bound before any mutating strategy or queue action.

## Non-duplicate observation delta

The preceding receipt at `2026-08-27T18:47:13Z` recorded eight active rows,
four `Q10_NEWS` rows, and seven running factory terminals. This snapshot
records seven active rows, three `Q10_NEWS` rows, and five running terminals:
`T4`, `T6`, and `T10` left the roster while `T9` joined. Average CPU fell from
`99.961250%` to `99.384975%`; the maximum remained `100%`. This changed fleet
state and the explicitly held, non-allocated candidate are the new evidence;
no prior card, identity, build, or queue row was duplicated.

## Safety and continuation

No compile, build check, dispatch, smoke test, manual tester, backtest, Q02
row, queue priority, claim, or verdict was created or changed. No terminal or
worker was started, stopped, reserved, released, or reaped. The portfolio
gate, portfolio admission state, `T_Live`, AutoTrading, and deploy manifests
were untouched. Concurrent worktree changes were preserved and remain
unstaged.

After a fresh five-sample window is strictly below 97% on both average and
maximum, the held candidate may start at reputable-source approval and
complete reading, then canonical dedup, G0, deterministic allocation, strict
non-live V5 build, Q01, and exactly one paced `XTIUSD.DWX` Q02 enqueue.

Machine-readable evidence:
`artifacts/commodity_energy_sleeve_hard_cpu_stop_20260827T190228Z_board_advisor.json`.

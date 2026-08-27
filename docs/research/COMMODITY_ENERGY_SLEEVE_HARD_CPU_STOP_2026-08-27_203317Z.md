# Commodity/energy sleeve mission — rotated-roster hard CPU stop

Date: 2026-08-27 UTC (`2026-08-27T20:33:17.6052648Z`), Europe/Berlin
`2026-08-27T22:33:17.6052648+02:00`

Branch: `agents/board-advisor`

Observation base: `bc58add59eaa5e1e4bc2b26f3869b458a11b91a3`

Status: stopped at the explicit backtest CPU ceiling before reputable-source
approval, card extraction, canonical dedup, allocation, build, compile, or Q02
enqueue.

## Concrete edge held

The selected candidate remains the outright WTI same-calendar-month seasonal
Mann-Kendall trend on `XTIUSD.DWX` recorded in the preceding commodity receipt.
At the first eligible D1 bar of each broker month, the provisional rule uses
exactly ten completed endpoints for the same calendar month in the prior ten
years, scores all 45 chronologically ordered pairs, buys at `S >= 23`, sells at
`S <= -23`, and otherwise consumes the month flat. It allows one consumed
attempt per broker month and exits at the next broker month, with a forty-day
stale repair.

This remains a research candidate, not an approved source, Strategy Card,
allocated identity, efficacy claim, or build. Complete reputable-source
reading, R1-R4 review, canonical dedup, final stop/sizing specification, G0,
and deterministic allocation remain mandatory after capacity clears. No new
identity was speculated while the admission stop was binding.

The intended backtest contract remains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`.

## Binding capacity result

Five fresh one-second whole-host CPU readings were `100.000000%`,
`100.000000%`, `96.387122%`, `89.752323%`, and `98.741333%`. Average CPU was
`96.976156%`, but maximum CPU was `100.000000%`. The governed admission rule
in `tools/strategy_farm/terminal_worker.py` stops when either the five-sample
average or maximum reaches `CPU_MAX_LOAD_PERCENT = 97.0`; the maximum-side
condition therefore bound.

The supported `farmctl mt5-slots` snapshot found five governed factory
terminals actively testing: `T1`, `T2`, `T8`, `T9`, and `T10`. Each had a
matching reservation, all ten terminal-worker daemons were alive, and no
orphaned factory terminal was reported. `T_Live` and the unrelated FTMO
terminal were observed only to exclude them; neither was controlled.

The supported active-work query succeeded and returned eight active rows:
two `OPT_CENSUS`, one `Q03`, one `Q07`, one `Q09`, and three `Q10_NEWS`.
Three claimed rows had no corresponding tester process in the point-in-time
process snapshot. They were observed only; that mismatch does not prove
staleness and did not authorize reclaim, repair, or duplicate enqueue.

## Non-duplicate observation delta

The immediately preceding receipt at `2026-08-27T19:45:13Z` found four
running factory terminals (`T1`, `T2`, `T3`, and `T7`), all five CPU samples
at 100%, and a locked active-work query. The current roster rotated to
`T1`, `T2`, `T8`, `T9`, and `T10`, and the active-work query now exposed eight
rows. Average CPU fell below 97%, but a 100% sample kept the maximum-side stop
binding. That changed roster and newly observed queue state are the new
evidence; no prior card, identity, build, or queue row was duplicated.

## Safety and continuation

No source approval, Card, G0 decision, EA ID, magic, EA, EX5, setfile, basket
manifest, compile, build check, smoke test, backtest, Q02 row, queue priority,
claim, or verdict was created or changed. No terminal or worker was started,
stopped, reserved, released, or reaped. The portfolio gate, portfolio
admission state, `T_Live`, AutoTrading, and deploy manifests were untouched.
Concurrent worktree changes were preserved and remain unstaged.

After a fresh five-sample window is strictly below 97% on both average and
maximum, resume with reputable-source approval and complete reading for the
held edge, then canonical dedup, G0, deterministic allocation, strict non-live
V5 build, Q01, and exactly one paced `XTIUSD.DWX` Q02 enqueue.

Machine-readable evidence:
`artifacts/commodity_energy_sleeve_hard_cpu_stop_20260827T203317Z_board_advisor.json`.

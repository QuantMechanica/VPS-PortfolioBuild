# Commodity/energy sleeve mission — contracted-roster hard CPU stop

Date: 2026-08-27 UTC (`2026-08-27T19:45:13.7332525Z`), Europe/Berlin
`2026-08-27T21:45:13.7332525+02:00`

Branch: `agents/board-advisor`

Observation base: `f5ce08a345107854218b88335dcf6af8fac45fbc`

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
allocated identity, efficacy claim, or build. The durable predecessor receipt
records the bounded first-pass duplicate observation: existing
`QM5_20264_wti-rank-trend` uses thirteen consecutive month-end endpoints rather
than same-calendar-month seasonal cohorts. Complete reputable-source reading,
R1-R4, canonical dedup, final stop/sizing specification, G0, and deterministic
allocation remain mandatory after capacity clears.

The intended backtest contract remains `RISK_FIXED=1000`, `RISK_PERCENT=0`,
and `PORTFOLIO_WEIGHT=1`.

## Binding capacity result

Five fresh one-second whole-host CPU readings were all `100.000000%`. Average
CPU and maximum CPU were both `100.000000%`, exceeding the governed
`CPU_MAX_LOAD_PERCENT = 97.0` tester-admission ceiling in
`tools/strategy_farm/terminal_worker.py`.

The supported `farmctl mt5-slots` snapshot found four governed factory
terminals actively testing: `T1`, `T2`, `T3`, and `T7`. Each had a matching
reservation, all ten terminal-worker daemons were alive, and no orphaned
factory terminal was reported. `T_Live` and the unrelated FTMO terminal were
observed only to exclude them; neither was controlled.

The supported active-work query encountered SQLite's existing database lock.
After the capacity stop bound, no retry, lock manipulation, claim, or database
mutation was attempted.

## Non-duplicate observation delta

The preceding commodity receipt at `2026-08-27T19:02:28Z` recorded five
running factory terminals (`T1`, `T2`, `T3`, `T7`, and `T9`) and average CPU of
`99.384975%`. The latest branch receipt at `2026-08-27T19:31:02Z` recorded six
running terminals (`T1`, `T2`, `T3`, `T7`, `T8`, and `T10`) and `100%` average
CPU. The current roster contracted to four: `T9` left relative to the commodity
receipt, and `T8` and `T10` left relative to the latest branch receipt. Despite
that contraction, all five fresh CPU samples remained saturated at `100%`.
That changed roster under unchanged saturation is the new evidence; no prior
card, identity, build, or queue row was duplicated.

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
`artifacts/commodity_energy_sleeve_hard_cpu_stop_20260827T194513Z_board_advisor.json`.

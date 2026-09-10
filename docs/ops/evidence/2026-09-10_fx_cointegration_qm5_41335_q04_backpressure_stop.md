# FX cointegration fallback — QM5_41335 Q04 backpressure stop

Recorded: 2026-09-10T04:20:29Z (06:20 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `43bfe54e8187d0cd5486f86543b4ca9cc9780d7f`

## Outcome

No new basket was built. The frozen sign-aware 66-pair FX cointegration
frontier remains fully mechanized: the durable relationship receipt
`artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`
accounts for all 66 relationships, so another scan-derived Card or EA would be
duplicate work. Its SHA-256 is
`5b11c01ec9afebf853433585d172fdc52669b367567ec5afff5fca4077bc5344`.

The two preferred baskets are not blocked at Q02:

- `QM5_12532` AUDUSD/NZDUSD has logical-basket Q02 `PASS`, Q04 `PASS`,
  then Q05 `FAIL`.
- `QM5_12533` EURJPY/GBPJPY has logical-basket Q02 `PASS`, then Q04
  `FAIL`.

The allowed existing-forex fallback was therefore resolved to approved,
structural, low-frequency `QM5_41335_fx-usd-exhaustion-reversal-opt` on
`AUDUSD.DWX` D1. Its exact Q02 work item
`ff75b1c3-4930-419d-a2fe-49bd37eadc4d` is `done/PASS` with 64 trades,
PF 1.23, and +4428.72 net profit over 2018-07-02 through 2022-12-31. A live
work-item census found no Q04 successor for this EA.

## Binding and PACER checks

The approved runtime Card is
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_41335_fx-usd-exhaustion-reversal-opt.md`
(`7826e575a21600cfcc48e7ba03e6fa38bfe8faf91e4db3978f430a49e69dc1aa`).
The canonical source, binary, and setfile identities still match the Q02 row:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `d7eec6373be1b7b865902cd8420b2a3fe305c7a7e026603e9baef9e32ee1e7bc` |
| EX5 | `f17045107715b1ee127011f14ee60ad36e6ad23e8dbfc372819a27d4bb596280` |
| AUDUSD D1 setfile | `6ed5b4fe7549362276fa8812bcbf9450f6aca2b3b03fd169336a89799874bd47` |

The setfile keeps `RISK_FIXED=1000` and `RISK_PERCENT=0`. The binding PACER
audit was run against the absolute source path and returned exit zero,
`ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, and zero findings:

```powershell
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_41335_fx-usd-exhaustion-reversal-opt/QM5_41335_fx-usd-exhaustion-reversal-opt.mq5"
```

No MQ5 was generated or edited, and no compile command was enqueued.

## Backpressure stop

Immediately before the intended exact Q02-to-Q04 enqueue, the canonical active
work-item census returned seven active rows: six `OPT_CENSUS` and one Q04.
`tools/strategy_farm/farmctl.py` sets
`BUILD_BACKPRESSURE_ACTIVE_WORK_ITEM_LIMIT = 7` and pauses new builds when the
active count is greater than or equal to that threshold.

Five fresh one-second whole-host CPU readings were `75.100113%`,
`73.541203%`, `84.481946%`, `88.380075%`, and `95.508281%` (average
`83.402324%`, maximum `95.508281%`). The active-work backpressure ceiling,
not the 97% CPU-utilization ceiling, bound first. Per the mission stop rule, no
Q04 row was enqueued and no dispatch tick was run.

A read-only verification at `2026-09-10T04:21:13.659035Z` observed the
transient active cohort had drained to three `OPT_CENSUS` rows. That later
change does not retroactively authorize mutation after the binding ceiling was
hit; it is recorded to make the point-in-time result reproducible rather than
misstate the fleet as still saturated.

## Safety

- No Card, EA, EX5, setfile, basket manifest, registry, magic row, resolver,
  work-item row, priority, hold, claim, verdict, or terminal state changed.
- No portfolio-admission, portfolio KPI, Q08-contribution, portfolio-gate,
  deploy-manifest, `T_Live`, or AutoTrading surface was touched.
- Existing unrelated dirty-worktree changes were left unstaged and untouched.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_41335_q04_backpressure_stop_20260910T042029Z_board_advisor.json`.

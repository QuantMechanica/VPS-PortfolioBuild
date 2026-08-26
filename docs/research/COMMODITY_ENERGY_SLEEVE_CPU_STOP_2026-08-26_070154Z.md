# Commodity/energy sleeve mission — selected candidate CPU stop

Date: 2026-08-26 UTC (`2026-08-26T07:01:54.5363631Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `f2d5c9f5a935fbe68f1f360c05fabc2ca1bee596`

Status: the governed, build-pending WTI candidate was reverified, then work
stopped before implementation, compile, or Q02 enqueue because the binding
backtest CPU ceiling was reached.

## Preserved non-duplicate build handoff

The selected candidate remains `QM5_41105_wti-mclose-location-mom`:

- approved card:
  `strategy-seeds/cards/approved/QM5_41105_wti-mclose-location-mom_card.md`;
- durable source approval:
  `decisions/2026-08-22_wti_monthly_close_location_momentum_source_approval.md`;
- G0 decision:
  `decisions/2026-08-22_qm5_41105_wti_monthly_close_location_momentum_g0.md`;
- active registry identity: `QM5_41105`, slot 0, `XTIUSD.DWX`, magic
  `411050000`; and
- scaffold: `framework/EAs/QM5_41105_wti-mclose-location-mom/`, which still
  has a spec and bound approved card but no `.mq5` implementation or
  backtest setfile.

The structural low-frequency signal follows the sign of the immediately
completed WTI broker-month return only when it agrees with that month's own
strict outer-quartile close location. It holds at most one month and uses a
frozen `3.5*ATR(20,D1)` hard stop with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. This remains different from the
certified XNG two-day RSI pullback and does not add another XAU/XAG ratio
estimator to the already dense family.

## Binding guard result

The required five-sample whole-host guard returned:

| Sample | CPU |
|---:|---:|
| 1 | 100.000000% |
| 2 | 100.000000% |
| 3 | 100.000000% |
| 4 | 100.000000% |
| 5 | 100.000000% |

Average and maximum CPU were both `100.000000%`. Both exceed the `97.0%`
claim ceiling and fail the governed requirement that average and maximum
remain below `90.0%` before work resumes.

Four path-anchored backtest terminals and four matching `metatester64.exe`
processes were active across `T3`, `T5`, `T7`, and `T8`. `T_Live` and the
FTMO terminal were observed only in the read-only process census.

## Non-duplicate operational delta

This sample was taken `2755.5146165` seconds after the prior selected-candidate
receipt at `2026-08-26T06:15:59.0217466Z`. Average CPU rose from
`99.981040%` to `100.000000%`; maximum remained `100.000000%`. The factory
roster changed from `T5,T6,T9,T10` to `T3,T5,T7,T8`.

The durable delta is a fresh capacity state tied to the unchanged governed
handoff. No new identity was allocated and no already implemented commodity
mechanic was duplicated.

## Scope boundary

No source or card was created, no registry row was changed, no EA or setfile
was created, no compile or tester was started, and no Q02 row was enqueued.
No terminal or tester process was controlled. AutoTrading, the portfolio gate,
`T_Live`, and every deploy manifest were untouched. Concurrent unrelated
worktree changes were preserved and excluded from this evidence commit.

Machine-readable evidence is in
`artifacts/commodity_energy_sleeve_cpu_stop_20260826T070154Z_board_advisor.json`.

## Continuation condition

Resume the selected `QM5_41105` build only after a fresh five-sample
whole-host CPU guard has both average and maximum below `90%`. Then implement
from the approved card, strict-compile the hash-bound EX5, and enqueue exactly
one non-live Q02 logical row.

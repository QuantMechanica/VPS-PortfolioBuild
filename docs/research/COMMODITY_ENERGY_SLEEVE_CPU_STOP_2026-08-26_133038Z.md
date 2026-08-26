# Commodity/energy sleeve mission — selected candidate CPU stop

Date: 2026-08-26 UTC (`2026-08-26T13:30:38.7232031Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `abbb1cc7d9b810935123d69d74a931248ecb02aa`

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
certified XNG two-day RSI pullback and avoids the already dense XAU/XAG ratio
family.

## Binding guard result

The required five-sample whole-host guard returned:

| Sample | CPU |
|---:|---:|
| 1 | 99.418523% |
| 2 | 98.644294% |
| 3 | 99.122534% |
| 4 | 99.708533% |
| 5 | 84.691892% |

Average CPU was `96.317155%` and maximum CPU was `99.708533%`. The maximum
exceeds the `97.0%` claim ceiling, and both measures fail the governed
requirement that average and maximum remain below `90.0%` before this build
resumes.

At the final CPU read, four `metatester64.exe` processes were active. The
supported fleet census completed 27 seconds later with five active,
path-anchored factory terminals and matching reservations across
`T1,T2,T5,T7,T9`, recording the process-layer transition without inferring a
tester lifecycle event. `T_Live` and the unrelated FTMO terminal were
observed only to exclude them; neither was controlled.

## Non-duplicate operational delta

The preceding commodity receipt at `2026-08-26T12:32:44.5203260Z` recorded
five factory terminals on `T1,T4,T5,T7,T9`, average CPU of `98.46%`, and a
maximum of `99.90%`. This fresh receipt records a rotated
`T1,T2,T5,T7,T9` roster and lower average CPU, while the maximum still binds
the hard ceiling and the below-90% continuation condition remains unmet.

The durable delta is a fresh capacity state tied to the unchanged governed
handoff. No new identity was allocated and no already implemented commodity
mechanic was duplicated.

## Scope boundary

No source or card was created, no registry row was changed, no EA or setfile
was created, no compile or tester was started, and no Q02 row was enqueued.
No terminal or tester process was controlled. AutoTrading, the portfolio
gate, `T_Live`, and every deploy manifest were untouched. Concurrent
unrelated worktree changes were preserved and excluded from this evidence
commit.

Machine-readable evidence is in
`artifacts/commodity_energy_sleeve_cpu_stop_20260826T133038Z_board_advisor.json`.

## Continuation condition

Resume the selected `QM5_41105` build only after a fresh five-sample
whole-host CPU guard has both average and maximum below `90%`. Then implement
from the approved card, strict-compile the hash-bound EX5, and enqueue exactly
one non-live Q02 logical row.

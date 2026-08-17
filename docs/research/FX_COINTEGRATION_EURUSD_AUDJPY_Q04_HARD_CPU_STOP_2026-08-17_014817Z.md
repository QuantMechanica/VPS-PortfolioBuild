# FX cointegration EURUSD/AUDJPY — Q04 hard-CPU continuation stop

Date: 2026-08-17 Europe/Berlin (`2026-08-17T01:48:17Z`)

Branch: `agents/board-advisor`

Status: the frozen 66-pair frontier remains fully mechanized; the selected
existing FX successor remains pending exactly once at Q04, and the explicit
backtest CPU ceiling is binding at a materially changed eight-terminal state

## Outcome

No duplicate Strategy Card or EA was created. The committed sign-aware audit
of `analyze_cross_asset_v3.py --include-negative-hedges` still accounts for
all 66 relationships, and both preferred anchors remain terminal downstream
of Q02 rather than blocked by ONINIT or NO_HISTORY:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

The existing rank-21 `EURUSD.DWX` / `AUDJPY.DWX` D1 package remains the
highest-ranked exact frontier successor awaiting an economic verdict. Its
logical identity is `QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1`, backed by the
OWNER-approved Tier-A Chan cointegration Card. It is structural fixed-beta,
low-frequency, and contains no ML, banned indicator, online refit, grid,
martingale, or rescue filter. Its setfile remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Exact Q04 identity

A read-only query of
`D:/QM/strategy_farm/state/farm_state.sqlite` returned
`PRAGMA quick_check=ok`. Q04 work item
`113ae6d1-33c0-42bc-b9b0-bf3a48ef3445` remains `pending`, unclaimed, at
attempt zero. There is exactly one Q04 row and exactly one open row for the
logical basket. Enqueueing, requeueing, restamping, or reprioritizing it would
therefore be duplicate work.

The existing MQ5, EX5, basket manifest, fixed-risk setfile, and build-local
Card hashes are unchanged from the preceding reconciliation. No strategy,
risk, artifact, registry, or pipeline-metadata mutation was needed.

## Binding hard-CPU stop

Five whole-machine CPU samples were `100%`, `100%`, `100%`, `99%`, and
`100%` (average `99.8%`, maximum `100%`). Both readings exceed the explicit
`97%` hard ceiling.

Eight path-anchored factory terminals were active on `T1`, `T2`, `T4`, `T5`,
`T7`, `T8`, `T9`, and `T10`, bound to eight canonical work items: six at Q02
and two at Q04. This is materially different from the prior
`2026-08-17T00:49:03Z` snapshot, which observed six active terminals. Every
factory process was selected by a `\\mt5\\T<n>\\` executable path; `T_Live`
was excluded and was neither inspected nor controlled.

Per the mission stop condition, no dispatch tick, backtest, enqueue, requeue,
priority/timestamp mutation, reservation, tester launch, terminal action, or
factory-control action followed.

Machine-readable evidence is
`artifacts/fx_cointegration_eurusd_audjpy_q04_hard_cpu_stop_20260817T014817Z_board_advisor.json`.

## 03:01Z continuation audit

A fresh read-only audit at repository head
`233d0919b47dd2fc5e85a708dd3961adbd417304` found a materially changed
factory roster but the same binding hard-CPU condition. Five whole-machine
samples were `99.9%`, `99.9%`, `100%`, `100%`, and `100%` (average `99.96%`,
maximum `100%`). Six path-anchored factory terminals were active:

| Terminal | EA | Phase | Symbol |
|---|---|---|---|
| `T2` | `QM5_20085` | `Q06` | `EURUSD.DWX` |
| `T4` | `QM5_41030` | `Q02` | `QM5_41030_XAU_XAG_FLOWDIV_D1` |
| `T5` | `QM5_20178` | `Q02` | `USDJPY.DWX` |
| `T6` | `QM5_20086` | `Q07` | `NDX.DWX` |
| `T7` | `QM5_20085` | `Q06` | `XAUUSD.DWX` |
| `T10` | `QM5_20178` | `Q02` | `GBPUSD.DWX` |

The roster fell from eight active factory terminals to six and changed its
work-item composition, so this is not a copy of the 01:48Z observation. CPU
nevertheless remained above the explicit `97%` ceiling on every sample. The
separately visible `T_Live` and FTMO processes were excluded from the factory
roster and were neither inspected beyond process identity nor controlled.

`PRAGMA quick_check` against the canonical farm database remained `ok`.
`QM5_20203_EURUSD_AUDJPY_COINTEGRATION_D1` still has exactly one open row:
Q04 work item `113ae6d1-33c0-42bc-b9b0-bf3a48ef3445`, `pending`, unclaimed,
attempt zero. The exact logical Q02 predecessor remains canonical `PASS`.
The anchor dispositions also remain Q02 `PASS` followed by downstream
economic failure. A new Q02/Q04 row, timestamp change, priority mutation, or
requeue would therefore be duplicate work.

The selected package remains cryptographically unchanged:

- EX5 SHA-256:
  `4d57f2bc03a14ce0be3f7f18245adfff280955287cda5af1119d502d33d96270`
- basket manifest SHA-256:
  `2f5823242ae1b2a0592d9239969e22f31ac90234d909b3eee5e1d9c635b519a9`
- fixed-risk setfile SHA-256:
  `dcac19dcd0882c24ba0c772b36e47c816c582d3f612b35445ce909bfc8e846d8`
- build-local approved Card SHA-256:
  `f5f4b1d13ace14d69ca3249b77976503f025c229598f16693ace755ba8c0043d`

Per the mission stop condition, no enqueue, dispatch tick, backtest, tester
launch, terminal action, or queue/EA-package mutation followed. The fresh
machine-readable evidence is
`artifacts/fx_cointegration_eurusd_audjpy_q04_hard_cpu_stop_20260817T030120Z_board_advisor.json`.

## Safety

- No portfolio-admission, portfolio KPI, or Q08-contribution path changed.
- No T_Live manifest or terminal, AutoTrading state, or live artifact changed.
- No EA, EX5, setfile, basket manifest, Card, registry, magic row, or runtime
  queue row changed.
- Concurrent unrelated worktree changes were left unstaged and untouched.

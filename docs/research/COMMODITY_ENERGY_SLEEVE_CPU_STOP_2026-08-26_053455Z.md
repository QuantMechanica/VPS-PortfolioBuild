# Commodity/energy sleeve mission — selected candidate and CPU stop

Date: 2026-08-26 UTC (`2026-08-26T05:34:55.6797491Z`), Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `78f7d5b60e391fd8b5ddd230a9583eee393f46b8`

Status: one governed, genuinely build-pending WTI candidate was selected, then
work stopped before implementation, compile, or Q02 enqueue because the
binding backtest CPU ceiling was reached.

## Selected non-duplicate build handoff

The current approved-card and EA-directory scan selected
`QM5_41105_wti-mclose-location-mom`:

- approved card:
  `strategy-seeds/cards/approved/QM5_41105_wti-mclose-location-mom_card.md`;
- durable source approval:
  `decisions/2026-08-22_wti_monthly_close_location_momentum_source_approval.md`;
- G0 decision:
  `decisions/2026-08-22_qm5_41105_wti_monthly_close_location_momentum_g0.md`;
- active registry identity: `QM5_41105`, slot 0, `XTIUSD.DWX`, magic
  `411050000`; and
- existing directory:
  `framework/EAs/QM5_41105_wti-mclose-location-mom/`, which has a spec and
  bound card but no `.mq5` implementation or backtest setfile.

The low-frequency structural signal is fixed. At a genuine new broker month,
use the two most recent completed WTI calendar-month endpoints:

```text
r   = ln(C0 / C1)
clv = (C0 - L0) / (H0 - L0)

BUY  when r > 0 and clv > 0.75
SELL when r < 0 and clv < 0.25
otherwise FLAT
```

The package holds to the following month, uses a frozen `3.5*ATR(20,D1)` hard
stop, and is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. It is an outright WTI monthly continuation carrier with
close-location agreement, not the certified XNG two-day RSI pullback and not
another already implemented XAU/XAG ratio estimator.

## Binding guard result

The required five-sample whole-host guard returned:

| Sample | CPU |
|---:|---:|
| 1 | 85.162850% |
| 2 | 99.614671% |
| 3 | 98.742692% |
| 4 | 96.196022% |
| 5 | 88.872117% |

Average CPU was `93.717670%` and maximum CPU was `99.614671%`. The maximum is
above the `97.0%` claim ceiling, and neither average nor maximum satisfies the
governed requirement that both remain below `90.0%` before work resumes.

Five path-anchored backtest terminals and five matching `metatester64.exe`
processes were active across `T1`, `T3`, `T6`, `T7`, and `T9`. `T_Live` and
the FTMO terminal were observed only in the read-only process census.

## Non-duplicate operational delta

This sample was taken `3843.681658` seconds after the prior commodity receipt
at `2026-08-26T04:30:51.9980914Z`. Average CPU fell from `97.910439%` to
`93.717670%`, while maximum CPU remained effectively saturated at
`99.614671%`. The factory roster changed from `T2,T3,T6,T7,T8,T9` to
`T1,T3,T6,T7,T9`.

Unlike the prior receipt, this pass also completed a read-only governed-card
scan and retained one exact build-pending candidate. It did not reserve a new
identity or duplicate one of the already implemented commodity systems.

## Scope boundary

No source or card was created, no EA ID or magic row was changed, no source or
setfile was written, no compile or tester was started, and no Q02 row was
enqueued. No terminal or tester process was controlled. AutoTrading, the
portfolio gate, `T_Live`, and every deploy manifest were untouched. Concurrent
unrelated worktree changes were preserved and excluded from this evidence
commit.

Machine-readable evidence is in
`artifacts/commodity_energy_sleeve_cpu_stop_20260826T053455Z_board_advisor.json`.

## Continuation condition

After a fresh five-sample whole-host guard has both average and maximum below
`90.0%`, resume exactly `QM5_41105`: implement from its approved card, strict-
compile the hash-bound EX5, author only the canonical `RISK_FIXED` backtest
setfile, and enqueue exactly one non-live Q02 row.

# QM5_20046 WTI Symmetric Halloween Q02 Enqueue

## Outcome

Built and enqueued one new structural energy sleeve: `QM5_20046_wti-halloween-ls` on `XTIUSD.DWX`, D1. The fixed calendar carrier is long November-April and short May-October, renewed monthly with one persisted attempt per month and a frozen ATR hard stop.

## Non-duplicate boundary

`QM5_20015_wti-halloween-winter` is long-only November-May and flat otherwise. `QM5_20046` uses a symmetric six/six partition; its May-October short carrier is load-bearing. It does not use RSI, ML, an external feed, a weekday/day-of-month signal, or XNG logic.

## Evidence

- Approved card: `strategy-seeds/cards/approved/QM5_20046_wti-halloween-ls_card.md`
- EA: `framework/EAs/QM5_20046_wti-halloween-ls/QM5_20046_wti-halloween-ls.mq5`
- Strict compile: PASS, 0 errors, 0 warnings; `framework/build/compile/20260722_143428/QM5_20046_wti-halloween-ls.compile.log`
- Build check: PASS, 0 failures, 0 warnings; `D:/QM/reports/framework/21/build_check_20260722_143439.json`
- Build task: `e419da00-af74-4410-8d08-32cea6f6d4eb`, status `done`
- Q02 work item: `68028ce6-8a03-4bc9-bef0-14387da6742d`, `pending`, attempt 0
- Q02 route: `XTIUSD.DWX`, D1, one `RISK_FIXED=1000` backtest setfile

No manual backtest was started. No `T_Live`, AutoTrading, live/deploy manifest, portfolio gate, or T_Live manifest was touched.

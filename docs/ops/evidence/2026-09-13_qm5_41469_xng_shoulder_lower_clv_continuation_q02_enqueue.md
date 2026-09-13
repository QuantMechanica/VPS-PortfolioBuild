# QM5_41469 XNG Shoulder Lower-CLV Continuation — Q02 Enqueue

Date: 2026-09-13  
Branch: `agents/board-advisor`  
Outcome: new source-grounded card and EA built; Q01 PASS; exactly one Q02
canary enqueued below the binding CPU ceiling; Q02 deterministically failed
the unchanged frequency gate and is not requeued or tuned.

## Edge

`QM5_41469_xng-shoulder-lclv-cont` is a low-frequency natural-gas downside-
continuation sleeve. At the first tradable D1 bar of each April-May or
September-October normalized broker week, it reconstructs exactly the
immediately completed three-to-five-session week and sells only when the final
close is strictly below one third of that week's full range. It has no parent-
close return-sign, range-rank, candle-body, wick, stretch, or moving-average
predicate and no long side.

The decision week is consumed before fallible gates. The position exits in
the next normalized week, with ten-calendar-day stale repair and one frozen
`3.5*ATR(20,D1)` hard stop. This differs from certified `QM5_12567`, an all-
year long-only two-day cumulative-RSI pullback above a slow trend filter.
Realized portfolio correlation is unclaimed and remains an unchanged later
Q09 measurement.

## Source And Identity

The complete-read packet combines official EIA natural-gas shoulder-season
context, governed peer-reviewed XNG completed-week/close-location lineage,
and the peer-reviewed Moskowitz-Ooi-Pedersen commodity-continuation lineage.
The exact weekly lower-tercile CFD conjunction is explicitly untested.

The canonical scan covered 4,950 registry rows and 1,559 repository cards. It
found no exact collision and five fuzzy family matches. Manual review separated
the WTI carrier siblings, the XNG upper-tercile fade, the weekly-return-sign
reversal, and the two-week XNG continuation package. The external Strategy
Wiki mount was unavailable and that limitation remains explicit.

## Q01 Evidence

- EA ID/magic: `QM5_41469`, slot 0, `414690000`.
- Mandatory final-source PACER audit: `ok=true`, predicate
  `EA_FRAMEWORK_INPUT_PINNED`, `hit_count=0`.
- Framework RNG, news, and Friday-close inputs are not equality-pinned; stress
  rejection has only finite inclusive `0..1` validation.
- Deterministic reference tests: 10 passed.
- Compile item: `2261e652-834d-4fbb-a02f-2c55bd7551dc`.
- Compile verdict: `COMPILE_OK`; 0 compiler errors, 0 compiler warnings;
  strict build check PASS.
- MQ5 SHA-256:
  `643aadb6ecca77be187f9d358df3278afa1f79517b62ba04ba3e8cb407e64047`.
- EX5 SHA-256:
  `2d40c3ee933a32e872071411a33e2aac64cd0c285a19bfdfe660eef0707d8f29`.
- Final setfile SHA-256:
  `bb64e381f2d82f6134d56d5a3422e3593b8b4f2a12fceb5e502b0633218ea13e`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; no live set exists.

The strict build check emitted three nonfatal card-inference warnings and zero
failures.

## Q02 Admission

Read-only first-Q02 intake returned `eligible=true` and `would_enqueue=true`
for exactly one `XNGUSD.DWX` D1 set. The governed intake verified all nonempty
strategy parameters, active magic, fixed-risk mode, current EX5, and final
setfile hash.

The five-sample CPU admission measured `[85.3, 73.2, 66.9, 71.9, 83.2]`;
average `76.1%`, maximum `85.3%`, threshold `97.0%`. Exactly one Q02 item was
then appended: `4b409bec-a72d-4c35-b160-8bad6d9b4830`; it was claimed by T8
after enqueue. Receipt:
`D:/QM/strategy_farm/artifacts/receipts/first_q02_intake/2261e652-834d-4fbb-a02f-2c55bd7551dc_4b409bec-a72d-4c35-b160-8bad6d9b4830.json`, SHA-256
`473ce2fd5aea079b89c1ae3853148f4754dc8d70cba496a5e28daf66a934dcbe`.

The real-tick run completed `FAIL` with reason
`MIN_TRADES_NOT_MET`: 20 trades over the scored 2018-07-02 through 2022-12-31
window versus 25 required by the unchanged five-trades-per-year floor. Profit
factor was `0.40`, net profit `-2614.36`, and drawdown `2698.35 (2.70%)`.
Evidence is
`D:/QM/reports/work_items/4b409bec-a72d-4c35-b160-8bad6d9b4830/QM5_41469/20260913_074145/summary.json`.
Per the operating rule, this below-floor candidate is retired as tested; no
requeue, threshold change, rescue parameter, or replacement edge was created.

No manual backtest, fanout, rerun, downstream phase, portfolio gate,
portfolio admission, deploy/live manifest, `T_Live`, AutoTrading, terminal
control, or live operation was touched.

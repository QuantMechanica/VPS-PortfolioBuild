# OWNER decisions — 2026-08-16 evening

Recorded by Claude directly from OWNER. Six items were put to OWNER; all six
were decided. This file is the binding record; the tasks below implement it.

| # | Item | OWNER decision |
|---|---|---|
| 1 | Q09 challenger swap QM5_13054 XTIUSD in / 11165 EURUSD out | **Next book only** — do not swap in the current live book |
| 2 | 25 session-tick card variants (XTI/XNG entry clock) | **Approved** — implement as proposed |
| 3 | XCUUSD copper line (5 parked EAs, no archive coverage) | **Stay parked** |
| 4 | QM5_12708 XAUUSD challenger evaluation (Q08 pass, Q09 regime-correlation fail) | **Yes — prepare it** |
| 5 | QM5_20177 Carney AB=CD, retired on the frequency floor | **Try the variant** |
| 6 | Gate recalibration for the near-miss cluster | **Recalibrate** — the near-misses may be book material after all |

## 1 — Challenger swap deferred to the next book

`QM5_13054:XTIUSD.DWX` measured superior to the weakest incumbent
`11165:EURUSD.DWX` (book Sharpe 2.803 → 2.886, MaxDD 26.15% → 24.57%,
challenger-to-incumbent correlation 0.030). OWNER decision: this does **not**
enter the current live book; it is carried into the next book cycle. No
T_Live change, no deploy manifest, no incumbent removal now. The Q09 evidence
(`D:/QM/reports/work_items/b12d6ddc-.../QM5_13054/Q09_PORTFOLIO/XTIUSD_DWX/aggregate.json`)
stands as the input for that cycle, together with the open caveat that Q08
sub-gate 8.10 regime_crisis is EDGE_SOFT and the Q09 correlation could not be
regime-bound (0 regime days, monthly full-sample basis only).

The same treatment applies to `QM5_1537:XAGUSD.DWX` if it reaches Q09: it
passed Q08 today (96 trades, cost cushion 43.4) and carries the same
regime_crisis EDGE_SOFT flag.

## 6 — Gate recalibration: what is actually being asked

Not "lower the floors". The observed cluster is eight failures within 5% of a
gate threshold, five of them on XAUUSD, several sitting exactly at or 1-3%
below the line (`artifacts/near_miss_register_20260816.json`). OWNER wants to
know whether that cluster represents extractable book material rather than
noise. The work is therefore an evidence question first and a threshold
question second — and any threshold change remains an OWNER DL, not an
operator action.

## Century Suite status (asked in the same message)

`C:\Users\Administrator\Desktop\Strategy_Cards_Overview.md` (2026-08-15, 100
cards, QM5_30001-41012). Measured state on 2026-08-16:

- 100/100 have EA-ID registry rows;
- 82/100 cards are in `strategy-seeds/cards/approved/`;
- **1/100 is built and tested** — `QM5_32003` (cl-pit-open-volatility-breakout),
  Q02 PASS, Q04 FAIL;
- **99/100 have no active magic rows**, which is a hard build precheck block.

So the suite is not "in progress"; it is stalled at the same gate that held
the 19 EAs recovered under task `89a4cb33` today. The EAs seen running today
in the 41013-41027 range are a *later* intake wave, not this document's set.
Note also that the PF figures inside that overview are illustrative, not
measured — no card in it has produced an economic verdict except QM5_32003.

The second desktop file, `FTMO_Factory_Hindernisse_Analyse_2026-08-16.md`, is
an obstacle analysis, not a strategy source.

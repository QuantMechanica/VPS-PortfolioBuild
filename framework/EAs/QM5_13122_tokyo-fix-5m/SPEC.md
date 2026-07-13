# QM5_13122 Tokyo Fix Five-Minute Cycle

Mechanical implementation of the APPROVED `tokyo-fix-5m` card. On each
audited Bank of Japan business day it buys USDJPY at the first M1/M5 bar at
09:50 JST, closes the long and opens a short only after a confirmed close at
09:55 JST, and closes the short at 10:00 JST.

The three clock values, 30-pip catastrophic stop, 10-point entry-spread cap,
20-point deviation cap, and all-business-days calendar are locked. No fitted
parameter, indicator, take profit, trailing stop, scale-in, ML, or external
runtime feed is present.

Canonical card: `strategy-seeds/cards/tokyo-fix-5m_card.md`.

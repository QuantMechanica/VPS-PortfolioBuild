# QM5_41400 WTI Monthly Fixed-Recency Sign Trend

Card of record:
`strategy-seeds/cards/approved/QM5_41400_wti-mrecency-sign-tr_card.md`.

The EA evaluates once per genuine broker month on `XTIUSD.DWX` D1. It derives
twelve adjacent returns from thirteen consecutive completed month ends,
reduces each return to a strict sign, and applies fixed oldest-to-newest integer
weights `1..12`. It buys at score `>=18`, sells at score `<=-18`, and consumes
weaker or invalid months flat.

The position is renewed at the next broker month and protected by one frozen
`3.5*ATR(20,D1)` hard stop. Q02 uses `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No target, retry, adaptation,
external feed, optimization, or live configuration exists.

Load-bearing implementation checks:

- current-month data is excluded;
- attempt state persists before every fallible entry gate;
- weights are chronological ages, never magnitude ranks;
- weight total is 78 and score range/parity are verified;
- RNG/news/Friday inputs are not equality-pinned;
- stress probability is checked only for finiteness and inclusive `[0,1]`;
- lifecycle repair precedes entry-only filters.

Q09 alone can establish portfolio decorrelation. This package authorizes no
live use, portfolio-gate mutation, `T_Live`, or AutoTrading change.

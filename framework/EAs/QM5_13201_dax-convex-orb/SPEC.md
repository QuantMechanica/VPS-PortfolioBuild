# QM5_13201 Build Specification

- Card: `artifacts/cards_approved/QM5_13201_dax-convex-orb.md`
- Symbol/timeframe: `GDAXI.DWX` H1 only
- Magic: `132010000`, slot 0
- Opening range: 08:00 Berlin H1 bar
- Trigger window: 09:00-10:00 Berlin, dual OCO stop orders
- Filter: range width at most 1.75 times simple TR-average ATR(14)
- Entry buffer: 0.05 ATR
- Stop: opposite range boundary
- Target: 5R
- Time exit: 18:00 Berlin
- Risk: fixed 1000 in Q02; no live setfile or deployment authorization

Native tick ordering adjudicates a same-H1 dual touch. The Python screen skips
such ambiguous trigger bars and otherwise applies stop-first OHLC resolution.

# QM5_13200 Build Specification

- Card: `artifacts/cards_approved/QM5_13200_ndx-convex-orb.md`
- Symbol/timeframe: `NDX.DWX` H1 only
- Magic: `132000000`, slot 0
- Opening range: 09:00 and 10:00 New York H1 bars
- Trigger window: 11:00-12:00 New York, dual OCO stop orders
- Filter: range width at most 1.75 times simple TR-average ATR(14)
- Entry buffer: 0.05 ATR
- Stop: opposite range boundary
- Target: 8R
- Time exit: 16:00 New York
- Risk: fixed 1000 in Q02; no live setfile or deployment authorization

Native tick ordering is the adjudicator when both sides touch during the same
H1 trigger bar. This is the only declared execution difference from the
pessimistic H1 research screen, which skips such ambiguous days.

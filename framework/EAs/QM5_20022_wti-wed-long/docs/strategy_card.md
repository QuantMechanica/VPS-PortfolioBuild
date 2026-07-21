# QM5_20022 WTI Wednesday One-Session Long

- Source: `LI-WTI-DOW-2022`.
- Approved card:
  `strategy-seeds/cards/approved/QM5_20022_wti-wed-long_card.md`.
- Target: `XTIUSD.DWX`, D1, magic slot 0.
- Entry: one BUY at a genuine new broker Wednesday D1 bar.
- Exit: first following D1 bar, with one-day stale retry guard.
- Risk: completed-bar ATR(20), frozen 2.75 ATR stop,
  `RISK_FIXED=1000`, no take-profit.
- State: consume the exact Wednesday attempt before fallible entry gates and
  persist it across restart.

The paper statistic is a research premise, not certification. Q02 must
falsify costs, session mapping, futures/CFD basis and post-2016 persistence.
No live or portfolio authority is included.

# QM5_20017 XNG Calendar-Day-15 One-Session Premium

- Source: `BOROWSKI-XNG-DOM15-2016`.
- Target: `XNGUSD.DWX`, D1, magic slot 0.
- Entry: one BUY only on a broker D1 bar dated exactly the 15th; never shift
  an absent/weekend 15th and never retry within the month.
- Exit: first following D1 bar, one-calendar-day stale guard, Friday close, or
  the broker hard stop.
- Risk plumbing: completed-bar ATR(20), 2.75 ATR stop, 2500-point spread cap.
- Q02 setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The source reports a `+0.9881%` natural-gas mean on calendar day 15 and
`p=0.0008` over its 1990-2016 NYMEX sample. It also searches 31 numbered days
without a reported multiple-comparison correction. This build is therefore a
strict falsification candidate, not a performance or decorrelation claim.

The canonical approved card is
`strategy-seeds/cards/approved/QM5_20017_xng-dom15-long_card.md`.
No live setfile, T_Live/AutoTrading action, deploy manifest, portfolio
admission, or portfolio-gate change is authorized.

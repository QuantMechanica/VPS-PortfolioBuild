# QM5_20035 XNG Calendar-Day-27 One-Session Fade

- Source: `BOROWSKI-XNG-DOM15-2016`, strategy extraction S02.
- Target: `XNGUSD.DWX`, D1, magic slot 0.
- Entry: one SELL only on a broker D1 bar dated exactly the 27th; never shift
  an absent/weekend 27th and never retry within the month.
- Exit: first following D1 bar, one-calendar-day stale guard, Friday close, or
  the broker hard stop.
- Risk plumbing: completed-bar ATR(20), 2.75 ATR stop, 2500-point spread cap.
- Q02 setfile: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The source reports day 27 as the minimum natural-gas mean (`-0.7265%`) over
its 1990-2016 NYMEX sample. It does not report day 27 as statistically
significant and searches 31 numbered days without a multiple-comparison
correction. This is a weak, strict falsification candidate, not a performance
or decorrelation claim.

The canonical approved card is
`strategy-seeds/cards/approved/QM5_20035_xng-dom27-short_card.md`.
No live setfile, T_Live/AutoTrading action, deploy manifest, portfolio
admission, or portfolio-gate change is authorized.

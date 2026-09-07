# QM5_41377_wti-wmom142-agree

**EA ID:** QM5_41377

**Source strategy:** `KWON-KANG-YUN-WTI-WMOM142-AGREE-2026_S01`

## Strategy Logic

On the first tradable D1 bar of normalized WTI broker week `t`, reconstruct
exactly four consecutive completed three-to-five-session weeks. Compute the
immediately completed `t-1` open-to-close log return and the disjoint
cumulative `t-4` first-open to `t-2` final-close log return. Buy only when
both are strictly positive, sell only when both are strictly negative, and
remain flat for disagreement, equality, or invalid chronology.

The position uses fixed-dollar risk, a frozen `3.5*ATR(20,D1)` hard stop, no
target, a durable one-attempt-per-week ledger, and next-week closure. The
source establishes cross-sectional weekly commodity-momentum horizons and WTI
membership; it does not establish this conjunction, WTI-only CFD efficacy, or
decorrelation.

## Locked Parameters

- Symbol: preset-bound `XTIUSD.DWX`; D1 only; slot 0.
- History: 40 D1 bars; exactly four completed weekly packages.
- Session count: three to five per normalized week.
- Entry grace: 180 raw-session minutes.
- Return boundary: exact strict sign, epsilon 0.
- Spread ceiling: 1,500 points.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Stop: completed-bar ATR(20), multiplier 3.5.
- Normal exit: first later normalized week; ten days is stale repair.
- News: temporal OFF, compliance NONE.
- Friday close: disabled.

No optimization, live/demo/shadow/stress preset, external feed, range or
volatility filter, magnitude condition, target, trail, retry, scale-in, grid,
martingale, or pyramid is authorized.

## Build And Safety Boundary

The canonical card is
`strategy-seeds/cards/approved/QM5_41377_wti-wmom142-agree_card.md`. Q01
requires card lint, reference tests, resolver verification, the PACER
framework-input pin audit before compile enqueue, governed compile PASS, and a
fixed-risk setfile. Q02 alone measures density and economics; Q09 alone may
measure realized correlation.

This build is branch-only and non-live. It excludes portfolio-gate changes,
portfolio admission, live manifests, `T_Live`, AutoTrading, and deployment.

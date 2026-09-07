# QM5_41378_wti-wmom265

**EA ID:** QM5_41378

**Source strategy:** `KWON-KANG-YUN-WTI-WMOM265-2026_S01`

## Strategy Logic

On the first tradable D1 bar of normalized WTI broker week `t`, reconstruct
exactly 26 consecutive completed two-to-five-session weeks. Ignore weeks
`t-4..t-1` for signal arithmetic, compute
`ln(final_close[t-5] / first_open[t-26])`, and follow its strict sign for one
week. Equality or invalid chronology is flat.

The position uses fixed-dollar risk, a frozen `3.5*ATR(20,D1)` hard stop, no
target, a durable one-attempt-per-week ledger, and next-week closure. The
source establishes a cross-sectional commodity-futures horizon and WTI
membership; it does not establish WTI-only CFD efficacy or decorrelation.

## Locked Parameters

- Symbol: preset-bound `XTIUSD.DWX`; D1 only; slot 0.
- History: 160 D1 bars; exactly 26 completed weekly packages.
- Session count: two to five per normalized week.
- Excluded signal interval: `t-4..t-1`.
- Entry grace: 180 raw-session minutes.
- Return boundary: exact strict sign, epsilon 0.
- Spread ceiling: 1,500 points.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Stop: completed-bar ATR(20), multiplier 3.5.
- Normal exit: first later normalized week; ten days is stale repair.
- News: temporal OFF, compliance NONE.
- Friday close: disabled.

No optimization, live/demo/shadow/stress preset, external feed, magnitude or
volatility filter, target, trail, retry, scale-in, grid, martingale, or pyramid
is authorized.

## Build And Safety Boundary

The canonical card is
`strategy-seeds/cards/approved/QM5_41378_wti-wmom265_card.md`. Q01 requires
card lint, reference tests, resolver verification, the PACER input-pin audit
before compile enqueue, governed compile PASS, and a fixed-risk setfile. Q02
alone measures density and economics; Q09 alone may measure correlation.

This build is branch-only and non-live. It excludes portfolio-gate changes,
portfolio admission, live manifests, `T_Live`, AutoTrading, and deployment.

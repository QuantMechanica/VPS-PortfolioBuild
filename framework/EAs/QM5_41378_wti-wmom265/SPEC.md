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

## Validation Record

- 2026-09-07: 14/14 deterministic reference checks PASS.
- 2026-09-07: mandatory pre-compile PACER input-pin audit PASS with zero
  `EA_FRAMEWORK_INPUT_PINNED` findings on source SHA-256
  `8d621c6f64affedd75dd61305e2828c88370513a192d96d35f5dac8e0241fed0`.
- 2026-09-07: governed compile work item
  `0d883e95-9a9d-440d-a7e7-55c03b2ded47` completed `COMPILE_OK`; compiler
  errors/warnings 0/0 and framework build check PASS. Binary SHA-256 is
  `cc4fce1985c6ba799af47f60e30c8ea9be8b9f6b2108c8250d61d7571f3cb108`.
- 2026-09-07: first-Q02 admission dry run PASS after binding
  `strategy_symbol=XTIUSD.DWX` in the fixed-risk preset. A five-sample CPU
  window peaked at 95.185%, below the 97% ceiling. Q02 work item
  `d4ac61bc-4b49-4eed-98ef-93b488d5e749` was enqueued without a priority boost.

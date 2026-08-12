# QM5_20165 energy leverage convergence build and Q02 enqueue

Date: 2026-07-26  
Branch: `agents/board-advisor`

## Outcome

Built one new market-neutral energy sleeve. A completed D1 joint shock must
have negative WTI return, positive natural-gas return, and an XTI-minus-XNG
one-day return-spread z-score below -2.0. The package buys XTI and sells XNG
for convergence. This event condition and fixed direction distinguish it from
the generic two-sided, 20-day `QM5_12840` spread reversion and from
`QM5_12567` single-symbol cumulative-RSI pullback.

## Source And Frozen Baseline

- Source: Kristoufek (2014), “Leverage effect in energy futures,”
  *Energy Economics* 45, 1-9, DOI `10.1016/j.eneco.2014.06.009`.
- Full governed extraction:
  `strategy-seeds/sources/KRISTOUFEK-ENERGY-LEV-2014/source.md`.
- Logical basket: `QM5_20165_ENERGY_LEV_CONV_D1`.
- Legs: `XTIUSD.DWX` slot 0 and `XNGUSD.DWX` slot 1.
- Exit: `abs(z)<0.3`, ten calendar days, orphan cleanup, or Friday close.
- Stops: frozen `3.0 * ATR(20)` per leg.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Validation

- Card schema lint: PASS, no ML hits.
- SPEC validation: PASS.
- Strict compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260726_005004/QM5_20165_energy-lev-conv.compile.log`.
- EX5: 347322 bytes, SHA256
  `ae762c32b994a88db2c77539abb6a22b2aaa4c3d64b596065e2afb47e07ea02d`.
- Magic resolver contains `201650000` and `201650001`.
- Build task: `7d580298-435c-41b2-ad92-ff80ebc04972`, done.

## Paced Q02

At preflight, six path-anchored factory terminals were running, below the
documented seven-terminal paced ceiling. No tester was manually launched.
`record-build` basket-aware auto-enqueue created exactly one logical Q02 item:

- work item `8e305c03-945a-47f1-9cc4-5cb58505103b`;
- status `pending`, unclaimed at verification;
- symbol `QM5_20165_ENERGY_LEV_CONV_D1`;
- phase `Q02`.

No portfolio gate, T_Live path, T_Live manifest, deploy manifest,
AutoTrading state, or live setfile was touched.

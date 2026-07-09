# QM5_1017 — Chan pairs stat-arb

## Build scope

- Approved card: `strategy-seeds/cards/chan-pairs-stat-arb_card.md` (`SRC02_S01`, `status: APPROVED`).
- Concrete deployment pair: `AUDUSD.DWX` / `NZDUSD.DWX`, D1.
- Logical tester symbol: `QM5_1017_AUDUSD_NZDUSD_COINTEGRATION_D1`.
- Host / magic slots: `AUDUSD.DWX` slot 4; `NZDUSD.DWX` slot 26.

## Strategy mapping

- No-trade: the annual walk-forward training anchor must pass the card's one-lag CADF critical value and OU half-life cap before entry. V5 kill-switch and two-symbol news clearance remain active; the approved Friday-close waiver remains explicit.
- Entry: OLS fits `AUDUSD - beta * NZDUSD` on the prior 252 closed D1 bars. The EA opens both legs at `z <= -2` or `z >= +2` and rolls back immediately if only one leg fills.
- Management: one synchronized spread only. A detected orphan leg is flattened. No pyramiding, grid, ML, trailing stop, break-even, or native price stop is added.
- Close: flatten both legs when `abs(z) <= 1` or the fitted OU half-life time stop expires.
- Risk: `RISK_FIXED=1000` in the logical backtest set. The card-authorized four-sigma catastrophic spread distance is used only to size the two-leg package; orders intentionally carry no native SL per the approved Chan rule.

## Q02 packaging

`basket_manifest.json` makes the pair one market-neutral Q02 unit. Historical per-component Q02 rows belong to the inert scaffold and do not test the approved spread edge.

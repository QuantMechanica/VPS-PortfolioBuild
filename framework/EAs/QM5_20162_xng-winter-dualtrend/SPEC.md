# QM5_20162 xng-winter-dualtrend — Strategy Spec

**EA ID:** QM5_20162

**Slug:** `xng-winter-dualtrend`

**Source:** `EIA-MOP-XNG-WINTER-DUALTREND-2026_S01`

## 1. Strategy Logic

During November through March, buy `XNGUSD.DWX` only when the last completed
D1 close is above SMA(21), SMA(21) is above SMA(84), and both averages are
above their values five completed D1 bars earlier. The rule is long-only and
uses native completed prices; it contains no cumulative RSI or pullback state.

One broker D1 decision is consumed before all fallible entry gates and is
persisted by EA magic. An open position or an entry deal from the same D1 bar
blocks re-entry after restart.

## 2. Parameters

The frozen baseline uses SMA periods 21/84, five slope bars, ATR(20), a
`3.5 * ATR` hard stop, a 35-calendar-day stale exit, and a 1,000-point spread
ceiling. Both news axes and legacy news are OFF. Framework Friday close remains
enabled at 21:00 broker time.

## 3. Symbol Universe

Exact registered carrier: `XNGUSD.DWX`, magic slot 0, magic `201620000`.

## 4. Timeframe

D1 only. The framework new-bar gate admits at most one new decision per broker
D1 bar. Friday flattening segments otherwise continuous November–March trend
states into low-frequency weekly packages.

## 5. Expected Behaviour

Approximately 8–18 completed November–March packages per year when the trend
state is valid. Q02 must establish at least five completed trades per full year
after warm-up and must retire the candidate below that floor.

## 6. Source Citation

U.S. EIA (2015), “Natural gas use features two seasonal peaks per year,”
provides winter heating-demand lineage. Moskowitz, Ooi, and Pedersen (2012),
“Time Series Momentum,” *Journal of Financial Economics* 104(2), provides
own-price persistence lineage. The exact trend stack and all execution/risk
choices are falsifiable QM translations, not source results.

## 7. Risk Model

Q02–Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. There is no live/demo/shadow setfile. The binary does not
authorize `T_Live`, AutoTrading, a deploy manifest, portfolio admission, a
portfolio-gate edit, or a correlation waiver.

## 8. Entry

- Require the exact carrier, D1, EA ID, slot, frozen strategy parameters,
  Friday contract, and news-OFF contract.
- Consume and persist the current D1 bar before position, season, history,
  signal, spread, quote, news, stop, or order checks.
- Require a November–March bar and the complete rising 21/84 trend stack.
- Require spread in `[0,1000]` points, a valid market quote, completed ATR(20),
  and a normalized BUY stop strictly below entry.
- Open one market BUY with no take profit.

## 9. Exit And Management

- Close outside November–March.
- Close when the completed close/21/84 stack or either five-bar slope is no
  longer strictly rising, or when the state cannot be validated.
- Close a wrong-side owned position and close after 35 calendar days.
- Framework Friday close, hard stop, and kill switch remain authoritative.
- No trail, break-even, partial close, scale-in, hedge, pyramid, grid,
  martingale, or discretionary path exists.

## 10. Framework Alignment

- no_trade: exact carrier/D1/ID/slot, frozen inputs, Friday and news contracts.
- trade_entry: restart-safe D1 attempt, winter gate, completed rising trend
  stack, spread/ATR/quote/stop validation, one market BUY.
- trade_management: per-tick season, trend, wrong-side, and stale exits.
- trade_close: framework position close, Friday close, hard stop, kill switch.

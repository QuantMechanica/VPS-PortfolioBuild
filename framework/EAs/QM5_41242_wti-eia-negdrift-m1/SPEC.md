# QM5_41242 WTI EIA Negative Drift M1 — Strategy Spec

EA ID `41242`; source `ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026`; exact target
`XTIUSD.DWX` M1 slot 0; registered magic `412420000`.

## Strategy

On a standard Wednesday, the EA waits for the 10:30-10:31 New York M1 bar to
complete. If its close is strictly below its open, the bar is treated as a
price-only proxy for negative EIA WPSR news. The EA consumes the New York date,
enters one market short during seconds 0-29 of 10:31, and closes on the first
tick at or after 10:35 New York.

The peer-reviewed source reports a five-minute negative-news drift in crude-oil
futures. It classifies news from unexpected inventories, not price sign. The
M1 CFD proxy, remaining four-minute window, fixed risk, ATR stop, and spread
cap are explicit QM translations.

## Exact Entry Contract

- Exact host `XTIUSD.DWX`, M1, slot 0.
- Current bar label Wednesday 10:31 New York after broker/UTC/U.S.-DST
  conversion.
- Previous completed bar label same-date 10:30, exactly 60 broker seconds
  earlier.
- Valid positive finite OHLC with open and close inside high/low.
- Strict `close < open`; positive or equal stays flat.
- Persist `yyyymmdd` before history, signal, news, spread, quote, ATR, sizing,
  or submission. No retry that date.
- Entry only in seconds 0-29 of the 10:31 minute.
- SELL only, with one frozen `3.0 * ATR(20,M1)` hard stop and no target.
- Reject negative/crossed quote or positive spread above 1,500 points; zero
  modeled spread is accepted.

## Exit And State Contract

- Close at or after 10:35 New York on the entry date.
- Date change and ten elapsed minutes are survivor repairs.
- Close duplicate-magic, wrong-symbol, non-SELL, stopless, or otherwise
  malformed owned exposure.
- Framework kill switch and card-declared Friday close remain authoritative.
- No retry, long, reversal, pending order, target, trailing stop, break-even,
  partial exit, scale-in, pyramid, grid, martingale, optimization, external
  feed, or trained signal.

## Locked Inputs

| input | value |
|---|---:|
| `strategy_release_hhmm_ny` | 1030 |
| `strategy_decision_hhmm_ny` | 1031 |
| `strategy_flat_hhmm_ny` | 1035 |
| `strategy_entry_grace_seconds` | 30 |
| `strategy_atr_period_m1` | 20 |
| `strategy_atr_stop_multiple` | 3.0 |
| `strategy_max_hold_minutes` | 10 |
| `strategy_max_spread_points` | 1500 |

Both current news axes and legacy news mode are locked OFF. The standard
Wednesday proxy deliberately does not infer holiday-shifted releases; an
ordinary Wednesday in a shifted week is a declared false-label risk.

## Backtest Preset

Exactly one preset is authorized:
`sets/QM5_41242_wti-eia-negdrift-m1_XTIUSD.DWX_M1_backtest.set`.
It uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Falsification

Q02 retires on zero positions, fewer than five in any full scored year,
nonpositive governed economics, wrong event label, entry on a nonnegative bar,
long entry, duplicate date, missing stop, exit beyond the contract,
nondeterminism, invalid risk mode, or insufficient M1 history. Passing Q02
does not establish news classification, source-to-CFD equivalence,
profitability, decorrelation, or portfolio admission.

No live/demo/shadow/stress/optimization setfile, terminal control,
AutoTrading, `T_Live`, deploy manifest, portfolio-gate change, or correlation
waiver is authorized.

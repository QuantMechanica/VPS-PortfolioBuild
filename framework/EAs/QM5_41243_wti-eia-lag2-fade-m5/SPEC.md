# QM5_41243 WTI EIA Lag-2 Fade M5 — Strategy Spec

EA ID `41243`; source `YE-KARALI-EIA-WTI-LAG2-FADE-M5-2026`; exact target
`XTIUSD.DWX` M5 slot 0; registered magic `412430000`.

## Strategy

On a standard Wednesday, the EA waits for the 10:30-10:35 New York M5 bar to
complete. It trades opposite that completed bar's strict sign at 10:35 and
closes on the first tick at or after 10:45 New York, spanning the source
study's first two five-minute return lags.

The peer-reviewed source reports negative first- and second-lag coefficients
in a five-minute crude-oil futures return model around EIA announcements. It
does not prescribe this unconditional CFD price-sign rule. The M5 CFD proxy,
fixed risk, ATR stop, spread cap, and ten-minute trade are disclosed QM
translations.

## Exact Entry Contract

- Exact host `XTIUSD.DWX`, M5, slot 0.
- Current bar label Wednesday 10:35 New York after broker/UTC/U.S.-DST
  conversion.
- Previous completed bar label same-date 10:30, exactly 300 broker seconds
  earlier.
- Valid positive finite OHLC with open and close inside high/low.
- Strict `close > open` produces SELL; strict `close < open` produces BUY;
  equality stays flat.
- Persist `yyyymmdd` before history, signal, news, spread, quote, ATR, sizing,
  or submission. Persist the selected direction before remaining entry gates.
  No retry that date.
- Entry only in seconds 0-29 of the 10:35 bar.
- One frozen `3.0 * ATR(20,M5)` hard stop and no target.
- Reject negative/crossed quote or positive spread above 1,500 points; zero
  modeled spread is accepted.

## Exit And State Contract

- Close at or after 10:45 New York on the entry date.
- Date change and twenty elapsed minutes are survivor repairs.
- Close duplicate-magic, wrong-symbol, direction inconsistent with persisted
  state, stopless, or otherwise malformed owned exposure.
- Framework kill switch and card-declared Friday close remain authoritative.
- No retry, reversal, pending order, target, trailing stop, break-even, partial
  exit, scale-in, pyramid, grid, martingale, optimization, external feed, or
  trained signal.

## Locked Inputs

| input | value |
|---|---:|
| `strategy_release_hhmm_ny` | 1030 |
| `strategy_decision_hhmm_ny` | 1035 |
| `strategy_flat_hhmm_ny` | 1045 |
| `strategy_entry_grace_seconds` | 30 |
| `strategy_atr_period_m5` | 20 |
| `strategy_atr_stop_multiple` | 3.0 |
| `strategy_max_hold_minutes` | 20 |
| `strategy_max_spread_points` | 1500 |

Both current news axes and legacy news mode are locked OFF. The standard
Wednesday proxy deliberately does not infer holiday-shifted releases; an
ordinary Wednesday in a shifted week is a declared false-label risk.

## Backtest Preset

Exactly one preset is authorized:
`sets/QM5_41243_wti-eia-lag2-fade-m5_XTIUSD.DWX_M5_backtest.set`.
It uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

## Falsification

Q02 retires on zero positions, fewer than five in any full scored year,
nonpositive governed economics, wrong event label, same-sign entry, duplicate
date, missing stop, exit beyond the contract, nondeterminism, invalid risk
mode, or insufficient M5 history. Passing Q02 does not establish price-proxy
validity, source-to-CFD equivalence, profitability, decorrelation, or portfolio
admission.

No live/demo/shadow/stress/optimization setfile, terminal control,
AutoTrading, `T_Live`, deploy manifest, portfolio-gate change, or correlation
waiver is authorized.

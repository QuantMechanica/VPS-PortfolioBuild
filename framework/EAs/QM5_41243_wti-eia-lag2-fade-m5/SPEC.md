# QM5_41243 WTI EIA Lag-2 Fade M5 — Strategy Spec

**EA ID:** QM5_41243

**Source ID:** YE-KARALI-EIA-WTI-LAG2-FADE-M5-2026

**Registered magic:** 412430000

## 1. Strategy Logic

On a standard Wednesday, the EA waits for the 10:30-10:35 New York M5 bar to
complete. It trades opposite that completed bar's strict sign at 10:35 and
closes on the first tick at or after 10:45 New York, spanning the source
study's first two five-minute return lags.

The exact entry contract is:

- Convert broker timestamps through the framework broker-to-UTC and U.S.-DST
  helpers.
- Require the current bar label Wednesday 10:35 New York and the prior
  completed bar label same-date 10:30, exactly 300 broker seconds earlier.
- Require valid positive finite OHLC with open and close inside high/low.
- A strict `close > open` produces SELL; strict `close < open` produces BUY;
  equality stays flat.
- Persist the New York `yyyymmdd` before history, signal, news, spread, quote,
  ATR, sizing, or submission. Persist the selected direction before the
  remaining entry gates. Never retry that date.
- Enter only in seconds 0-29 of the 10:35 bar, with one frozen hard stop and
  no target.

## 2. Parameters

| input | locked value |
|---|---:|
| `strategy_release_hhmm_ny` | 1030 |
| `strategy_decision_hhmm_ny` | 1035 |
| `strategy_flat_hhmm_ny` | 1045 |
| `strategy_entry_grace_seconds` | 30 |
| `strategy_atr_period_m5` | 20 |
| `strategy_atr_stop_multiple` | 3.0 |
| `strategy_max_hold_minutes` | 20 |
| `strategy_max_spread_points` | 1500 |

Both current news axes and legacy news mode are locked OFF because WPSR is the
strategy event. Friday closure remains enabled at broker hour 21. There is no
optimization surface in Q02.

## 3. Symbol Universe

The exact host and traded symbol is `XTIUSD.DWX`, slot 0. The EA is
single-symbol only and rejects every other chart carrier through its locked
initialization contract. The governed active magic row maps slot 0 to
`412430000`.

## 4. Timeframe

Host, signal, ATR, and execution timeframe are all M5. The decision cadence is
one consumed attempt per standard Wednesday. Shifted holiday releases are not
inferred or traded on their shifted day; an ordinary Wednesday proxy during a
shifted week is a declared false-label risk.

## 5. Expected Behaviour

The expected research cadence is approximately 35-48 completed positions per
full year, but that estimate is not evidence. Q02 must prove at least five in
every full scored year.

Entry rejects an owned magic position, crossed or negative quote, or positive
spread above 1,500 points. A modeled zero spread is valid. Each accepted entry
has a frozen `3.0 * ATR(20,M5)` normalized broker stop and no take-profit.

Every tick, before entry-only gates, the EA closes at or after 10:45 New York,
on a New York date change, or after twenty elapsed minutes as a survivor
repair. It also closes duplicate-magic, wrong-symbol, direction inconsistent
with persisted state, stopless, or otherwise malformed owned exposure.
Framework kill-switch and Friday closure remain authoritative.

No retry, reversal, pending order, target, trailing stop, break-even, partial
exit, scale-in, pyramid, grid, martingale, external runtime feed, trained
signal, or portfolio-state dependency is allowed.

## 6. Source Citation

Ye, Shiyu, and Berna Karali (2016), “The informational content of inventory
announcements: Intraday evidence from crude oil futures market,” *Energy
Economics* 59, 349-364, DOI `10.1016/j.eneco.2016.08.011`.

The peer-reviewed source reports negative first- and second-lag coefficients
in a five-minute crude-oil futures return model around EIA announcements. It
does not prescribe this unconditional CFD price-sign rule. The M5 CFD proxy,
fixed risk, ATR stop, spread cap, and ten-minute trade are disclosed QM
translations. The exact standard release clock comes from the U.S. EIA Weekly
Petroleum Status Report schedule. Full bounded traceability is in the approved
card and governed source packet.

## 7. Risk Model

The only authorized backtest risk mode is `RISK_FIXED=1000`, with
`RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`. Signal magnitude never changes
risk. The attached broker hard stop is the intrabar backstop; all scheduled
and repair exits route through the framework transaction manager.

Exactly one preset is authorized:
`sets/QM5_41243_wti-eia-lag2-fade-m5_XTIUSD.DWX_M5_backtest.set`.

Q02 retires on zero positions, fewer than five in any full scored year,
nonpositive governed economics, wrong event label, same-sign entry, duplicate
date, missing stop, exit beyond the contract, nondeterminism, invalid risk
mode, or insufficient M5 history. Passing Q02 does not establish price-proxy
validity, source-to-CFD equivalence, profitability, decorrelation, or portfolio
admission.

No live/demo/shadow/stress/optimization setfile, terminal control,
AutoTrading, `T_Live`, deploy manifest, portfolio-gate change, or correlation
waiver is authorized.

# QM5_13107_wti-juldec-short - Strategy Spec

**EA ID:** QM5_13107  
**Slug:** `wti-juldec-short`  
**Source:** `EWALD-WTI-TRDTIME-2022`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-10

## 1. Strategy Logic

This EA implements a low-frequency WTI trading-time seasonal short on
`XTIUSD.DWX`. Ewald et al. (2022) find that fixed-maturity WTI futures prices
are highest when traded in July and lowest when traded in December, then test
a short-July, close-December rule. Because the Darwinex CFD cannot reproduce
matched futures maturities, the EA divides the July-November directional
exposure into non-overlapping weekly tranches: short on the first tradable D1
bar of each week and flatten through the V5 Friday-close mechanism.

This is not the cumulative-RSI2 commodity pullback in `QM5_12567`, a monthly
WTI premium/fade, a broad long summer-demand map, a trend/breakout, or an
inventory/event strategy. It has no price-direction filter; the return driver
is the source-defined trading-month risk-premium window.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_start_month` | 7 | fixed | First active broker-calendar month |
| `strategy_end_month` | 11 | fixed | Last active month before December cover |
| `strategy_atr_period` | 20 | 14, 20, 30 | D1 ATR for the hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR hard-stop distance |
| `strategy_max_hold_days` | 7 | 5-7 | Stale-position fallback exit |
| `strategy_max_spread_points` | 1500 | 1000-2000 | Entry spread cap |

The month window, weekly tranche frequency, short-only side, and Friday close
are locked and are not sweep axes.

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.
- No XNG, XAU, XAG, index, FX, futures-curve, or external-data leg.

## 4. Timeframe

- Base timeframe: D1.
- Entry gate: first tradable D1 bar of each broker-calendar week.
- Management gate: new D1 bar plus framework Friday-close ticks.

## 5. Expected Behaviour

- Expected completed trades/year/symbol: 20-23 before Q02 validation.
- Typical hold: first tradable bar of the week through Friday 21 broker time,
  with ATR stop and seven-day stale fallback.
- Risk mode for Q02: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Regime preference: seasonal WTI price decline from the paper's July trading-
  month high toward its December trading-month low.

## 6. Source Citation

Ewald, C.-O., Haugom, E., Lien, G., Stordal, S., and Wu, Y. (2022),
"Trading time seasonality in commodity futures: An opportunity for arbitrage
in the natural gas and crude oil markets?" *Energy Economics* 115, 106324.
DOI: https://doi.org/10.1016/j.eneco.2022.106324. The full open-access paper
is at https://eprints.gla.ac.uk/281581/1/281581.pdf; the implementation lineage
is Sections 3-5.2, especially Table 3.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, only if separately approved | RISK_PERCENT | portfolio allocation |

The paper's fixed-maturity futures construction is not equivalent to the
continuous CFD. Q02 must reject the port if frequency, economics, or report
validity fails. No live setfile, deploy manifest, portfolio gate, portfolio
admission file, `T_Live` path, or AutoTrading setting is part of this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | Initial mission-directed build | Compile and enqueue Q02 only |

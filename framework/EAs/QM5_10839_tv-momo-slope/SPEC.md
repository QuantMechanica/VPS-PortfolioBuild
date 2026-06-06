# QM5_10839_tv-momo-slope - Strategy Spec

**EA ID:** QM5_10839
**Slug:** tv-momo-slope
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades the Momentum Slope Navigator baseline on M15 bars. It builds a Squeeze-style momentum histogram from a bounded OHLC window and enters long when the histogram rises for the configured number of confirmed bars, with close above the EMA trend filter and ADX above the strength threshold. It enters short when the histogram falls for the configured number of confirmed bars, with close below the EMA filter and ADX above the same threshold. Exits use an initial ATR hard stop and an ATR trailing stop that activates only after price has moved by the configured ATR multiple.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_momentum_length | 20 | >=2 | Lookback for the Squeeze-style momentum histogram calculation. |
| strategy_consecutive_slope_bars | 2 | >=1 | Number of confirmed bars that must show rising or falling histogram slope. |
| strategy_use_ema_filter | true | true/false | Enables the EMA trend filter from the card baseline. |
| strategy_ema_period | 200 | >=2 | EMA period used for trend direction. |
| strategy_use_adx_filter | true | true/false | Enables the ADX strength filter from the card baseline. |
| strategy_adx_period | 14 | >=1 | ADX calculation period. |
| strategy_adx_threshold | 20.0 | >=0 | Normal preset threshold for trend strength. |
| strategy_atr_period | 14 | >=1 | ATR period for stop and trailing calculations. |
| strategy_atr_stop_mult | 1.5 | >0 | Initial hard-stop distance in ATR multiples. |
| strategy_trail_activation_mult | 1.5 | >0 | Open-profit ATR multiple required before trailing starts. |
| strategy_atr_trail_mult | 1.0 | >0 | ATR trailing-stop distance after activation. |
| strategy_max_stop_atr_mult | 3.0 | >0 | Max-stop filter expressed as ATR multiple. |
| strategy_max_spread_points | 0.0 | >=0 | Optional spread ceiling in points; 0 disables the extra spread ceiling. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card R3 FX member with liquid M15 history.
- GBPUSD.DWX - card R3 FX member with liquid M15 history.
- XAUUSD.DWX - card R3 metals member suited to volatility-normalized ATR exits.
- GDAXI.DWX - DWX matrix DAX equivalent for the card-stated GER40 leg.
- NDX.DWX - card R3 index member suited to trend-following momentum.

**Explicitly NOT for:**
- GER40.DWX - not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX instead.
- SPX500.DWX - not the canonical S&P 500 custom symbol; use SP500.DWX only when a card calls for SP500/SPX/SPY.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Not specified in frontmatter; expected intraday to multi-session from ATR trail behaviour. |
| Expected drawdown profile | Bounded ATR risk with trend-burst whipsaw risk. |
| Regime preference | trend-following momentum / volatility expansion |
| Win rate target (qualitative) | low to medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/bSGjA2Ie/ and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10839_tv-momo-slope.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10839_tv-momo-slope.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | ab334ce2-276a-4bf4-b256-d22f61475c04 |

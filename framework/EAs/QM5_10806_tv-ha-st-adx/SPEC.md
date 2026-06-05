# QM5_10806_tv-ha-st-adx - Strategy Spec

**EA ID:** QM5_10806
**Slug:** `tv-ha-st-adx`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `artifacts/cards_approved/QM5_10806_tv-ha-st-adx.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades on the close of each H4 bar. A long setup requires a bullish full-bodied Heiken Ashi candle, bullish SuperTrend direction, and ADX above the configured threshold when the ADX filter is enabled. A short setup requires the opposite full-bodied Heiken Ashi candle, bearish SuperTrend direction, and the same optional ADX trend-strength check. Positions close on an opposing full-bodied Heiken Ashi signal, the active ATR trailing stop, the 10-bar swing stop, the insurance stop, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_st_atr_period` | 10 | 1+ | ATR period used by SuperTrend. |
| `strategy_st_factor` | 3.0 | >0 | SuperTrend ATR multiplier. |
| `strategy_use_adx_filter` | true | true/false | Enables the ADX trend-strength filter. |
| `strategy_adx_period` | 14 | 1+ | ADX lookback period. |
| `strategy_adx_threshold` | 25.0 | 0+ | Minimum ADX value when the filter is enabled. |
| `strategy_wick_tolerance` | 0.10 | 0.0-1.0 | Maximum wick size as a fraction of Heiken Ashi candle range. |
| `strategy_stop_atr_period` | 14 | 1+ | ATR period for initial and trailing ATR stop. |
| `strategy_stop_atr_mult` | 2.0 | >0 | ATR stop multiplier. |
| `strategy_swing_lookback` | 10 | 1+ | Recent-bar swing high/low lookback for the swing stop. |
| `strategy_insurance_pct` | 2.0 | 0+ | Initial adverse-movement insurance stop percentage from entry. |
| `strategy_warmup_bars` | 220 | 40-300 practical | Closed-bar warmup depth for Heiken Ashi and SuperTrend state. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair in the card's portable P2 basket.
- `GBPUSD.DWX` - liquid major FX pair in the card's portable P2 basket.
- `USDJPY.DWX` - liquid major FX pair in the card's portable P2 basket.
- `XAUUSD.DWX` - available DWX gold symbol matching the card's `XAUUSD` exposure.
- `GDAXI.DWX` - available DAX custom symbol used for the card's unavailable `GER40.DWX` name.
- `NDX.DWX` - liquid US index symbol in the card's portable P2 basket.
- `WS30.DWX` - liquid US index symbol in the card's portable P2 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.
- `XAUUSD` - unsuffixed form is not used in registry/backtest context; mapped to `XAUUSD.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | multi-bar trend hold until opposing Heiken Ashi signal or stop |
| Expected drawdown profile | moderate trend-follower drawdown, bounded by fixed-risk sizing and stop layers |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/XWh2nzi1-Heiken-Ashi-Supertrend-ADX-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10806_tv-ha-st-adx.md`

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
| v1 | 2026-06-05 | Initial build from card | c7205c8e-e5d4-405a-acb7-bc1fc39b4f24 |

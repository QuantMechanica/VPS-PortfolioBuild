# QM5_11339_tc20-h1-15-ema5-21-rsi21-candle-pattern - Strategy Spec

**EA ID:** QM5_11339
**Slug:** `tc20-h1-15-ema5-21-rsi21-candle-pattern`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see approved card artifact)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades H1 closed-bar EMA trend reversals confirmed by RSI and a candle pattern. A long setup requires EMA(5) to have crossed above EMA(21) on the last closed bar or one bar earlier, RSI(21) above 50, and either a bullish engulfing candle or bullish hammer on the last closed bar. A short setup mirrors this with EMA(5) crossing below EMA(21), RSI(21) below 50, and either a bearish engulfing candle or bearish inverted-hammer mirror. Positions close when the closed-bar EMA relationship or RSI state reverses against the open side.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ema_period` | 5 | 1+ | Fast EMA period from the card. |
| `strategy_slow_ema_period` | 21 | greater than fast EMA | Slow EMA period from the card. |
| `strategy_rsi_period` | 21 | 1+ | RSI period from the card. |
| `strategy_rsi_midline` | 50.0 | 0-100 | RSI trend threshold. |
| `strategy_cross_lookback_bars` | 2 | 1+ | Allows the EMA cross on the signal bar or one closed bar earlier. |
| `strategy_use_atr_stop` | true | true/false | Uses the card's P2 ATR stop by default; false switches to swing structure stop. |
| `strategy_atr_period` | 14 | 1+ | ATR period for P2 stop placement. |
| `strategy_atr_sl_mult` | 1.5 | greater than 0 | ATR stop multiplier for P2. |
| `strategy_swing_lookback_bars` | 10 | 1+ | Swing low/high lookback if structure stop is selected. |
| `strategy_spread_cap_pips` | 20 | 0+ | Maximum non-zero modeled spread allowed by the card. |
| `strategy_allow_engulfing` | true | true/false | Enables engulfing candle confirmation. |
| `strategy_allow_hammer` | true | true/false | Enables hammer / inverted-hammer candle confirmation. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card primary H1 FX symbol, present in the DWX symbol matrix.
- `GBPUSD.DWX` - card primary H1 FX symbol, present in the DWX symbol matrix.
- `USDJPY.DWX` - card P2 expansion H1 FX symbol, present in the DWX symbol matrix.

**Explicitly NOT for:**
- Non-FX index, metal, crypto, or ETF symbols - the approved card is an H1 FX strategy and does not authorize cross-asset expansion.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `70` |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | not specified in card frontmatter |
| Regime preference | trend-following with candle confirmation |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** book / local PDF archive
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\376863900-20-Forex-Trading-Strategies-Collection.pdf`, Thomas Carter, 20 Forex Trading Strategies, Forex Trading Strategy #15
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11339_tc20-h1-15-ema5-21-rsi21-candle-pattern.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | 83184d24-4234-457f-8bd4-f42959bb2f5f |

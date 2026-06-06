# QM5_10837_tv-zscore-mr - Strategy Spec

**EA ID:** QM5_10837
**Slug:** tv-zscore-mr
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView source cited in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades mean reversion after a statistically stretched close. On each closed M15 bar it calculates close-price Z-score against a rolling mean and standard deviation, confirms exhaustion with RSI, optionally checks minimum Bollinger Band Width, and applies an EMA trend filter. It buys when Z-score is at or below the negative threshold, RSI is exhausted lower, and price is above the EMA filter; it sells when the inverse conditions hold. The primary exit is a bracket with 1.0 ATR stop and 1.5 ATR take profit; the optional equilibrium exit closes when Z-score reverts to zero.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_zscore_length | 20 | 20, 50, 100 | Rolling mean and standard deviation length for Z-score. |
| strategy_zscore_threshold | 2.0 | 1.5-2.5 | Absolute Z-score stretch needed for entry. |
| strategy_rsi_length | 14 | 14, 21 | RSI period used for exhaustion confirmation. |
| strategy_rsi_long_max | 35.0 | 30.0-40.0 | Long entries require RSI at or below this value. |
| strategy_rsi_short_min | 65.0 | 60.0-70.0 | Short entries require RSI at or above this value. |
| strategy_bbw_period | 20 | 20+ | Bollinger Band Width calculation period. |
| strategy_bbw_deviation | 2.0 | 1.0-3.0 | Bollinger deviation for width calculation. |
| strategy_bbw_min_width_pct | 0.0 | 0.0+ | Minimum band width as percent of middle band; 0 disables this ambiguous floor. |
| strategy_use_ema_filter | true | true / false | Enables the EMA trend alignment filter. |
| strategy_ema_period | 200 | 100, 200 | EMA period for trend alignment. |
| strategy_atr_period | 14 | 14+ | ATR period for stop and target distance. |
| strategy_atr_sl_mult | 1.0 | 1.0+ | Stop-loss distance in ATR multiples. |
| strategy_atr_tp_mult | 1.5 | 1.5+ | Take-profit distance in ATR multiples. |
| strategy_atr_min_points | 0.0 | 0.0+ | Minimum ATR in points; 0 disables this ambiguous floor. |
| strategy_use_equilibrium_exit | false | true / false | Enables optional Z-score reversion-to-zero exit. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid DWX FX major with OHLC, RSI, Bollinger, EMA, and ATR coverage.
- GBPUSD.DWX - liquid DWX FX major with the required indicator stack.
- USDJPY.DWX - liquid DWX FX major with the required indicator stack.
- XAUUSD.DWX - liquid DWX metal symbol included in the card's R3 basket.
- GDAXI.DWX - DAX index DWX symbol verified in the matrix and used as the available equivalent for the card-stated GER40.DWX.

**Explicitly NOT for:**
- GER40.DWX - named by the card but absent from `framework/registry/dwx_symbol_matrix.csv`; GDAXI.DWX is registered instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Expected trade frequency | not specified in card frontmatter |
| Typical hold time | not specified in card frontmatter |
| Expected drawdown profile | bounded ATR-risk mean reversion drawdowns during strong trends |
| Regime preference | mean reversion after statistical stretch with sufficient volatility |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/92rilzXd-Z-Score-Mean-Reversion-Pro/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10837_tv-zscore-mr.md`

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
| v1 | 2026-06-06 | Initial build from card | ba90ff05-ea31-4f26-904d-10738a9169d8 |

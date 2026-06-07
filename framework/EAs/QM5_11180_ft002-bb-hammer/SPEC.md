# QM5_11180_ft002-bb-hammer - Strategy Spec

**EA ID:** QM5_11180
**Slug:** `ft002-bb-hammer`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades long-only M5 oversold reversals. On each closed M5 bar it requires RSI(14) below 30, stochastic slow K below 20, close below the 20-period Bollinger lower band on typical price, and a hammer candle with a long lower wick. It enters at the next bar using a market buy, places a 10% protective stop, and uses the source ROI ladder for profit-taking. It also closes a profitable long when Parabolic SAR is above the closed-bar close and the Fisher transform of RSI is above 0.3.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | > 0 | RSI lookback used for entry and Fisher exit |
| `strategy_rsi_entry` | 30.0 | 20.0-35.0 | Maximum RSI value for long entry |
| `strategy_stoch_k` | 5 | > 0 | Stochastic K period |
| `strategy_stoch_d` | 3 | > 0 | Stochastic D period |
| `strategy_stoch_slowing` | 3 | > 0 | Stochastic slowing period |
| `strategy_stoch_slowk_entry` | 20.0 | 10.0-25.0 | Maximum stochastic slow K value for long entry |
| `strategy_bb_window` | 20 | 14-30 | Bollinger Band period |
| `strategy_bb_deviation` | 2.0 | > 0 | Bollinger Band standard deviation multiplier |
| `strategy_fisher_exit` | 0.30 | 0.10-0.50 | Minimum Fisher RSI value for SAR exit |
| `strategy_stoploss_pct` | 10.0 | 3.0-10.0 | Percent stop below entry |
| `strategy_roi_0_pct` | 5.0 | >= 0 | Profit-taking threshold from entry |
| `strategy_roi_20_pct` | 4.0 | >= 0 | Profit-taking threshold after 20 minutes |
| `strategy_roi_30_pct` | 3.0 | >= 0 | Profit-taking threshold after 30 minutes |
| `strategy_roi_60_pct` | 1.0 | >= 0 | Profit-taking threshold after 60 minutes |
| `strategy_exit_profit_only` | true | true/false | Source-faithful SAR/Fisher exits only while position is profitable |
| `strategy_atr_period` | 14 | > 0 | ATR period for the spread volatility guard |
| `strategy_max_spread_atr_pct` | 15.0 | >= 0 | Blocks entries when spread exceeds this percent of ATR |
| `strategy_psar_step` | 0.02 | > 0 | Parabolic SAR acceleration step |
| `strategy_psar_maximum` | 0.20 | > 0 | Parabolic SAR maximum acceleration |
| `strategy_psar_warmup_bars` | 120 | >= 30 | Bars used for bounded PSAR calculation |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` -- do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major from the card's primary P2 basket.
- `GBPUSD.DWX` - liquid FX major from the card's primary P2 basket.
- `USDJPY.DWX` - liquid FX major from the card's primary P2 basket.
- `XAUUSD.DWX` - liquid metal CFD from the card's primary P2 basket.

**Explicitly NOT for:**
- None specified by the approved card beyond the registered P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `45` |
| Typical hold time | About 189 minutes from the source README sample |
| Expected drawdown profile | Medium risk, bounded by 10% source stop and V5 fixed-risk sizing |
| Regime preference | Oversold mean-reversion after lower-band hammer reversals |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** GitHub strategy source
**Pointer:** Gerald Lonlas / freqtrade community, `Strategy002.py`, commit `dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`, https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/Strategy002.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11180_ft002-bb-hammer.md`

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
| v1 | 2026-06-07 | Initial build from card | 57360ec3-4bad-4062-a2f9-1972e0871963 |

# QM5_10439_mql5-asq-break - Strategy Spec

**EA ID:** QM5_10439
**Slug:** `mql5-asq-break`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

The EA trades completed M5-bar breakouts only when the EMA(150) and EMA(510) trend lines agree and are separated by at least 0.5 times ATR(14). A long entry requires price above both EMAs, a close above the prior 20-bar high plus 0.25 ATR, RSI(14) between 40 and 65, positive candle momentum, and H1 EMA(50) above EMA(200). A short entry mirrors those rules below the EMAs, below the prior 20-bar low minus 0.25 ATR, with RSI between 35 and 60 and H1 EMA(50) below EMA(200). Exits are the fixed 2R take-profit, the ATR stop, framework Friday close, and a move to break-even after price advances by 1R.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ema_period` | 150 | 1-1000 | Fast M5 EMA used for trend direction. |
| `strategy_slow_ema_period` | 510 | 1-2000 | Slow M5 EMA used for trend direction. |
| `strategy_atr_period` | 14 | 1-200 | ATR period for separation, breakout buffer, spread filter, and stop distance. |
| `strategy_ema_sep_atr_mult` | 0.50 | 0.0-5.0 | Minimum EMA separation as a fraction of M5 ATR. |
| `strategy_breakout_lookback` | 20 | 1-200 | Prior-bar high/low window for breakout confirmation. |
| `strategy_breakout_atr_buffer` | 0.25 | 0.0-5.0 | ATR buffer added to the breakout level. |
| `strategy_rsi_period` | 14 | 1-200 | RSI period for momentum-zone filter. |
| `strategy_long_rsi_min` | 40.0 | 0-100 | Lower RSI bound for long entries. |
| `strategy_long_rsi_max` | 65.0 | 0-100 | Upper RSI bound for long entries. |
| `strategy_short_rsi_min` | 35.0 | 0-100 | Lower RSI bound for short entries. |
| `strategy_short_rsi_max` | 60.0 | 0-100 | Upper RSI bound for short entries. |
| `strategy_use_h1_filter` | true | true/false | Enables the card baseline H1 EMA agreement filter. |
| `strategy_h1_fast_ema_period` | 50 | 1-500 | Fast H1 EMA for higher-timeframe agreement. |
| `strategy_h1_slow_ema_period` | 200 | 1-1000 | Slow H1 EMA for higher-timeframe agreement. |
| `strategy_sl_atr_mult` | 1.20 | 0.1-10.0 | M5 ATR multiple for baseline stop distance. |
| `strategy_h1_sl_cap_atr_mult` | 3.00 | 0.1-10.0 | H1 ATR multiple that caps the stop distance. |
| `strategy_tp_rr` | 2.00 | 0.1-10.0 | Fixed take-profit reward/risk multiple. |
| `strategy_session_start_hour` | 8 | 0-23 | Broker-hour session start for new entries. |
| `strategy_session_end_hour` | 20 | 1-24 | Broker-hour session end for new entries. |
| `strategy_friday_cutoff_hour` | 16 | 0-23 | Broker-hour Friday cutoff for new entries. |
| `strategy_max_spread_atr_frac` | 0.15 | 0.0-1.0 | Maximum spread as a fraction of M5 ATR. |
| `strategy_max_trades_per_day` | 3 | 1-20 | Daily cap on entries per symbol. |
| `strategy_breakeven_buffer_pips` | 0 | 0-100 | Stop buffer when moving to break-even after 1R. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - listed in the card's primary P2 basket for metals breakout scalping.
- `EURUSD.DWX` - listed in the card's primary P2 basket for liquid FX breakout scalping.
- `GBPUSD.DWX` - listed in the card's primary P2 basket for liquid FX breakout scalping.
- `XAGUSD.DWX` - listed in the card's primary P2 basket for metals breakout scalping.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the build only registers verified DWX symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `H1 EMA(50) / EMA(200)` and `H1 ATR(14)` stop cap |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday minutes to hours |
| Expected drawdown profile | Scalper-style fixed-risk drawdowns controlled by ATR stop, 2R target, and daily entry cap. |
| Regime preference | Breakout / trend continuation with volatility expansion. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/71189`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10439_mql5-asq-break.md`

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
| v1 | 2026-05-27 | Initial build from card | c417947a-538b-4fd2-b1b4-ec3815f95a18 |

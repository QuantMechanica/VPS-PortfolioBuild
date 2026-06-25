# QM5_9948_bandy-d1-setup-h1-trigger-mr-index - Strategy Spec

**EA ID:** QM5_9948
**Slug:** `bandy-d1-setup-h1-trigger-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016` (see `strategy-seeds/sources/9ef19e06-5ca6-5b35-aa06-b8187aa0e016/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

This EA trades the long-only index mean-reversion pattern from the card. On each H1 close, it checks the most recent closed D1 bar for RSI(4) at or below 30 and D1 close above SMA(200), then checks the closed H1 bar for RSI(2) at or below 10. If all conditions are true, it opens a long position at the next H1 bar with a 2.5 x ATR(14) H1 catastrophic stop. It exits when H1 RSI(2) reaches 70, when D1 close falls below SMA(200), or when the position has been open for 36 H1 hours.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_d1_rsi_period` | 4 | 1+ | D1 RSI period for the daily oversold setup. |
| `strategy_d1_rsi_threshold` | 30.0 | 0-100 | Maximum D1 RSI value allowed for long setup. |
| `strategy_d1_regime_sma_period` | 200 | 1+ | D1 SMA period used as the bullish regime gate. |
| `strategy_h1_rsi_period` | 2 | 1+ | H1 RSI period for entry trigger and exit trigger. |
| `strategy_h1_rsi_entry_threshold` | 10.0 | 0-100 | Maximum H1 RSI value allowed for long entry. |
| `strategy_h1_rsi_exit_threshold` | 70.0 | 0-100 | H1 RSI value that triggers strategy exit. |
| `strategy_h1_atr_period` | 14 | 1+ | H1 ATR period used for the catastrophic stop. |
| `strategy_cat_sl_atr_mult` | 2.5 | 0+ | ATR multiplier for the catastrophic stop below entry. |
| `strategy_time_stop_bars` | 36 | 1+ | Maximum holding time expressed as H1 hours. |
| `strategy_session_start_hour_broker` | 16 | 0-23 | Broker-time H1 bar hour treated as the first US index session bar and skipped for entry. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index proxy named by the card as the backtest target.
- `NDX.DWX` - Nasdaq 100 live-tradable US large-cap index proxy in the card's R3 basket.
- `WS30.DWX` - Dow 30 live-tradable US large-cap index proxy in the card's R3 basket.

**Explicitly NOT for:**
- `SPX500.DWX` - Not present in the DWX symbol matrix; `SP500.DWX` is the canonical S&P 500 custom symbol.
- `SPY.DWX` - Not present in the DWX symbol matrix and not broker-routable.
- `ES.DWX` - Not present in the DWX symbol matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `PERIOD_D1` RSI(4), SMA(200), and D1 close; `PERIOD_H1` RSI(2) and ATR(14) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `40` |
| Typical hold time | `up to 36 H1 bars` |
| Expected drawdown profile | Bounded by 2.5 x H1 ATR catastrophic stop on each trade. |
| Regime preference | Mean-reversion inside bullish D1 index regime. |
| Win rate target (qualitative) | Medium to high due to oversold long-only reversion design. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** `book`
**Pointer:** Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1, URL: https://books.google.com/books?isbn=9780979103771
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9948_bandy-d1-setup-h1-trigger-mr-index.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-25 | Initial build from card | 03bde224-f8f4-41e2-bcdb-543fda1716da |

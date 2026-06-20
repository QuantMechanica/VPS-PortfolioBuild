# QM5_9981_bandy-d1-setup-m30-trigger-mr-index - Strategy Spec

**EA ID:** QM5_9981
**Slug:** `bandy-d1-setup-m30-trigger-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA is a long-only multi-timeframe index mean-reversion system. On each closed M30 bar it enters long when the last closed D1 RSI(4) is at or below 30, the last closed D1 close is above its D1 SMA(200), and the last closed M30 RSI(2) is at or below 10. It places a catastrophic stop 2.5 * ATR(14) below the entry price. It exits when M30 RSI(2) reaches 70 or higher, when the D1 close is no longer above SMA(200), or after 48 M30 bars in the trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_d1_rsi_period` | 4 | 1+ | D1 RSI lookback for the setup condition. |
| `strategy_d1_rsi_oversold` | 30.0 | 0-100 | Maximum D1 RSI value allowed for setup. |
| `strategy_d1_sma_period` | 200 | 1+ | D1 SMA period used as the bullish regime filter. |
| `strategy_m30_rsi_period` | 2 | 1+ | M30 RSI lookback for trigger and exit. |
| `strategy_m30_rsi_trigger` | 10.0 | 0-100 | Maximum M30 RSI value allowed for long entry. |
| `strategy_m30_rsi_exit` | 70.0 | 0-100 | M30 RSI value that triggers a strategy exit. |
| `strategy_atr_period` | 14 | 1+ | M30 ATR period used for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.5 | >0 | ATR multiple below entry for the stop loss. |
| `strategy_time_stop_m30_bars` | 48 | 1+ | Maximum holding period in M30 bars. |
| `strategy_skip_first_session_bar` | true | true/false | Blocks entries when the trigger bar is the first M30 bar of the configured session. |
| `strategy_session_start_hhmm` | 1630 | 0000-2359 | Broker-time HHMM of the first regular US index cash-session M30 bar. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index exposure; card primary backtest symbol and valid custom DWX symbol.
- `NDX.DWX` - Nasdaq 100 index exposure; card portable live-validation symbol.
- `WS30.DWX` - Dow 30 index exposure; card portable live-validation symbol.

**Explicitly NOT for:**
- Non-index FX, metals, energy, or single-stock symbols - the card specifies an index mean-reversion universe only.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable or non-canonical S&P variants; `SP500.DWX` is the canonical DWX symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `D1` RSI(4), D1 SMA(200), and closed D1 close for regime checks |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Up to 48 M30 bars, about 4 index cash sessions per the card |
| Expected drawdown profile | Bounded by 2.5 * ATR(14) catastrophic stop per trade |
| Regime preference | Bullish-regime mean reversion after intraday oversold pushes |
| Win rate target (qualitative) | Medium to high for a mean-reversion exit profile |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`  
**Source type:** book  
**Pointer:** Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1; Google Books ISBN URL in the approved card.  
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_9981_bandy-d1-setup-m30-trigger-mr-index.md`

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
| v1 | 2026-06-20 | Initial build from card | 01c927ae-34da-4655-9b66-eced110a12ff |

# QM5_11563_connors-rsi2-sma200-mean-reversion-d1 — Strategy Spec

**EA ID:** QM5_11563
**Slug:** `connors-rsi2-sma200-mean-reversion-d1`
**Source:** `278c6e13-0726-5779-83fe-a38f5a2e480f` (see `strategy-seeds/sources/278c6e13-0726-5779-83fe-a38f5a2e480f/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Connors 2-period RSI mean reversion with a 200-period SMA trend filter, adapted
from US equities to D1 Forex. On each new D1 bar the EA reads the last closed
bar (shift 1): if the close is above SMA(200) and RSI(2) is below 10 (deep
short-term oversold within an uptrend), it buys at market; the mirror short
fires when the close is below SMA(200) and RSI(2) is above 90. A long is closed
when RSI(2) rises back above 65; a short is closed when RSI(2) falls below 35.
The original book uses no stop ("stops hurt"); P2 adds a safety stop of 2×ATR(14)
from entry, capped at 150 pips. New entries are skipped on Fridays and when the
spread exceeds 15 pips; exits and stops keep running through those windows.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 200 | 50-200 | SMA trend-filter period |
| `strategy_rsi_period` | 2 | 2-5 | RSI period (Connors RSI2) |
| `strategy_rsi_entry_long` | 10.0 | 5-15 | LONG entry: RSI(2)[1] below this in an uptrend |
| `strategy_rsi_entry_short` | 90.0 | 85-95 | SHORT entry: RSI(2)[1] above this in a downtrend |
| `strategy_rsi_exit_long` | 65.0 | 55-75 | LONG exit: close when RSI(2)[1] above this |
| `strategy_rsi_exit_short` | 35.0 | 25-45 | SHORT exit: close when RSI(2)[1] below this |
| `strategy_atr_period` | 14 | 10-20 | ATR period for the safety stop |
| `strategy_atr_sl_mult` | 2.0 | 1.5-2.5 | Safety-stop distance = mult × ATR(14) |
| `strategy_sl_cap_pips` | 150 | 50-200 | Safety-stop distance cap (pips) |
| `strategy_spread_cap_pips` | 15 | 5-30 | Block new entries when spread exceeds this (pips) |
| `strategy_no_friday_entry` | true | true/false | Skip new entries on Fridays (exits still run) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid major; clean D1 mean-reversion behaviour around trend.
- `GBPUSD.DWX` — liquid major with slightly higher D1 volatility; same regime logic.
- `USDJPY.DWX` — liquid major; pip-scale handled by the framework (3-digit pip factor) for the ATR/cap stop.

**Explicitly NOT for:**
- Index / metal CFDs (e.g. `NDX.DWX`, `XAUUSD.DWX`) — the RSI(2)/SMA(200) thresholds and 150-pip cap were sized for D1 FX majors, not index-scale ranges.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~8 (5-10 range)` |
| Typical hold time | `days (RSI(2) reverts within 1-5 D1 bars)` |
| Expected drawdown profile | `~18% expected DD; occasional loser stopped at 2×ATR / 150-pip cap` |
| Regime preference | `mean-revert (oversold/overbought pullbacks inside the SMA200 trend)` |
| Win rate target (qualitative) | `high` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `278c6e13-0726-5779-83fe-a38f5a2e480f`
**Source type:** `book`
**Pointer:** `strategy-seeds/sources/278c6e13-0726-5779-83fe-a38f5a2e480f/` — Larry Connors & Cesar Alvarez, "Short-Term Trading Strategies That Work" (TradingMarkets Publishing, 2009), Strategies 8-9 "The 2-Period RSI".
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11563_connors-rsi2-sma200-mean-reversion-d1.md`

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
| v1 | 2026-08-10 | Initial build from card | e26b6273-3c6a-478b-8f2a-b5004e32d85f |

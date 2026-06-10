# QM5_9413_mql5-paq-marubozu — Strategy Spec

**EA ID:** QM5_9413
**Slug:** `mql5-paq-marubozu`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb` (see `strategy-seeds/sources/ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb/`)
**Author of this spec:** Claude (Build task ca7a766f-9186-44a6-a088-80ed301c6e8d)
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On every closed H1 bar the EA detects a Marubozu candle: a bar whose body covers at least 90% of the total high-low range and whose upper and lower wicks each stay below the remaining 10% of the range. An additional range filter requires the total bar range to be at least one ATR(14) in size, preventing entries on abnormally narrow bars. A buy is triggered when a bullish Marubozu (close above open) closes above the 50-period EMA; a sell when a bearish Marubozu closes below it. Stop loss is placed below the Marubozu low (buy) or above the Marubozu high (sell) by 0.25 × ATR(14). Take profit is set at 1.5 × risk distance from entry. The position is also closed early on a close back through the 20-period EMA against the trade, on the appearance of an opposite-direction Marubozu, or after 18 H1 bars have elapsed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_marubozu_ratio` | 0.90 | 0.70–0.98 | Minimum body/total-range ratio; lower = more signals, less purity |
| `strategy_atr_period` | 14 | 5–30 | ATR period for range filter and SL distance |
| `strategy_atr_sl_mult` | 0.25 | 0.1–1.0 | SL placed at bar extreme ± ATR × this multiplier |
| `strategy_ema_trend_period` | 50 | 20–200 | EMA period for trend direction filter |
| `strategy_ema_exit_period` | 20 | 5–50 | EMA period for close-back exit |
| `strategy_tp_risk_mult` | 1.5 | 1.0–3.0 | TP at entry ± risk × this multiplier |
| `strategy_time_exit_bars` | 18 | 5–50 | Maximum hold time in H1 bars before forced exit |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — high liquidity major FX pair; Marubozu signals are clean and spreads are tight
- `GBPUSD.DWX` — volatile major FX; produces well-defined momentum bars with clear direction
- `XAUUSD.DWX` — gold exhibits strong directional Marubozu continuation during macro-driven sessions
- `GDAXI.DWX` — German equity index; intraday momentum candles align with European session openings

**Explicitly NOT for:**
- Monthly (MN1) or very low-frequency instruments — Marubozu signals require sufficient bar frequency
- SP500.DWX not included in this EA; card targets the four symbols above

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~40 |
| Typical hold time | 4–18 hours (H1 bars) |
| Expected drawdown profile | Momentum strategy; expects short sequences of consecutive losses on choppy markets |
| Regime preference | momentum-continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** forum/article
**Pointer:** Christian Benjamin, "Price Action Analysis Toolkit Development (Part 24): Price Action Quantification Analysis Tool", MQL5 Articles, 2025-05-22, https://www.mql5.com/en/articles/18207
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9413_mql5-paq-marubozu.md`

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
| v1 | 2026-06-10 | Initial build from card | ca7a766f-9186-44a6-a088-80ed301c6e8d |

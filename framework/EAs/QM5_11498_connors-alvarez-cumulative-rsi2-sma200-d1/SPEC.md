# QM5_11498_connors-alvarez-cumulative-rsi2-sma200-d1 — Strategy Spec

**EA ID:** QM5_11498
**Slug:** `connors-alvarez-cumulative-rsi2-sma200-d1`
**Source:** e2807d63-4109-5824-8d44-1800ee8fe7eb
**Author of this spec:** Codex
**Last revised:** 2026-08-09

---

## 1. Strategy Logic

On each completed D1 bar, the EA buys when the close is above SMA(200) and the sum of RSI(2) for the latest two closed bars is below 45. It sells when the close is below SMA(200) and that same sum is above 55. Each order receives a two-ATR(14) protective stop unless that distance exceeds 100 pips, and an open position closes when its side-specific RSI(2) recovery level is reached or after 10 completed D1 holding bars.

The source says to enter at the signal-bar close. Under the V5 closed-bar contract, the executable implementation submits at market on the first tick of the next D1 bar after the signal is known.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_D1` | fixed | Card-native signal and holding timeframe. |
| `strategy_rsi_period` | 2 | 2–3 | RSI period; the card lists 2 and the P3 sweep also lists 3. |
| `strategy_cum_window` | 2 | 2–3 | Number of closed RSI observations summed for entry. |
| `strategy_sma_period` | 200 | fixed | Long-term trend filter period. |
| `strategy_entry_long` | 45.0 | 35–45 | Long entry requires cumulative RSI below this level. |
| `strategy_entry_short` | 55.0 | fixed | Short entry requires cumulative RSI above this card-stated mirror level. |
| `strategy_exit_long` | 65.0 | 55–65 | Long exit requires single-bar RSI above this level. |
| `strategy_exit_short` | 35.0 | fixed | Short exit requires single-bar RSI below this card-stated mirror level. |
| `strategy_atr_period` | 14 | fixed | ATR period used for the protective stop. |
| `strategy_atr_stop_mult` | 2.0 | 1.5–3.0 | ATR multiple used for the initial stop distance. |
| `strategy_max_stop_pips` | 100 | fixed | Skip an entry when its ATR stop would exceed this pip distance. |
| `strategy_max_hold_bars` | 10 | 7–15 | Maximum completed D1 holding bars before exit. |
| `strategy_spread_cap_pips` | 30 | fixed | Entry is blocked only when the positive modeled spread exceeds this cap. |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid daily FX major named by the approved card.
- `GBPUSD.DWX` — liquid daily FX major named by the approved card.
- `USDJPY.DWX` — liquid daily FX major named by the approved card.
- `AUDUSD.DWX` — liquid daily FX major named by the approved card.
- `USDCAD.DWX` — liquid daily FX major named by the approved card.

**Explicitly NOT for:**

- Other symbols — they are outside this card's approved five-symbol P2 universe and are not registered for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on a D1 chart; D1 calendar cadence is used for closed-bar exits |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 30 |
| Expected trade frequency | approximately 2–3 entries per month per symbol |
| Typical hold time | short daily mean-reversion hold, capped at 10 completed D1 bars |
| Expected drawdown profile | not quantified by the card; losses can cluster when a pullback continues instead of reverting |
| Regime preference | short-term mean reversion inside the SMA(200) long-term trend state |
| Win rate target (qualitative) | not specified by the approved card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** e2807d63-4109-5824-8d44-1800ee8fe7eb
**Source type:** book
**Pointer:** Larry Connors and Cesar Alvarez, *Short-Term Trading Strategies That Work*, TradingMarkets Publishing LLC, 2009, chapter “The Cumulative RSI Strategy”; local source page `sources/connors-alvarez-short-term-trading-strategies-2009`.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11498_connors-alvarez-cumulative-rsi2-sma200-d1.md`.

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
| v1 | 2026-08-09 | Initial build from card | 0c154a88-02de-443f-9960-8105c48e7f2d |

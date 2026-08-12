# QM5_9973_bandy-ibs-extreme-mr-index — Strategy Spec

**EA ID:** QM5_9973
**Slug:** bandy-ibs-extreme-mr-index
**Source:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Author of this spec:** Codex
**Last revised:** 2026-08-02

---

## 1. Strategy Logic

On each completed D1 bar, the EA calculates Internal Bar Strength as `(close - low) / (high - low)`. It opens a long position at the next bar's first tradable price when IBS is at or below 0.15, the close is above its 200-day simple moving average, and the bar range is at least 0.20 times ATR(14). It exits when closed-bar IBS reaches 0.60, after 10 completed D1 holding bars, or through the server-side catastrophic stop placed 2.5 times ATR(14) below entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_ibs_entry_threshold` | 0.15 | 0.10–0.25 | Maximum closed-bar IBS allowed for a long entry. |
| `strategy_ibs_exit_threshold` | 0.60 | 0.50–0.70 | Minimum closed-bar IBS that completes the mean-reversion exit. |
| `strategy_regime_sma_period` | 200 | 100–300 | D1 SMA period for the long-only bullish regime gate. |
| `strategy_atr_period` | 14 | 14 (card-fixed) | D1 ATR period used by the range filter and catastrophic stop. |
| `strategy_atr_sl_mult` | 2.5 | 2.0–3.0 | Catastrophic stop distance as a multiple of ATR. |
| `strategy_time_stop_bars` | 10 | 5–15 | Maximum number of completed D1 holding bars. |
| `strategy_narrow_range_atr_mult` | 0.20 | 0.10–0.30 | Minimum closed-bar range as a multiple of ATR before entry. |

Framework-level risk, news, random-seed, stress, portfolio-weight, and Friday-close inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `SP500.DWX` — broad S&P 500 index exposure and the card's primary US-index test substrate.
- `NDX.DWX` — liquid Nasdaq 100 index exposure portable to the same daily index mean-reversion rule.
- `WS30.DWX` — liquid Dow 30 index exposure portable to the same daily index mean-reversion rule.

**Explicitly NOT for:**

- Non-index `.DWX` symbols — the approved source/card confines the IBS asymmetry thesis to US equity-index exposure.
- Non-US index `.DWX` symbols — they are outside the card's R3 PASS basket and were not registered for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the D1 chart; closed-bar reads use shift 1 |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 36 |
| Expected trade frequency | approximately one qualifying setup per seven D1 bars in the long regime |
| Typical hold time | until IBS reaches 0.60, capped at 10 completed D1 bars |
| Expected drawdown profile | each trade has a 2.5 × ATR catastrophic stop; portfolio drawdown was not specified by the card |
| Regime preference | long-only daily mean reversion while price is above the 200-day SMA |
| Win rate target (qualitative) | not specified by the approved card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Source type:** book
**Pointer:** Howard B. Bandy, *Quantitative Technical Analysis* (2015), ISBN 978-0-9791037-7-1, https://books.google.com/books?isbn=9780979103771
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_9973_bandy-ibs-extreme-mr-index.md`.

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
| v1 | 2026-08-02 | Initial build from card | f89f376a-cd2b-4b6b-806c-1654f153c726 |

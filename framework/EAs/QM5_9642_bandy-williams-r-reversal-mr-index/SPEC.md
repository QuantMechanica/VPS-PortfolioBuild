# QM5_9642_bandy-williams-r-reversal-mr-index — Strategy Spec

**EA ID:** QM5_9642
**Slug:** `bandy-williams-r-reversal-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Author of this spec:** Codex
**Last revised:** 2026-08-02

---

## 1. Strategy Logic

On each completed D1 bar, the EA enters long at the next available market price when Williams %R(10) is at or below -90 and the close is above its 200-day simple moving average. It skips an entry when ATR(14) divided by close ranks in the highest 1% of the 252 closed D1 observations. The position has an initial stop two ATR below entry and closes when Williams %R returns to -50 or higher, or after six completed D1 trading bars; short entries and pyramiding are disabled.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_wpr_period` | 10 | 5–14 | Closed-D1 Williams %R lookback. |
| `strategy_wpr_entry_threshold` | -90 | -95–-80 | Enter long at or below this oversold level. |
| `strategy_wpr_exit_threshold` | -50 | -50–0 | Exit when Williams %R recovers to or above this level. |
| `strategy_regime_sma_period` | 200 | 100–300 | Bull-regime SMA lookback on D1 closes. |
| `strategy_atr_period` | 14 | fixed | ATR lookback for the initial hard stop and volatility filter. |
| `strategy_atr_sl_mult` | 2.0 | fixed | Initial stop distance in ATR multiples. |
| `strategy_max_hold_d1_bars` | 6 | 4–10 | Maximum completed D1 trading bars held. |
| `strategy_vol_percentile_lookback` | 252 | fixed | Closed D1 observations used to rank ATR/close. |
| `strategy_vol_top_percent` | 1.0 | fixed | Highest volatility percentile in which entries are suppressed. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — canonical S&P 500 custom-symbol alias for the card's US large-cap index exposure.
- `NDX.DWX` — liquid Nasdaq 100 index proxy in the card's portable R3 basket.
- `WS30.DWX` — liquid Dow 30 index proxy in the card's portable R3 basket.

**Explicitly NOT for:**
- Non-index symbols — the source rule and long-only SMA regime premise are specific to diversified equity indices.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Expected trade frequency | Approximately monthly; the frontmatter gives no separate frequency label. |
| Typical hold time | Up to 6 completed D1 trading bars; no separate frontmatter value is supplied. |
| Expected drawdown profile | Mean-reversion losses can cluster during persistent selloffs; card expectation is 17% drawdown. |
| Regime preference | Long-only equity-index mean reversion while price remains above SMA(200). |
| Win rate target (qualitative) | Not stated in the approved card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** book
**Pointer:** Howard Bandy, *Quantitative Technical Analysis*, Blue Owl Press, 2015, ISBN 978-0-9791037-7-1; approved card at `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9642_bandy-williams-r-reversal-mr-index.md`.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_9642_bandy-williams-r-reversal-mr-index.md`.

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
| v1 | 2026-08-02 | Initial build from card | a270ebef-3c92-4949-bb45-47867cb66fec |


<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_9645_bandy-stochastic-extreme-mr-index — Strategy Spec

**EA ID:** QM5_9645
**Slug:** `bandy-stochastic-extreme-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Author of this spec:** Codex
**Last revised:** 2026-08-03

---

## 1. Strategy Logic

On each completed D1 bar, the EA buys at the next session open when slow
Stochastic(14,3,3) has both %K at or below 20 and %D at or below 25, while the
close remains above its 200-day SMA. It skips the highest-volatility one percent
of the trailing 252-bar ATR(14)/close distribution. The position has a hard stop
2.2 ATR below entry and closes after a completed bar with %K at or above 50, or
after eight trading days, whichever happens first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_k_period` | 14 | P3: 9 / 14 / 21 | Stochastic raw-K lookback. |
| `strategy_smoothing` | 3 | P3: 1 / 3 / 5 | SMA smoothing used for both slow %K and %D. |
| `strategy_entry_k_max` | 20.0 | P3: 15 / 20 / 25 | Highest %K allowed for a long entry. |
| `strategy_entry_d_max` | 25.0 | P3: 20 / 25 / 30 | Highest %D allowed for a confirmed long entry. |
| `strategy_exit_k_min` | 50.0 | P3: 40 / 50 / 60 | %K midline threshold that closes the position. |
| `strategy_regime_sma_period` | 200 | P3: 100 / 200 / 300 | Long-only bullish-regime SMA period. |
| `strategy_atr_period` | 14 | Card-fixed | ATR period for the hard stop and volatility filter. |
| `strategy_atr_sl_mult` | 2.2 | Card-fixed | Initial stop distance in ATR multiples. |
| `strategy_max_hold_days` | 8 | P3: 5 / 8 / 12 | Maximum completed D1 holding periods. |
| `strategy_volatility_lookback` | 252 | Card-fixed | Closed D1 ratios used by the volatility percentile filter. |
| `strategy_volatility_percentile` | 99.0 | Card-fixed | Nearest-rank ATR/close percentile at or above which entry is skipped. |

> Note: framework-level inputs are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `SP500.DWX` — broad S&P 500 custom-symbol proxy specified by the card.
- `NDX.DWX` — liquid Nasdaq 100 index proxy in the card's portable basket.
- `WS30.DWX` — liquid Dow 30 index proxy in the card's portable basket.

**Explicitly NOT for:**

- Non-index symbols — the approved thesis is a long-only equity-index mean-reversion effect.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` on D1 setfiles |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 10 |
| Expected trade frequency | low; approximately 10 entries per year per symbol |
| Typical hold time | one to eight trading days |
| Expected drawdown profile | approximately 17% expected drawdown per card frontmatter |
| Regime preference | long-only mean reversion while the close is above SMA(200) |
| Win rate target (qualitative) | not specified by the approved card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** book
**Pointer:** Howard Bandy, *Quantitative Technical Analysis* (Blue Owl Press,
2015, ISBN 978-0-9791037-7-1), as recorded in the approved card.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per
`artifacts/cards_approved/QM5_9645_bandy-stochastic-extreme-mr-index.md`.

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
| v1 | 2026-08-03 | Initial build from card | 44dd91ac-d750-478c-80cb-451a28ceda0c |


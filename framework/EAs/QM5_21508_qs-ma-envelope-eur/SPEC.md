# QM5_21508_qs-ma-envelope-eur — Strategy Spec

**EA ID:** QM5_21508
**Slug:** `qs-ma-envelope-eur`
**Source:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Author of this spec:** Codex
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

On each completed EURUSD D1 bar, the EA computes a simple moving average and fixed-percentage bands: `Upper = SMA × (1 + envelope_pct)` and `Lower = SMA × (1 - envelope_pct)`. It buys a fresh close below the lower band or sells a fresh close above the upper band; “fresh” means the prior close was inside or exactly on its corresponding prior band. A long exits when a completed close is at or above the SMA, a short exits when it is at or below the SMA, and either side also exits through its entry-time ATR hard stop, after the configured completed-bar hold limit, or through the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ma_period` | 20 | 14, 20, 30 | D1 simple-moving-average period used for the envelope centre. |
| `strategy_envelope_pct` | 0.015 | 0.01, 0.015, 0.02, 0.03 | Proportional distance of each band from the SMA. |
| `strategy_atr_period` | 14 | 10, 14, 20 | D1 ATR period used to fix the entry stop distance. |
| `strategy_atr_sl_mult` | 2.0 | 1.5, 2.0, 2.5 | Multiple of completed-signal-bar ATR used for the hard stop. |
| `strategy_max_hold_bars` | 20 | 10, 20, 30 | Maximum completed D1 bars held before the stale-position exit. |
| `strategy_max_spread_points` | 20.0 | 10, 20, 30 | Maximum positive entry spread in MT5 points; zero modeled spread remains valid. |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — the approved card is a price-only, low-cost EURUSD mean-reversion strategy and explicitly requires a single-symbol baseline.

**Explicitly NOT for:**

- All other `.DWX` symbols — the card declares `single_symbol_only: true`; portability expansion would change the approved experiment.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` in the canonical framework entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 25 completed round trips |
| Typical hold time | several D1 bars, hard-capped at 20 completed D1 bars |
| Expected drawdown profile | medium risk; card estimate 18% drawdown |
| Regime preference | range-bound / mean-reverting EURUSD regimes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0b564ef2-810c-5b1d-9084-342ddb20575c`

**Source type:** public trading article

**Pointer:** QuantifiedStrategies.com, “Moving Average Envelope - Strategy, Rules, Returns,” https://www.quantifiedstrategies.com/moving-average-envelope/

**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `D:/QM/strategy_farm/artifacts/cards_approved/QM5_21508_qs-ma-envelope-eur.md`.

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
| v1 | 2026-08-24 | Initial build from card | build-QM5_21508_qs-ma-envelope-eur |

# QM5_9269_mql5-gator-ad-hidden — Strategy Spec

**EA ID:** QM5_9269
**Slug:** `mql5-gator-ad-hidden`
**Source:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Author of this spec:** Codex
**Last revised:** 2026-07-10

---

## 1. Strategy Logic

On each closed H4 bar, the EA looks for both Gator histogram magnitudes to contract on the pullback bar and expand on the current bar. It buys when price holds a higher pullback low and the cumulative Accumulation/Distribution line reaches a three-bar high; it sells on the mirrored lower-high and A/D-low pattern. The stop sits 0.5 ATR beyond the pullback extreme, the target is 2.5 times initial risk, and the trade also exits on two consecutive red Gator bars, a three-bar A/D reversal, a close through the pullback level, or after 24 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_gator_jaw_period` | 13 | 5–34 | Jaw SMMA period on median price. |
| `strategy_gator_jaw_shift` | 8 | 0–13 | Jaw forward displacement. |
| `strategy_gator_teeth_period` | 8 | 3–21 | Teeth SMMA period on median price. |
| `strategy_gator_teeth_shift` | 5 | 0–8 | Teeth forward displacement. |
| `strategy_gator_lips_period` | 5 | 2–13 | Lips SMMA period on median price. |
| `strategy_gator_lips_shift` | 3 | 0–5 | Lips forward displacement. |
| `strategy_atr_period` | 14 | 5–50 | ATR period for volatility gate and stop buffer. |
| `strategy_atr_percentile_bars` | 100 | 20–250 | Historical ATR observations used by the activity gate. |
| `strategy_atr_min_percentile` | 0.20 | 0.0–1.0 | Minimum rank of current ATR in its history. |
| `strategy_structure_atr_buffer` | 0.50 | 0.1–2.0 | ATR distance beyond the pullback extreme. |
| `strategy_take_profit_rr` | 2.50 | 1.0–5.0 | Take-profit multiple of initial risk. |
| `strategy_time_stop_bars` | 24 | 1–60 | Maximum holding time in H4 bars. |
| `strategy_spread_cap_points` | 1000 | 0–5000 | Entry guard for a genuinely positive modeled spread. |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major-FX baseline from the approved card.
- `GBPJPY.DWX` — JPY cross adds the card's highest instrument-diversity exposure.
- `XAUUSD.DWX` — liquid metal tests whether the structural volume-continuation edge ports beyond FX.

**Explicitly NOT for:**

- Symbols outside `dwx_symbol_matrix.csv` — no validated Darwinex-native test history.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 25 |
| Typical hold time | several H4 bars, capped at 4 days |
| Expected drawdown profile | clustered losses during range-bound false resumptions |
| Regime preference | established trends resuming after volume-confirmed pullbacks |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `ba57d97a-0ee0-5a87-aa6d-fb5a37f08bdb`
**Source type:** MQL5 article
**Pointer:** `https://www.mql5.com/en/articles/18992`, Pattern 7 “Hidden Volume Divergence”
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9269_mql5-gator-ad-hidden.md`

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
| v1 | 2026-07-10 | Initial build from card | build task `98682952-8410-49c6-9ec8-9f0f33a92ffc` |

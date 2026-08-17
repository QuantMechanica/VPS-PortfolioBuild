# QM5_21512_qs-fibonacci-ma-band-gbp - Strategy Spec

**EA ID:** QM5_21512
**Slug:** `qs-fibonacci-ma-band-gbp`
**Source:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Author of this spec:** Claude
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

This EA trades a Fibonacci Moving Average (FMA) composite-band breakout on
GBPUSD D1. Six EMAs at Fibonacci-numbered lookback periods ({13, 21, 34, 55,
89, 144} — the central six terms of the source's disclosed pool) are computed
on the High series and averaged into an upper band line; the same six periods
computed on the Low series and averaged form a lower band line. This produces
a smoother, slower-turning support/resistance zone than a single moving
average.

A long entry opens on a fresh close above the upper band, confirmed by the
upper band itself sloping upward over `strategy_slope_lookback` bars; a short
entry opens on a fresh close below the lower band with the lower band sloping
downward. Both directions share a single one-position-per-magic cap.
Positions carry a fixed ATR hard stop and exit on a plain recross back inside
the band (not a fresh breakout trigger), a bar-count time stop, or framework
Friday close. A recross exit does not itself open the opposite position — that
requires its own fresh breakout trigger. No take-profit, trailing stop, or
partial close in v1.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_slope_lookback` | 5 | 3-10 | Bars back used for the band-slope confirmation filter |
| `strategy_atr_period` | 14 | 10-20 | ATR period for the protective stop |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.5 | Protective stop distance in ATR units |
| `strategy_max_hold_bars` | 90 | 60-150 | Maximum holding period in D1 bars |
| `strategy_max_spread_points` | 40 | 25-60 | Spread cap (points) above which entries are skipped |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - liquid FX major with tight typical spreads, well suited to
  a low-turnover D1 band-breakout system.

**Explicitly NOT for:**
- Any other symbol - the card is single-symbol-only by design; batch
  siblings from the same source use distinct instruments.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 10 |
| Typical hold time | up to 90 D1 bars (time-stop bound) |
| Expected drawdown profile | Low-frequency composite-band breakouts; slope filter reduces but does not eliminate whipsaw risk |
| Regime preference | Long-horizon trend/regime following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Source type:** web (QuantifiedStrategies.com)
**Pointer:** "Fibonacci Moving Averages Trading Strategy: Backtest and
Evaluation", https://www.quantifiedstrategies.com/fibonacci-moving-averages/
**R1-R4 verdict (Q00):** all PASS; see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_21512_qs-fibonacci-ma-band-gbp.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | Initial build from approved G0 card | router task 03feaa56 |

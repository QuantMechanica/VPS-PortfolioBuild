# QM5_21510_qs-nvi-ema-sp500 - Strategy Spec

**EA ID:** QM5_21510
**Slug:** `qs-nvi-ema-sp500`
**Source:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Author of this spec:** Claude
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

This EA trades a long-horizon Negative Volume Index (NVI) trend-regime cross
on SP500 D1. NVI is a cumulative index seeded at 1000 that updates ONLY on
down-volume days (today's tick volume below yesterday's): on those days it is
scaled by the day's percentage price change; on flat/rising-volume days it is
unchanged. The EA computes NVI and its own long-window EMA fully from history
once per new closed D1 bar (a bounded, cheap recompute — `nvi_ema_period +
warmup_buffer` iterations, gated so it never repeats within a bar).

A long entry opens when NVI crosses from at/below its EMA to above it; a short
entry opens when NVI crosses from at/above its EMA to below it. Both directions
share a single one-position-per-magic cap. Positions carry a fixed ATR hard
stop and exit on the opposite NVI/EMA cross (signal reversal, may flip
same-bar), a bar-count time stop, or framework Friday close. No take-profit,
trailing stop, or partial close in v1.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_nvi_ema_period` | 255 | 180-320 | EMA period applied to the NVI series itself |
| `strategy_warmup_buffer` | 20 | 10-40 | Extra bars beyond the EMA period before trading is allowed |
| `strategy_atr_period` | 14 | 10-20 | ATR period for the protective stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Protective stop distance in ATR units |
| `strategy_max_hold_bars` | 120 | 90-180 | Maximum holding period in D1 bars |
| `strategy_max_spread_points` | 500 | 300-800 | Spread cap (points) above which entries are skipped |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - the source's own original instrument (S&P 500); no
  cross-asset porting gap.

**Explicitly NOT for:**
- Any other symbol - the card is single-symbol-only by design (NVI is
  historically an S&P 500 / broad-market index construct).

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
| Trades / year / symbol | 8 |
| Typical hold time | up to 120 D1 bars (time-stop bound) |
| Expected drawdown profile | Infrequent long-window regime crosses; losses cluster around whipsaws near the 255-bar EMA |
| Regime preference | Long-horizon trend/regime following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Source type:** web (QuantifiedStrategies.com)
**Pointer:** "Negative Volume Index (NVI) - Strategy, Rules, Returns",
https://www.quantifiedstrategies.com/negative-volume-index/ (Paul Dysart,
creator; Norman Fosback, popularizer, "Stock Market Logic").
**R1-R4 verdict (Q00):** all PASS; see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_21510_qs-nvi-ema-sp500.md`

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
| v1 | 2026-08-17 | Initial build from approved G0 card | router task 068c2ce0 |

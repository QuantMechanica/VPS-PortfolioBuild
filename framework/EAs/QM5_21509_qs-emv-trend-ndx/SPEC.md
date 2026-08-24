# QM5_21509_qs-emv-trend-ndx — Strategy Spec

**EA ID:** QM5_21509
**Slug:** `qs-emv-trend-ndx`
**Source:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Author of this spec:** Codex
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

This EA trades `NDX.DWX` on completed D1 bars. It computes raw Ease of Movement as the change in the High/Low midpoint divided by a tick-volume-to-range box ratio, then smooths the most recent valid raw observations with an SMA. A long opens when smoothed EMV crosses above zero and the last close is above its trend SMA; a short opens on the inverse cross and trend agreement.

A zero-range or zero-volume bar does not advance the EMV calculation. The prior smoothed state is carried instead. Each entry receives a fixed hard stop at `strategy_atr_sl_mult` times D1 ATR. A position exits when its completed-bar close crosses through the trend SMA, after the configured maximum number of completed D1 bars, or through the framework Friday-close guard. There is no take-profit, trailing stop, partial close, pyramiding, or same-direction re-entry without a fresh EMV zero-cross.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_emv_smooth_period` | 14 | 10, 14, 20 | Number of valid raw EMV observations in the smoothing SMA |
| `strategy_volume_divisor` | 10000.0 | 1000, 10000, 100000 | Scale divisor applied to native MT5 tick volume in the EMV box ratio |
| `strategy_trend_period` | 50 | 30, 50, 80 | D1 close SMA period used for trend agreement and trend-failure exits |
| `strategy_atr_period` | 14 | 10, 14, 20 | D1 ATR period used to size the hard stop |
| `strategy_atr_sl_mult` | 2.5 | 2.0, 2.5, 3.0 | ATR multiple from entry for the server-side hard stop |
| `strategy_max_hold_bars` | 50 | 30, 50, 70 | Maximum holding period in completed D1 bars |
| `strategy_max_spread_points` | 500 | 300, 500, 800 | Maximum positive entry spread in symbol points |

---

## 3. Symbol Universe

**Designed for:**

- `NDX.DWX` — the approved card is a single-symbol Nasdaq-100 D1 strategy and uses the symbol's native tick volume as the required volume proxy.

**Explicitly NOT for:**

- All other symbols — the approved card declares `single_symbol_only: true`; no portability expansion is authorized.

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
| Trades / year / symbol | approximately 10 |
| Typical hold time | 1–50 completed D1 bars; hard maximum 50 by default |
| Expected drawdown profile | medium risk; card estimate approximately 20% |
| Regime preference | established uptrends and downtrends with confirming volume/price movement |
| Win rate target (qualitative) | not specified by the approved card |

The approved card estimates approximately 8–12 joint signals per year from a 14-bar EMV zero-cross combined with SMA50 trend agreement.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `0b564ef2-810c-5b1d-9084-342ddb20575c`
**Source type:** public trading article
**Pointer:** QuantifiedStrategies.com, “Ease Of Movement Indicator (EMV) as a Trading Strategy (Backtest),” https://www.quantifiedstrategies.com/ease-of-movement/
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `D:/QM/strategy_farm/artifacts/cards_approved/QM5_21509_qs-emv-trend-ndx.md`

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
| v1 | 2026-08-24 | Initial build from card | `build-QM5_21509_qs-emv-trend-ndx` |

# QM5_11900_kobasfx-4ema-macd-sentiment-h1 — Strategy Spec

**EA ID:** QM5_11900
**Slug:** `kobasfx-4ema-macd-sentiment-h1`
**Source:** `b8f3c4d7-9e26-5a51-8d74-c3e6f9a5b1d4`
**Author of this spec:** Codex
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

On each closed H1 bar, the EA enters long when EMA(5), EMA(10), and EMA(15)
form a separated bullish stack, price and the slope of EMA(65) confirm the
uptrend, and the MACD signal is positive and inside the five-bar MACD cloud.
The short rule mirrors those conditions. The initial stop is two pips beyond
the ten-bar structural extreme and the take-profit is three times initial
risk. A position also exits when the MACD signal crosses zero, leaves the
cloud against the position, or reaches the 240-bar timeout.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast1` | 5 | card-fixed | Fastest EMA in the directional stack. |
| `strategy_ema_fast2` | 10 | card-fixed | Middle EMA in the directional stack. |
| `strategy_ema_fast3` | 15 | card-fixed | Slowest fast EMA in the directional stack. |
| `strategy_ema_slow` | 65 | card-fixed | Slow trend-level and price-side filter. |
| `strategy_slope_bars` | 5 | card-fixed | Bars used to measure the EMA(65) slope. |
| `strategy_macd_fast` | 12 | card-fixed | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | card-fixed | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | card-fixed | MACD signal-line period. |
| `strategy_atr_period` | 14 | card-fixed | ATR period used to normalize EMA separation. |
| `strategy_ema_sep_atr_mult` | 0.25 | card-fixed | Minimum EMA(5)-to-EMA(15) separation in ATR units. |
| `strategy_tp_risk_mult` | 3.0 | card-fixed | Take-profit multiple of initial price risk. |
| `strategy_time_stop_bars` | 240 | card-fixed | Maximum H1 holding period. |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`, and `NZDUSD.DWX` — liquid dollar FX carriers covered by the approved card.
- `USDJPY.DWX`, `USDCAD.DWX`, and `USDCHF.DWX` — liquid dollar crosses covered by the approved card.
- `EURJPY.DWX`, `GBPJPY.DWX`, and `AUDJPY.DWX` — liquid yen crosses covered by the approved card.

**Explicitly NOT for:**

- Indices, metals, and energy symbols — the approved card and source scope are FX only; portability outside FX is not authorized.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 35 per approved card; Q02 owns the measured frequency verdict |
| Typical hold time | hours to several days, capped at 240 H1 bars |
| Expected drawdown profile | fixed-risk trend entries with structural stops; empirical drawdown is unknown before Q02 |
| Regime preference | directional FX trends with separated short-term EMAs and aligned MACD momentum |
| Win rate target (qualitative) | unknown; the 3R cap permits a lower hit rate |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8f3c4d7-9e26-5a51-8d74-c3e6f9a5b1d4`
**Source type:** self-published retail-FX guide
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11900_kobasfx-4ema-macd-sentiment-h1.md`
**R1–R4 verdict (Q00):** PASS under the OWNER-approved card record at the pointer above.

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
| v1 | 2026-08-24 | Q02 infrastructure recovery and missing Q01 spec completion | Farm task `46e34047-c661-462c-96d5-b4f9d76914db`; strategy mechanics unchanged. |

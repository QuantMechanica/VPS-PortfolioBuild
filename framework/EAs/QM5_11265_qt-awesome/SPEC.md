# QM5_11265_qt-awesome - Strategy Spec

**EA ID:** QM5_11265
**Slug:** qt-awesome
**Source:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades the Awesome Oscillator as the difference between a 5-period SMA and a 34-period SMA of median price `(High + Low) / 2`. It opens long when the fast median SMA is above the slow median SMA and the oscillator magnitude is at least `0.05 * ATR(14,H4)`, or when the card's saucer long pattern appears. It opens short on the symmetric bearish condition, exits on an opposite oscillator or saucer signal, and applies a time stop after 20 H4 bars when oscillator magnitude remains below `0.25 * ATR(14,H4)`.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ao_fast_period` | 5 | 1 to `strategy_ao_slow_period - 1` | Fast SMA period for the median-price Awesome Oscillator. |
| `strategy_ao_slow_period` | 34 | `strategy_ao_fast_period + 1` and higher | Slow SMA period for the median-price Awesome Oscillator. |
| `strategy_enable_saucer` | true | true / false | Enables the card's saucer entry and opposite-saucer exit patterns. |
| `strategy_atr_period` | 14 | 1 and higher | ATR lookback used for hard stop and oscillator magnitude filters. |
| `strategy_atr_timeframe` | PERIOD_H4 | M1 to MN1 | Timeframe used for the card's fixed `ATR(14,H4)` stop convention. |
| `strategy_atr_sl_mult` | 2.5 | greater than 0 | Hard stop distance in ATR multiples. |
| `strategy_min_cross_atr_mult` | 0.05 | 0 and higher | Minimum oscillator magnitude for MA-sign entries. |
| `strategy_time_stop_atr_mult` | 0.25 | 0 and higher | Oscillator magnitude threshold for the optional time stop. |
| `strategy_time_stop_h4_bars` | 20 | 0 and higher | Number of H4 bars before the optional low-momentum time stop can close a trade. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX major with OHLC median-price data.
- `GBPUSD.DWX` - card-listed liquid FX major with OHLC median-price data.
- `XAUUSD.DWX` - card-listed metal market with OHLC median-price data.
- `NDX.DWX` - card-listed large-cap index proxy with DWX OHLC data.
- `GDAXI.DWX` - registered DAX DWX symbol used as the matrix-available substitute for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated name is not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the available DAX equivalent.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol data guarantee.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | `ATR(14,H4)` for stop and momentum filters; oscillator uses the chart timeframe. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Expected trade frequency | Awesome Oscillator 5/34 median-price momentum with saucer/MA flips; conservative estimate 25-60 trades/year/symbol on H4. |
| Typical hold time | Not stated as a frontmatter value; exits by opposite signal or optional time stop after 20 H4 bars. |
| Expected drawdown profile | Medium risk; momentum oscillator systems can whipsaw. |
| Regime preference | Median-price momentum and continuation, with saucer reversal timing enabled. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 72f9fcfa-6c75-5544-80c4-31e15c9817ab
**Source type:** GitHub repository script
**Pointer:** https://github.com/je-suis-tm/quant-trading/blob/master/Awesome%20Oscillator%20backtest.py
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11265_qt-awesome.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-08 | Initial build from card | 89f27a94-7083-4426-b1c9-d89b8d2b2f94 |

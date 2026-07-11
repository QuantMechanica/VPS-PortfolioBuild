# QM5_10571_mql5-pchan-stop — Strategy Spec

**EA ID:** QM5_10571
**Slug:** `mql5-pchan-stop`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Author of this spec:** Codex
**Last revised:** 2026-07-11

---

## 1. Strategy Logic

On each closed H4 bar, the EA compares the close with the highest high and
lowest low of the preceding 22 bars. It buys after an upside channel break and
sells after a downside channel break. It exits on the opposite channel signal,
after 40 H4 bars, at a 2 ATR hard stop, at a 1.5R target, or through the V5
kill-switch and Friday-close controls.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_signal_tf` | H4 | H1–H6 test range | Signal timeframe |
| `strategy_model` | 8 | fixed at 8 | Selects the price-channel breakout rule |
| `strategy_fast_period` | 14 | 2–100 | Shared rebuild-family fast lookback; inactive in model 8 |
| `strategy_mid_period` | 21 | 2–200 | Shared rebuild-family middle lookback; inactive in model 8 |
| `strategy_slow_period` | 50 | 5–300 | Shared rebuild-family slow lookback; inactive in model 8 |
| `strategy_adx_period` | 14 | 2–100 | Shared rebuild-family ADX lookback; inactive in model 8 |
| `strategy_rsi_period` | 14 | 2–100 | Shared rebuild-family RSI lookback; inactive in model 8 |
| `strategy_atr_period` | 14 | 2–100 | ATR lookback for stop sizing |
| `strategy_channel_bars` | 22 | 5–100 | Prior closed bars used for channel bounds |
| `strategy_momentum_period` | 14 | 2–100 | Shared rebuild-family momentum lookback; inactive in model 8 |
| `strategy_time_stop_bars` | 40 | 0–200 | Maximum holding time in signal bars; 0 disables |
| `strategy_volume_lookback` | 20 | 2–100 | Shared rebuild-family volume lookback; inactive in model 8 |
| `strategy_atr_sl_mult` | 2.0 | 0.5–5.0 | Hard-stop distance in ATR units |
| `strategy_tp_r_mult` | 1.5 | 0–5.0 | Target as a multiple of initial risk; 0 disables |
| `strategy_delta` | 0.0 | 0–10 | Shared rebuild-family threshold; inactive in model 8 |
| `strategy_min_distance_points` | 5.0 | 0–500 | Shared rebuild-family distance filter; inactive in model 8 |
| `strategy_max_spread_points` | 250.0 | 0–1000 | Rejects entries above this spread; 0 disables |
| `strategy_min_atr_points` | 0.0 | 0–1000 | Optional minimum ATR filter; 0 disables |
| `strategy_breakout_buffer_points` | 10.0 | 0–500 | Shared rebuild-family breakout buffer; inactive in model 8 |
| `strategy_volume_mult` | 1.0 | 0.5–5.0 | Shared rebuild-family volume multiplier; inactive in model 8 |

Framework risk, news, Friday-close, and portfolio inputs follow
`framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major-FX channel trends.
- `GBPUSD.DWX` — liquid major-FX channel trends.
- `EURJPY.DWX` — cross-currency trend diversification.
- `XAUUSD.DWX` — liquid metal trend diversification.

**Explicitly NOT for:**

- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` — no verified
  Darwinex real-tick history is available for the pipeline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` on the host H4 chart |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20–55; card baseline 35 |
| Typical hold time | One to 40 H4 bars |
| Expected drawdown profile | Clustered losses in sideways, false-breakout regimes |
| Regime preference | Persistent directional trends and volatility expansion |
| Win rate target (qualitative) | Medium-low, offset by asymmetric winners |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase article and source code
**Pointer:** Nikolay Kositsin, “Exp_PriceChannel_Stop,” 2016,
https://www.mql5.com/en/code/15222
**R1–R4 verdict (Q00):** all PASS; see
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_10571_mql5-pchan-stop.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-03 | Initial build from approved card | Historical rebuild |
| v2 | 2026-07-11 | Q02 ONINIT infrastructure repair | Align magic slots with the EA and canonical setfiles |

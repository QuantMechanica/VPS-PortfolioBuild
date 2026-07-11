# QM5_11906_watthana-candlestick-rsi-stoch-ea-h1 — Strategy Spec

**EA ID:** QM5_11906
**Slug:** `watthana-candlestick-rsi-stoch-ea-h1`
**Source:** `7f1c4b9a-3d68-5e52-a836-c4d9e2b7f1a8`
**Author of this spec:** Codex
**Last revised:** 2026-07-11

---

## 1. Strategy Logic

On each completed H1 bar, the EA looks for a long-shadow reversal candle in
the direction opposite the preceding five-bar move. A bullish hammer or
inverted hammer must coincide with RSI(14) below 30 and Stochastic %K below
20; the bearish mirror requires a hanging man or shooting star with RSI above
70 and Stochastic %K above 80. Entries use a 2 ATR(14) hard stop. Positions
close on the opposite candle/oscillator state, after 120 H1 bars, or through
the framework Friday-close and kill-switch paths.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_rsi_period` | 14 | fixed by card | RSI lookback on completed H1 bars |
| `strategy_rsi_oversold` | 30 | fixed by card | Maximum RSI for a bullish reversal entry |
| `strategy_rsi_overbought` | 70 | fixed by card | Minimum RSI for a bearish reversal entry |
| `strategy_stoch_k_period` | 14 | fixed by card | Stochastic %K lookback |
| `strategy_stoch_d_period` | 3 | fixed by card | Stochastic %D smoothing period |
| `strategy_stoch_slowing` | 3 | fixed by card | Stochastic slowing period |
| `strategy_stoch_oversold` | 20 | fixed by card | Maximum %K for a bullish reversal entry |
| `strategy_stoch_overbought` | 80 | fixed by card | Minimum %K for a bearish reversal entry |
| `strategy_body_shadow_ratio` | 2.0 | fixed by card | Minimum long-shadow length relative to candle body |
| `strategy_trend_lookback` | 5 | fixed by card | Prior H1 close lookback for trend context |
| `strategy_trend_min_pips` | 10 | fixed by card | Minimum lookback move needed to classify a trend |
| `strategy_atr_period` | 14 | fixed by card | ATR period for the hard stop |
| `strategy_atr_sl_mult` | 2.0 | fixed by card | Hard-stop distance in ATR units |
| `strategy_time_stop_bars` | 120 | fixed by card | Maximum position age in H1 bars |

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCAD.DWX`, and `USDCHF.DWX` — liquid major FX pairs, including the paper's EUR/USD carrier.
- `AUDUSD.DWX`, `NZDUSD.DWX`, `EURJPY.DWX`, `GBPJPY.DWX`, and `AUDJPY.DWX` — additional liquid FX pairs used to test whether the reversal mechanism diversifies beyond EUR/USD.

**Explicitly NOT for:**

- Non-FX instruments — the approved card and the peer-reviewed source specify an H1 currency-market mechanism.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | one latched `QM_IsNewBar()` event refreshes all candle and oscillator state |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 50 card-estimated signals before downstream filtering |
| Typical hold time | several hours to several days, capped at 120 H1 bars |
| Expected drawdown profile | fixed-risk reversal losses during persistent directional moves, bounded by the 2 ATR hard stop |
| Regime preference | exhaustion and mean reversion after a short directional move |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `7f1c4b9a-3d68-5e52-a836-c4d9e2b7f1a8`
**Source type:** peer-reviewed journal article
**Pointer:** Watthana Pongsena et al., “Developing a Forex Expert Advisor Based on Japanese Candlestick Patterns and Technical Trading Strategies,” *International Journal of Trade, Economics and Finance* 9(6), 2018, DOI `10.18178/ijtef.2018.9.6.622`
**R1–R4 verdict (Q00):** all PASS; see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11906_watthana-candlestick-rsi-stoch-ea-h1.md`

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
| v1 | 2026-07-11 | Q02 infrastructure recovery | Added missing magic registrations, canonical per-symbol slots, complete RISK_FIXED setfiles, and closed-bar state caching |

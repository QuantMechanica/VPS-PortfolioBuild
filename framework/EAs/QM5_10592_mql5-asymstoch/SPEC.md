# QM5_10592_mql5-asymstoch - Strategy Spec

**EA ID:** QM5_10592
**Slug:** mql5-asymstoch
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Author of this spec:** Codex
**Last revised:** 2026-05-30

---

## 1. Strategy Logic

The EA evaluates completed H4 bars. It computes the source-default AsimmetricStochNR-style stochastic line with short and long K windows, then opens long when the stochastic line crosses above its signal line and opens short when it crosses below. Existing longs close on a bearish cross, existing shorts close on a bullish cross, and either side also closes after 12 completed H4 bars if no opposite cross appears. Entries use a 2.5 x ATR(14) catastrophic stop and no fixed take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for stochastic cross signals, ATR stop, and time stop. |
| `strategy_kperiod_short` | `5` | 1+ | Short K lookback used by the asymmetric stochastic state. |
| `strategy_kperiod_long` | `12` | 1+ | Long K lookback used by the asymmetric stochastic state. |
| `strategy_dperiod` | `7` | 1+ | Signal-line SMA period. |
| `strategy_slowing` | `3` | 1+ | Stochastic-line smoothing period. |
| `strategy_sensitivity_points` | `7` | 0+ | Minimum high-low range in points before the oscillator moves away from neutral. |
| `strategy_overbought` | `80` | 1-100 | Overbought threshold for asymmetric high/low window selection. |
| `strategy_oversold` | `20` | 0-99 | Oversold threshold for asymmetric high/low window selection. |
| `strategy_atr_period` | `14` | 1+ | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | `2.5` | >0 | ATR multiple used for the catastrophic stop. |
| `strategy_max_hold_bars` | `12` | 0+ | Maximum H4 bars to hold a trade before time-stop exit; 0 disables. |
| `strategy_max_spread_points` | `0` | 0+ | Optional spread gate in points; 0 disables. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` - source test was AUDUSD H4, and this is the primary card symbol.
- `EURUSD.DWX` - liquid DWX FX major suitable for H4 oscillator-cross testing.
- `USDJPY.DWX` - liquid DWX FX major suitable for H4 oscillator-cross testing.
- `GBPJPY.DWX` - active DWX FX cross suitable for H4 oscillator-cross testing.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline artifacts must use canonical `.DWX` symbols.
- Non-FX symbols - the card R3 target list is FX-only for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | Up to 12 H4 bars, with earlier opposite-cross exits. |
| Expected drawdown profile | Oscillator-cross mean reversion with losses bounded by ATR stop. |
| Regime preference | Mean-reversion / oscillator-cross regimes. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase expert
**Pointer:** https://www.mql5.com/en/code/1279 and `D:\QM\strategy_farm\artifacts\cards_approved\QM5_10592_mql5-asymstoch.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10592_mql5-asymstoch.md`

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
| v1 | 2026-05-30 | Initial build from card | 4bcc022a-ce60-4341-9306-71eefa231f89 |

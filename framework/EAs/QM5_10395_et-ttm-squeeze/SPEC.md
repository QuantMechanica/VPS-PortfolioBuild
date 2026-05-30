# QM5_10395_et-ttm-squeeze - Strategy Spec

**EA ID:** QM5_10395
**Slug:** `et-ttm-squeeze`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see approved Strategy Card)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

This EA trades the H1 TTM squeeze breakout described in the approved Elite Trader card. A long entry requires Bollinger Bands to move from inside the Keltner Channel to a bullish release and EMA(12) > EMA(20) > EMA(30) > EMA(50). A short entry requires the opposite bearish squeeze release and EMA(12) < EMA(20) < EMA(30) < EMA(50). JPY FX pairs use the card's 100-pip stop and 120-pip target; non-JPY ports use ATR(20) multiples.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast` | 12 | 1-200 | Fast EMA in the trend stack. |
| `strategy_ema_mid1` | 20 | 1-200 | First middle EMA; also used for EMA20/EMA50 exits. |
| `strategy_ema_mid2` | 30 | 1-200 | Second middle EMA in the trend stack. |
| `strategy_ema_slow` | 50 | 1-300 | Slow EMA in the trend stack and cross exit. |
| `strategy_squeeze_period` | 20 | 5-100 | Bollinger and Keltner lookback period. |
| `strategy_bb_deviation` | 2.0 | 0.5-4.0 | Bollinger Band standard deviation multiplier. |
| `strategy_kc_atr_mult` | 1.5 | 0.5-4.0 | ATR multiplier for Keltner Channel width. |
| `strategy_atr_period` | 20 | 5-100 | ATR period for Keltner width and non-JPY exits. |
| `strategy_jpy_stop_pips` | 100 | 10-500 | Fixed stop for JPY FX pairs from the source. |
| `strategy_jpy_target_pips` | 120 | 10-600 | Fixed target for JPY FX pairs from the source. |
| `strategy_atr_sl_mult` | 1.0 | 0.2-5.0 | Non-JPY stop distance as ATR multiple. |
| `strategy_atr_tp_mult` | 1.2 | 0.2-8.0 | Non-JPY target distance as ATR multiple. |
| `strategy_skip_friday_last_h1` | true | true/false | Skip new entries in the last H1 bar before weekly close. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPJPY.DWX` - source instrument and JPY FX baseline for fixed-pip stop and target.
- `EURJPY.DWX` - liquid JPY FX port using the same fixed-pip convention.
- `EURUSD.DWX` - liquid FX major port using ATR-based stop and target.
- `XAUUSD.DWX` - liquid metal port using ATR-based stop and target.
- `GDAXI.DWX` - canonical DWX DAX symbol; used as the available matrix-valid port for the card's `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX` - not a canonical DWX custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | hours to a few days |
| Expected drawdown profile | Moderate drawdown from false squeeze releases and whipsaw trend-stack changes. |
| Regime preference | volatility-expansion breakout with aligned trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/ttm-trend-the-markets-mechanical-system.184126/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10395_et-ttm-squeeze.md`

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
| v1 | 2026-05-25 | Initial build from card | 72c8d839-1e3e-4d96-b75f-344f08ce48ae |

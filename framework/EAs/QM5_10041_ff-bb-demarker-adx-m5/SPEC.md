# QM5_10041_ff-bb-demarker-adx-m5 - Strategy Spec

**EA ID:** QM5_10041
**Slug:** `ff-bb-demarker-adx-m5`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades M5 closed-bar Bollinger band proximity breakouts on DWX FX pairs. A long signal fires when the previous M5 close is within 5 pips of the upper Bollinger band built from low prices, DeMarker(14) is outside the 0.30-0.70 neutral zone, and ADX(14) is at least 40. A short signal mirrors the same rules near the lower Bollinger band built from high prices. Positions use a fixed 20-pip take profit, a 10 x ATR(100,H4) stop subject to the card's maximum stop caps, an early profitable EMA(14 typical price) close, and a 5 trading-day time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bb_period` | 14 | 5-100 | Bollinger period for the M5 band proximity check. |
| `strategy_bb_deviation` | 2.0 | 0.5-5.0 | Bollinger standard-deviation multiplier. |
| `strategy_demarker_period` | 14 | 2-100 | DeMarker period used as the oscillator filter. |
| `strategy_demarker_high` | 0.70 | 0.50-1.00 | Upper DeMarker threshold. |
| `strategy_demarker_low` | 0.30 | 0.00-0.50 | Lower DeMarker threshold. |
| `strategy_adx_period` | 14 | 2-100 | ADX period on M5. |
| `strategy_adx_min` | 40.0 | 0.0-100.0 | Minimum ADX trend strength for entry. |
| `strategy_ema_period` | 14 | 2-100 | EMA period for profitable early exits. |
| `strategy_h4_atr_period` | 100 | 10-300 | H4 ATR period used for the card stop. |
| `strategy_sl_atr_mult` | 10.0 | 1.0-20.0 | Multiplier applied to ATR(100,H4) for stop distance. |
| `strategy_tp_pips` | 20 | 1-200 | Fixed take-profit distance in pips. |
| `strategy_band_window_pips` | 5 | 1-50 | Maximum distance from the signal close to the relevant band. |
| `strategy_max_sl_pips` | 600 | 50-2000 | Hard cap for the ATR stop on FX majors. |
| `strategy_d1_atr_period` | 14 | 2-100 | D1 ATR period for the stop-distance cap. |
| `strategy_d1_atr_cap_mult` | 6.0 | 1.0-20.0 | Maximum stop distance as a multiple of ATR(14,D1). |
| `strategy_time_stop_days` | 5 | 1-30 | Maximum holding time before strategy close. |
| `strategy_max_spread_points` | 35 | 0-500 | Spread filter in broker points; 0 disables it. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary liquid EUR/USD FX pair from the approved card.
- `GBPUSD.DWX` - liquid GBP/USD FX pair in the card's P2 basket.
- `USDJPY.DWX` - liquid USD/JPY FX pair in the card's P2 basket.
- `EURJPY.DWX` - liquid EUR/JPY FX cross in the card's P2 basket.

**Explicitly NOT for:**
- Non-DWX symbols - the framework and registry require canonical `.DWX` names for research and backtest.
- Indices and commodities - the card is specified for DWX FX OHLC-derived indicators.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `H4` ATR(100) stop and `D1` ATR(14) stop cap |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `160` |
| Typical hold time | Intraday to several days; maximum 5 trading days |
| Expected drawdown profile | Wide ATR stop with fixed 20-pip take profit creates small frequent wins and occasional larger losses. |
| Regime preference | Breakout / trend-strength expansion |
| Win rate target (qualitative) | Medium-high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** `https://www.forexfactory.com/thread/19073-5min-bollinger-breakout-system`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10041_ff-bb-demarker-adx-m5.md`

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
| v1 | 2026-06-09 | Initial build from card | 9ca49224-9691-4cad-bdcc-a6fec4fc6973 |

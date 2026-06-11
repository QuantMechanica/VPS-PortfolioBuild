# QM5_11480_capra-pristine-pbs-pss-pullback-d1 - Strategy Spec

**EA ID:** QM5_11480
**Slug:** capra-pristine-pbs-pss-pullback-d1
**Source:** 60dd4b99-251b-5bb7-95d3-aca347a243ca (see `sources/capra-greg-pristine-trading-method`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades Greg Capra and Oliver Velez's Pristine Buy Setup and Pristine Sell Setup on D1 FX bars. Long entries require price above a rising EMA20 and either three consecutive lower highs or three consecutive bearish bars; a one-day buy stop is placed one pip above the last pullback bar. Short entries mirror the rule below a falling EMA20 with three higher lows or three bullish bars and a one-day sell stop below the rally bar. Stops use the pullback/rally extreme with an 80-pip cap; exits are prior 10-bar pivot target, D1 bar trailing after two days, framework SL/TP, Friday close, or a five-day time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 20 | >=2 | EMA period for Stage 2/Stage 4 trend filter. |
| `strategy_ema_slope_bars` | 5 | >=1 | Closed-bar distance for EMA slope comparison. |
| `strategy_pullback_bars` | 3 | >=3 | Required pullback/rally bar count; card baseline is 3. |
| `strategy_entry_offset_pips` | 1.0 | >0 | Stop-entry offset beyond the pullback/rally bar. |
| `strategy_max_sl_pips` | 80.0 | >0 | P2 stop-distance cap; skip wider signals. |
| `strategy_pivot_lookback` | 10 | >=2 | Prior pivot proxy window for TP. |
| `strategy_atr_tp_mult` | 2.0 | >0 | ATR fallback TP multiple if pivot proxy is not beyond entry. |
| `strategy_atr_period` | 14 | >=1 | ATR period for fallback TP. |
| `strategy_trail_after_bars` | 2 | >=0 | D1 bars after entry before bar-extreme trailing starts. |
| `strategy_time_stop_bars` | 5 | >=1 | Maximum D1 holding period before strategy exit. |
| `strategy_spread_cap_pips` | 25.0 | >0 | Maximum allowed spread in pips. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-stated DWX FX major with D1 native data.
- `GBPUSD.DWX` - card-stated DWX FX major with D1 native data.
- `USDJPY.DWX` - card-stated DWX FX major with D1 native data.
- `AUDUSD.DWX` - card-stated DWX FX major with D1 native data.
- `USDCAD.DWX` - card-stated DWX FX major with D1 native data.

**Explicitly NOT for:**
- Non-FX index, metal, energy, and synthetic symbols - the card's R3 PASS and instrument list are FX D1 only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Up to 5 D1 bars per card time stop |
| Expected drawdown profile | Trend-pullback losses bounded by 80-pip SL cap plus framework risk sizing |
| Regime preference | D1 trend pullback in EMA20 Stage 2/Stage 4 regimes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 60dd4b99-251b-5bb7-95d3-aca347a243ca
**Source type:** book
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11480_capra-pristine-pbs-pss-pullback-d1.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11480_capra-pristine-pbs-pss-pullback-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | a3936943-659e-4e9a-be4c-2fcb43cd0a55 |

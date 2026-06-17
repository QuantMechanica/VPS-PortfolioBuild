# QM5_10974_ftmo-obv-brk — Strategy Spec

**EA ID:** QM5_10974
**Slug:** `ftmo-obv-brk`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (FTMO blog: On Balance Volume)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

The EA trades H1 range breakouts that are confirmed by On Balance Volume (OBV).
OBV is computed from closed-bar tick volume as a running cumulative total: the
bar's tick volume is added when its close is above the prior close and
subtracted when below. On each closed bar the EA builds a 40-bar price range and
a parallel 40-bar OBV range from the bars preceding the current one. A long is
taken when the last close breaks above the 40-bar range high by at least
0.20 x ATR(14), OBV has broken above its own 40-bar range high on the breakout
bar or one bar earlier, and the close is above EMA(100). Shorts mirror this below
the range low with OBV below its range low and close below EMA(100). Quality
filters skip ranges that are too tight (< 1.2 x ATR) or too wide (> 5.0 x ATR)
and breakout candles wider than 2.2 x ATR. The stop is the farther of the range
midpoint and the breakout-candle extreme +/- 0.25 x ATR; the take-profit is 2.0R.
Once price travels 1.5R in favour the stop is trailed to EMA(20). The position is
also closed if OBV falls back inside its pre-breakout range for 2 consecutive
closed bars, or after 30 H1 bars (time exit).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_range_lookback` | 40 | 10-100 | Bars in the price & OBV breakout range |
| `strategy_trend_period` | 100 | 20-300 | EMA trend filter period |
| `strategy_trail_period` | 20 | 5-100 | EMA used to trail the stop after 1.5R |
| `strategy_atr_period` | 14 | 5-50 | ATR period (filter / breakout / stop) |
| `strategy_brk_atr_mult` | 0.20 | 0.0-1.0 | Min breakout beyond the range edge, in ATR |
| `strategy_sl_atr_buf` | 0.25 | 0.0-1.0 | ATR buffer beyond the breakout-candle extreme |
| `strategy_tp_rr` | 2.0 | 0.5-5.0 | Take-profit as an R multiple |
| `strategy_trail_trigger_r` | 1.5 | 0.5-3.0 | R travelled before the EMA trail arms |
| `strategy_range_min_atr` | 1.2 | 0.0-3.0 | Skip if range height < this x ATR |
| `strategy_range_max_atr` | 5.0 | 2.0-10.0 | Skip if range height > this x ATR |
| `strategy_candle_max_atr` | 2.2 | 1.0-5.0 | Skip if breakout candle range > this x ATR |
| `strategy_obv_confirm_window` | 2 | 1-5 | OBV break allowed on bar 1..this |
| `strategy_max_hold_bars` | 30 | 5-200 | Time exit after this many closed bars |
| `strategy_obv_exit_bars` | 2 | 1-5 | OBV-back-inside bars to force exit |
| `strategy_spread_pct_of_stop` | 15.0 | 1.0-100.0 | Skip if spread > this % of ATR stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid FX major with reliable tick volume for OBV.
- `GBPUSD.DWX` — liquid FX major; trends and breaks ranges on H1.
- `XAUUSD.DWX` — strong intraday breakout behaviour with volume surges.
- `NDX.DWX` — index with pronounced momentum breakouts; live-tradable.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only custom symbol; card basket did not list it, and
  it cannot be routed live, so it is excluded from this EA's universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `48` |
| Typical hold time | `hours to a few days (<= 30 H1 bars)` |
| Expected drawdown profile | `breakout chop produces clustered small losses between trends` |
| Regime preference | `breakout / volatility-expansion` |
| Win rate target (qualitative) | `low-medium (2R target, trend-following payoff)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `forum / blog`
**Pointer:** FTMO, "Technical analysis - On Balance Volume relies on volumes", 2023, https://ftmo.com/en/blog/technical-analysis-on-balance-volume-relies-on-volumes/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10974_ftmo-obv-brk.md`

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
| v1 | 2026-06-17 | Initial build from card | board-advisor build |

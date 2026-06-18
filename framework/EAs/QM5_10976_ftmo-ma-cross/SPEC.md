# QM5_10976_ftmo-ma-cross — Strategy Spec

**EA ID:** QM5_10976
**Slug:** `ftmo-ma-cross`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (FTMO blog, moving averages)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

A classic SMA(50)/SMA(200) trend-cross system on H4. Go long when SMA(50)
crosses above SMA(200), provided SMA(50) had spent at least 20 H4 bars below
SMA(200) before the cross, and the cross bar closes above both SMAs. Go short on
the mirror condition (SMA(50) crosses below SMA(200), prior 20-bar state above,
close below both SMAs). Two entry filters reject weak setups: skip if SMA(200)
is nearly flat (absolute 20-bar slope below 0.25×ATR(14)) and skip if the entry
candle range exceeds 2.5×ATR(14). The stop is the recent 12-bar swing extreme
with a 0.50×ATR(14) buffer; the take-profit is 3.0R. Once price reaches 1.5R, the
stop trails to SMA(50). The trade exits early on a reverse SMA cross, on two
consecutive H4 closes back through SMA(200), or after a hard 80-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_fast_period` | 50 | 20-100 | Fast SMA period |
| `strategy_sma_slow_period` | 200 | 100-300 | Slow SMA period |
| `strategy_qualify_bars` | 20 | 5-50 | Bars fast must be on the opposite side before the cross |
| `strategy_atr_period` | 14 | 7-30 | ATR period for filters and stop buffer |
| `strategy_slope_bars` | 20 | 10-50 | Bars over which to measure SMA(200) slope |
| `strategy_slope_atr_mult` | 0.25 | 0.0-1.0 | Min absolute slope as a fraction of ATR (flat-skip) |
| `strategy_range_atr_mult` | 2.5 | 1.0-5.0 | Skip if entry candle range > mult × ATR |
| `strategy_swing_bars` | 12 | 5-30 | Swing lookback for the structural stop |
| `strategy_swing_atr_buf` | 0.50 | 0.0-2.0 | ATR buffer beyond the swing extreme |
| `strategy_tp_rr` | 3.0 | 1.0-6.0 | Take-profit in R multiples |
| `strategy_trail_trigger_rr` | 1.5 | 0.5-3.0 | R touch before trailing to SMA(50) |
| `strategy_exit_close_bars` | 2 | 1-5 | Consecutive closes beyond SMA(200) to exit |
| `strategy_max_hold_bars` | 80 | 20-200 | Time exit after this many H4 bars |
| `strategy_spread_pct_of_stop` | 15.0 | 5.0-50.0 | Skip if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX with clean H4 trend structure
- `GBPUSD.DWX` — liquid major FX, strong trend persistence
- `USDJPY.DWX` — major FX, frequent multi-week trends suiting 50/200 crosses
- `XAUUSD.DWX` — gold, pronounced trending regimes that the slow cross captures

**Explicitly NOT for:**
- Index CFDs (NDX/WS30/SP500.DWX) — card targets FX/metals; index trend behaviour not validated here

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` (6-18 range) |
| Typical hold time | `days to weeks (slow H4 trend cross)` |
| Expected drawdown profile | `moderate; trend-following with frequent small losing crosses` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low` (trend-following: many small losers, few large 3R winners) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `blog` (FTMO educational article)
**Pointer:** `https://ftmo.com/en/blog/technical-analysis-why-are-moving-averages-so-popular/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10976_ftmo-ma-cross.md`

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
| v1 | 2026-06-18 | Initial build from card | c3478e4d-09dc-4e2c-bca1-511623a2b014 |

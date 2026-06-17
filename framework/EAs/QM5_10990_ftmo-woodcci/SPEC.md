# QM5_10990_ftmo-woodcci — Strategy Spec

**EA ID:** QM5_10990
**Slug:** `ftmo-woodcci`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (FTMO, "Trading the Woodies CCI System - COMPLETE Guide", 2018)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

A Woodies-CCI trend-state EA on H1, trading both long and short. It goes long
when the Trend CCI(20) has closed above zero for six consecutive H1 bars, the
LSMA(25) least-squares regression endpoint is rising over the last three bars,
and the Turbo CCI(6) either just crossed above zero on the trigger bar or has
been above zero for no more than three bars; the mirror conditions trigger a
short. A chop filter blocks entries when Trend CCI crossed zero more than three
times in the prior twenty bars, and a volatility floor skips bars where ATR(14)
is below its 20th percentile over the last 250 bars. The stop is 1.5×ATR(14) and
the take-profit is a 2.0R multiple of that stop distance. A position is closed
early when Trend CCI closes back across zero against the trade, when the LSMA
slope flips against it for two consecutive bars, or after 48 H1 bars (time exit).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_trend_cci_period` | 20 | 10-50 | Trend CCI period |
| `strategy_turbo_cci_period` | 6 | 4-14 | Turbo CCI period (entry trigger) |
| `strategy_lsma_period` | 25 | 10-60 | LSMA (least-squares MA) period for slope gate |
| `strategy_trend_bars` | 6 | 3-12 | Consecutive Trend-CCI bars one side of zero |
| `strategy_turbo_max_bars` | 3 | 1-6 | Turbo may already be on-side for ≤ this many bars |
| `strategy_chop_lookback` | 20 | 10-40 | Bars scanned for the chop filter |
| `strategy_chop_max_cross` | 3 | 1-8 | Max Trend-CCI zero crossings allowed in lookback |
| `strategy_atr_period` | 14 | 5-30 | ATR period (vol filter + stop) |
| `strategy_atr_pctile` | 20.0 | 0-50 | Skip if ATR below this percentile … |
| `strategy_atr_pctile_lookback` | 250 | 50-500 | … over this many closed bars |
| `strategy_sl_atr_mult` | 1.5 | 0.5-4.0 | Stop distance = mult × ATR |
| `strategy_tp_rr` | 2.0 | 0.5-5.0 | Take-profit = RR multiple of the stop |
| `strategy_time_exit_bars` | 48 | 12-200 | Time exit after this many H1 bars |
| `strategy_spread_lookback` | 20 | 5-50 | Bars for the median-spread reference |
| `strategy_spread_median_mult` | 1.5 | 1.0-5.0 | Skip if spread > this × median spread |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep-liquidity major; CCI/LSMA trend states are well-behaved on H1.
- `GBPUSD.DWX` — trending major with enough H1 volatility for the 1.5×ATR stop.
- `USDJPY.DWX` — trending major; complements the two EUR/GBP legs.
- `XAUUSD.DWX` — strong trender; benefits from the Woodies trend-state filter.

**Explicitly NOT for:**
- Sub-H1 timeframes — the six-bar Trend-CCI state and 48-bar time exit are H1-calibrated.

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
| Trades / year / symbol | `45` |
| Typical hold time | `hours to ~2 days (≤ 48 H1 bars)` |
| Expected drawdown profile | `moderate; trend-following with fixed 1.5×ATR stop` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** `blog (FTMO)`
**Pointer:** `https://ftmo.com/en/blog/woodies-cci-system/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10990_ftmo-woodcci.md`

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

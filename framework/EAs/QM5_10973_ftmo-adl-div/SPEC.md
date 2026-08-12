# QM5_10973_ftmo-adl-div — Strategy Spec

**EA ID:** QM5_10973
**Slug:** `ftmo-adl-div`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

H4 Accumulation/Distribution Line (ADL) swing-divergence reversal, both
directions. Long: the two most recent confirmed price swing lows (Williams
fractals, 5-30 H4 bars apart) show a lower price low while the ADL — computed
from tick volume via the standard money-flow-multiplier formula, windowed
over a fixed 70-bar anchor so the two compared points are directly comparable
— shows a higher low (bullish divergence). Confirmed only if price is below
EMA(100) or within 0.75x ATR(14) of a 60-bar low, and ATR(14) is at or above
its own 100-bar 25th percentile (skip low-volatility regime). Entry triggers
when price closes above the high of the swing-low bar. Short is the mirror
(swing highs, bearish divergence, close below the swing-high bar's low).
Stop = the more extreme of the two swing points +/- 0.25x ATR; primary target
2.0R; secondary target cap at EMA(50) if reached before 2.0R; move stop to
breakeven at 1.0R; time exit after 20 H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | fixed | ATR period |
| `strategy_ema_trend_period` | 100 | fixed | EMA(100) above/below filter |
| `strategy_ema_tp_cap_period` | 50 | fixed | EMA(50) secondary TP cap |
| `strategy_pivot_lookback_bars` | 60 | fixed | confirmed-fractal scan window |
| `strategy_swing_sep_min_bars` | 5 | fixed | card: "5-30 H4 bars" separation, lower bound |
| `strategy_swing_sep_max_bars` | 30 | fixed | card: separation upper bound |
| `strategy_adl_window_bars` | 70 | design choice | ADL windowed-cumulative anchor (headroom above the 60-bar pivot scan) |
| `strategy_extreme_lookback_bars` | 60 | fixed | card: "60-bar low/high" |
| `strategy_extreme_atr_mult` | 0.75 | fixed | card: "0.75 * ATR(14)" |
| `strategy_sl_atr_buffer_mult` | 0.25 | fixed | card: stop buffer beyond swing extreme |
| `strategy_tp_r_mult` | 2.0 | fixed | card: "2.0R" |
| `strategy_time_exit_bars` | 20 | fixed | card: "20 H4 bars" |
| `strategy_atr_percentile_sample` | 100 | fixed | card: "100-bar 25th percentile" |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`. "Skip high-impact
> news windows" is satisfied by the framework's own two-axis news gate
> (`qm_news_temporal` / `qm_news_compliance`), no strategy-level override.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card primary symbol.
- `GBPUSD.DWX` — card primary symbol.
- `XAUUSD.DWX` — card primary symbol.
- `WS30.DWX` — card primary symbol; tick-volume-based ADL is well-defined on index CFDs same as FX/metals.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~6-12 |
| Typical hold time | up to 20 H4 bars (~3.3 days) |
| Expected drawdown profile | infrequent, capped near swing-extreme + 0.25 ATR risk, breakeven-managed after 1R |
| Regime preference | volatility-expansion / reversal |
| Win rate target (qualitative) | medium (selective divergence entries) |

---

## 6. Source Citation

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** OWNER (FTMO blog article)
**Pointer:** https://ftmo.com/en/blog/technical-analysis-what-does-accumulation-distribution-tell-you/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10973_ftmo-adl-div.md`

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
| v1 | 2026-08-10 | Initial build from card | agent_router task 93481b8d |

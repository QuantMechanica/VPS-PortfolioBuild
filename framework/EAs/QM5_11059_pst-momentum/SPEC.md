# QM5_11059_pst-momentum — Strategy Spec

**EA ID:** QM5_11059
**Slug:** `pst-momentum`
**Source:** `352af9de-f372-5cf2-9a86-681a26224597` (Rob Carver / pysystemtrade rob_system raw-price momentum)
**Author of this spec:** Claude
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Daily raw-price EWMAC combined-forecast momentum from Rob Carver's pysystemtrade
`rob_system` config. On each completed D1 bar the EA computes a daily price-unit
volatility using the source mixed-vol blend (exponentially-weighted std of daily
price differences over a 35-day span, blended 65% fast / 35% with a long 20-year
slow-vol average). It then evaluates five EWMAC components on the raw daily close:
for fast spans 4, 8, 16, 32, 64 it takes `(EMA(fast) - EMA(4*fast)) / vol`,
multiplies by the fixed source scalar, and caps each to `[-20, +20]`. The combined
forecast is the equal-weight average of the five capped components. The EA goes
long when the combined forecast `>= +5` and short when it is `<= -5`. It closes a
long when the forecast decays to `<= +1` and closes a short when it rises to
`>= -1`. An emergency stop of `3.0 * ATR(20)` from entry bounds worst-case risk;
there is no fixed take-profit (signal decay is the primary exit). One position per
symbol/magic; a reversal only happens after the position is closed and a later D1
close re-crosses the opposite entry threshold.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_1` | 4 | 2-16 | momentum4 fast EMA span (slow span = 4× fast) |
| `strategy_ema_fast_2` | 8 | 4-32 | momentum8 fast EMA span |
| `strategy_ema_fast_3` | 16 | 8-64 | momentum16 fast EMA span |
| `strategy_ema_fast_4` | 32 | 16-128 | momentum32 fast EMA span |
| `strategy_ema_fast_5` | 64 | 32-256 | momentum64 fast EMA span |
| `strategy_scalar_1` | 8.539941 | fixed | momentum4 forecast scalar (source constant) |
| `strategy_scalar_2` | 5.949404 | fixed | momentum8 forecast scalar |
| `strategy_scalar_3` | 4.104172 | fixed | momentum16 forecast scalar |
| `strategy_scalar_4` | 2.786994 | fixed | momentum32 forecast scalar |
| `strategy_scalar_5` | 1.909395 | fixed | momentum64 forecast scalar |
| `strategy_fc_cap` | 20.0 | 10-40 | per-component forecast cap `[-cap,+cap]` |
| `strategy_entry_threshold` | 5.0 | 3-8 | `|combined|` at/above this enters (sweep 3/5/8) |
| `strategy_exit_buffer` | 1.0 | 0-2 | forecast-decay exit level (sweep 0/1/2) |
| `strategy_vol_days` | 35 | 20-60 | exponential span for daily-return vol |
| `strategy_vol_min_periods` | 10 | 5-20 | min daily returns required for a vol estimate |
| `strategy_vol_slow_years` | 20 | 5-25 | slow-vol averaging window (years) |
| `strategy_vol_slow_prop` | 0.35 | 0-1 | proportion of slow vol in the mixed-vol blend |
| `strategy_atr_period` | 20 | 10-30 | ATR period for the emergency stop |
| `strategy_stop_atr_mult` | 3.0 | 2.5-3.5 | stop distance = mult × ATR (sweep 2.5/3.0/3.5) |
| `strategy_spread_pct_of_stop` | 25.0 | 10-50 | skip if spread > this % of stop distance (fail-open) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid FX major with persistent multi-week trends; core EWMAC universe.
- `GBPUSD.DWX` — liquid FX major, complementary trend behaviour to EUR.
- `USDJPY.DWX` — FX major with strong rate-driven trends suited to raw-price momentum.
- `AUDUSD.DWX` — commodity-linked FX major; diversifying trend exposure.
- `XAUUSD.DWX` — gold; strong directional momentum regimes, EWMAC-friendly.
- `NDX.DWX` — Nasdaq 100 CFD (live-tradable); persistent equity-index trends.
- `WS30.DWX` — Dow 30 CFD (live-tradable); diversifying US-index trend exposure.

**Explicitly NOT for:**
- Range-bound / low-trend symbols — raw-price EWMAC whipsaws when no directional regime exists.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~24` |
| Typical hold time | `weeks (multi-day to multi-week trend legs)` |
| Expected drawdown profile | `whipsaw losses in range-bound regimes; gains carried in trends` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low-to-medium (trend-following: few large winners)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `352af9de-f372-5cf2-9a86-681a26224597`
**Source type:** `forum/repo (open-source production config)`
**Pointer:** `https://github.com/robcarver17/pysystemtrade/blob/master/systems/provided/rob_system/config.yaml` (rules `momentum4/8/16/32/64`); `rules/ewmac.py` function `ewmac`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11059_pst-momentum.md`

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
| v1 | 2026-06-17 | Initial build from card | claude board-advisor build |

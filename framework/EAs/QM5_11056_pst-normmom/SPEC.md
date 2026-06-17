# QM5_11056_pst-normmom — Strategy Spec

**EA ID:** QM5_11056
**Slug:** `pst-normmom`
**Source:** `352af9de-f372-5cf2-9a86-681a26224597` (Rob Carver / pysystemtrade rob_system)
**Author of this spec:** Claude
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

The EA trades volatility-normalised momentum (EWMAC) on the daily timeframe,
following Rob Carver's pysystemtrade `rob_system` normalised-momentum rules. Each
new D1 bar it converts price into a cumulative volatility-normalised return
series ("norm price"): daily return `r = close_t/close_{t-1} - 1`, divided by a
rolling-stddev estimate of daily-return volatility, then cumulatively summed —
giving a synthetic price with roughly equal expected volatility through time.

Six EWMAC trend components are then computed on that norm-price series with
`Lfast` in {2,4,8,16,32,64} and `Lslow = 4*Lfast`. Each raw EWMAC
`(EMA(Lfast) - EMA(Lslow)) / robust_vol(diff(norm_price),35)` is multiplied by
its fixed pysystemtrade forecast scalar (12.388306, 8.614430, 5.979139,
4.116537, 2.758873, 1.870680), capped to [-20,+20], and the six are averaged
into a combined forecast. The EA goes long when the combined forecast `>= +5`
and short when `<= -5`. It closes a long when the forecast falls back to `<= +1`
and a short when it rises to `>= -1` (signal-reversal exit). An emergency stop of
`3.0 * ATR(20)` bounds MT5 worst-case risk; the primary exit is the
signal-reversal close. One position per symbol/magic; flip only after a later
close crosses the opposite entry threshold.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_vol_lookback` | 35 | 20-60 | Rolling stddev window for daily-return volatility |
| `strategy_warmup_bars` | 320 | 200-500 | Minimum closed D1 bars before any signal |
| `strategy_diff_vol_lookback` | 35 | 20-60 | Robust-vol window of diff(norm_price) scaling each EWMAC |
| `strategy_entry_threshold` | 5.0 | 3.0-8.0 | `|combined forecast|` required to enter |
| `strategy_exit_buffer` | 1.0 | 0.0-2.0 | Close long when fc <= +this (short: >= -this) |
| `strategy_forecast_cap` | 20.0 | 10.0-30.0 | Per-component forecast cap [-cap,+cap] |
| `strategy_stop_atr_period` | 20 | 10-30 | ATR period for the emergency stop |
| `strategy_stop_atr_mult` | 3.0 | 2.5-3.5 | Emergency stop distance = mult * ATR |
| `strategy_spread_pct_of_stop` | 15.0 | 5.0-30.0 | Skip new entries if spread > this % of stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid FX major with persistent multi-week trends; normalised momentum dampens its lower vol.
- `GBPUSD.DWX` — FX major; trends well on D1, normalised returns equalise its higher vol vs EURUSD.
- `USDJPY.DWX` — FX major with strong rate-driven trends; vol normalisation handles JPY scale.
- `AUDUSD.DWX` — commodity-linked FX major; sustained risk-on/off trends suit EWMAC.
- `NDX.DWX` — Nasdaq 100 index CFD; strong directional trends, live-tradable.
- `WS30.DWX` — Dow 30 index CFD; index trend diversifier, live-tradable.
- `XAUUSD.DWX` — gold; classic trend-follower instrument, vol normalisation tames its spikes.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only Custom Symbol (broker routes no live orders); use NDX/WS30 for live index exposure.

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
| Trades / year / symbol | `~45` |
| Typical hold time | `days to weeks` |
| Expected drawdown profile | `medium — trend-following whipsaw in range regimes, bounded by ATR stop` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `low/medium (trend-follower: many small losers, few large winners)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `352af9de-f372-5cf2-9a86-681a26224597`
**Source type:** `code repository (open-source)`
**Pointer:** `https://github.com/robcarver17/pysystemtrade/blob/master/systems/provided/rob_system/config.yaml`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11056_pst-normmom.md`

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
| v1 | 2026-06-17 | Initial build from card | pst-normmom EWMAC normalised-momentum, D1 |

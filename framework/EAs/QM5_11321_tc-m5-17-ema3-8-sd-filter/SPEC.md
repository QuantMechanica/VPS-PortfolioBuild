# QM5_11321_tc-m5-17-ema3-8-sd-filter — Strategy Spec

**EA ID:** QM5_11321
**Slug:** `tc-m5-17-ema3-8-sd-filter`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", 5 Min Trading System #17)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Multi-confirmation M5 trend follower. The single trigger EVENT is a fresh EMA(3)
crossing EMA(8) on the close of an M5 bar: an up-cross opens the long path, a
down-cross opens the short path. The trigger fires only when four confirming
STATES align on that same closed bar: Parabolic SAR(0.02,0.2) is below the candle
(long) or above it (short); MACD(12,26,9) main is positive (long) or negative
(short); Stochastic(10,15,15) %K is above %D (long) or below %D (short); and
StdDev(20) sits in a medium-or-stronger volatility regime (StdDev >= the medium
floor for the pair class, in price units). The position closes defensively when
EMA(3) crosses back to the opposite side of EMA(8) (EMA3<EMA8 closes a long;
EMA3>EMA8 closes a short). The protective stop is the recent swing low (long) or
swing high (short) over a structure lookback (baseline 10 closed bars). Only one
indicator cross is treated as an EVENT; the rest are STATES, which avoids the
two-cross-same-bar zero-trade trap.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_fast_period` | 3 | 2-10 | Fast EMA (trigger leg) |
| `strategy_ema_slow_period` | 8 | 5-30 | Slow EMA (trigger leg) |
| `strategy_sar_step` | 0.02 | 0.01-0.05 | Parabolic SAR acceleration step |
| `strategy_sar_max` | 0.2 | 0.1-0.5 | Parabolic SAR maximum acceleration |
| `strategy_macd_fast` | 12 | 5-20 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 15-40 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 5-15 | MACD signal SMA period |
| `strategy_stoch_k` | 10 | 5-20 | Stochastic %K period |
| `strategy_stoch_d` | 15 | 3-20 | Stochastic %D period |
| `strategy_stoch_slowing` | 15 | 3-20 | Stochastic slowing |
| `strategy_stddev_period` | 20 | 10-30 | StdDev period |
| `strategy_stddev_med_floor` | 0.010 | symbol-dependent | Medium-regime StdDev floor (price units) — set per pair class via setfile |
| `strategy_stddev_strong_floor` | 0.020 | symbol-dependent | Strong-regime StdDev floor (price units) |
| `strategy_strong_only` | false | true/false | false = medium+strong admitted; true = strong-only (P3 variant) |
| `strategy_swing_lookback` | 10 | 5-15 | Swing-stop lookback in closed bars |
| `strategy_spread_pts_cap` | 20.0 | 5-50 | Block only if modeled spread exceeds this many points (fail-open on zero) |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are
> documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

The StdDev floors are pair-class-dependent (card §"Volatility Regime Filter"):
AUD/NZD medium 0.0005 / strong 0.0010; JPY medium 0.10 / strong 0.20; other
medium 0.010 / strong 0.020. The default inputs carry the "other" class; the
generated per-symbol setfiles override `strategy_stddev_med_floor` /
`strategy_stddev_strong_floor` for the AUD/NZD and JPY symbols.

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` — major liquid FX pair; card R3 basket; AUD-class StdDev floors.
- `NZDUSD.DWX` — major liquid FX pair; card R3 basket; NZD-class StdDev floors.
- `USDJPY.DWX` — major liquid FX pair; card R3 basket; JPY-class StdDev floors.
- `EURUSD.DWX` — major liquid FX pair; card R3 basket; other-class StdDev floors.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the StdDev price-unit thresholds and the M5 FX
  trend mechanics are calibrated to major FX pairs, not index CFDs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~100` |
| Typical hold time | `minutes to a few hours (M5 intraday trend legs)` |
| Expected drawdown profile | `choppy whipsaw drawdowns in range regimes; trends pay` |
| Regime preference | `trend (volatility-expansion gated)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)" (2014), 5 Min Trading System #17, pp. 41-42, local PDF cited in card `source_citation`.
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11321_tc-m5-17-ema3-8-sd-filter.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor lane build |

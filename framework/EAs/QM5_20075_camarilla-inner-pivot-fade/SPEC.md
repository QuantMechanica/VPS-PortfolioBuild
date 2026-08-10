# QM5_20075_camarilla-inner-pivot-fade — Strategy Spec

**EA ID:** QM5_20075
**Slug:** `camarilla-inner-pivot-fade`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (ForexFactory community Camarilla Equation cluster; recovered from QM5_1261)
**Author of this spec:** Claude (capacity-spilled build_ea)
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

Intraday mean-reversion fade of the inner Camarilla pivots. Once per broker day
(at the 00:00 broker-time D1 boundary) the EA computes the closed-form Camarilla
levels from the prior day's High/Low/Close: `H1 = C + (H-L)*1.1/12`,
`L1 = C - (H-L)*1.1/12`, `H2/L2` at `/6`, `H3/L3` at `/4`, and the floor pivot
`P = (H+L+C)/3`. Inside the 06:00-18:00 broker-time window (Mon-Fri) it fades the
tight inner band: it goes LONG the instant Bid touches L1 provided the prior
closed M15 bar's Low is still above L2 (the inner-fade thesis is intact), and
SHORT the instant Ask touches H1 provided the prior closed M15 bar's High is
still below H2. Take-profit is the mid pivot P (mean-reversion target); the hard
stop sits a fraction of the mid-to-outer gap beyond the mid band
(`L2 - frac*(L2-L3)` for longs, `H2 + frac*(H3-H2)` for shorts). Positions also
exit on an opposite-pivot break (an hourly bar closing above H2 for a long, or
below L2 for a short) and are force-flattened at 21:00 broker-time so no risk is
carried overnight.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_trade_start_hour` | 6 | 0-23 | First broker hour new entries are allowed. |
| `strategy_trade_end_hour` | 18 | 0-23 | Broker hour at/after which no new entries fire. |
| `strategy_eod_flatten_hour` | 21 | 0-23 | Broker hour at/after which open positions are force-flattened. |
| `strategy_sl_gap_frac` | 0.5 | 0.25-1.0 | Hard-stop distance as a fraction of the (L2,L3)/(H2,H3) gap beyond the mid band. |
| `strategy_spread_cap_pts` | 20 | 5-60 | Max spread (points) that still permits entry; only a genuinely wide spread blocks. |
| `strategy_opp_break_exit` | true | true/false | Enable the tertiary opposite-pivot (hourly close) soft exit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deepest-liquidity major; tight spreads suit spread-sensitive inner-pivot fades.
- `GBPUSD.DWX` — liquid major with wider daily range; more frequent inner-band touches.
- `USDJPY.DWX` — liquid major; range-bound intraday sessions favour pivot reversion.
- `EURJPY.DWX` — liquid cross with clean European-session ranges (matches the 06:00-18:00 window).
- `GBPJPY.DWX` — high-range cross; frequent inner-pivot touches, judged by Q02 on cost.

**Explicitly NOT for:**
- Index/metal CFDs (`NDX.DWX`, `XAUUSD.DWX`, etc.) — gap behaviour and session structure differ from the FX-pair Camarilla calibration; out of the card's R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `PERIOD_D1` (prior-day H/L/C → Camarilla levels), `PERIOD_M15` (inner-fade gate), `PERIOD_H1` (opposite-pivot soft exit) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1/PERIOD_M15/PERIOD_H1)` per-cadence; per-tick entry reads cached levels |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~150` |
| Typical hold time | `intraday (minutes to hours; always flat by 21:00 broker-time)` |
| Expected drawdown profile | `~12% expected DD; clustered losers on trend days that run through the mid band` |
| Regime preference | `mean-revert (range-bound intraday sessions)` |
| Win rate target (qualitative) | `medium-high (tight TP at P), offset by full-gap stops` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `ForexFactory Trading Systems — Camarilla Equation cluster (https://www.forexfactory.com/search?q=camarilla+equation)`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_20075_camarilla-inner-pivot-fade.md`

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
| v1 | 2026-08-11 | Initial build from card | build task 81793202-f0ec-45d3-9e99-96c1a619a626 |

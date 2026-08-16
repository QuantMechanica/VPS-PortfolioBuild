# QM5_20082_connors-rsi2-pullback-h4 — Strategy Spec

**EA ID:** QM5_20082
**Slug:** `connors-rsi2-pullback-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

Connors RSI(2) pullback-in-trend mean reversion on the H4 timeframe. The EA fades
an ultra-short RSI(2) extreme, but only in the direction of the longer-term trend,
so it buys shallow pullbacks inside uptrends and sells shallow rallies inside
downtrends. Six closed-form gates must all agree before an entry fires:

1. **Trend filter** — long requires `close[1] > SMA(200,H4)[1]`; short requires
   `close[1] < SMA(200,H4)[1]`.
2. **RSI(2) extreme** — long requires `RSI(2,H4)[1] < 10`; short requires
   `RSI(2,H4)[1] > 90`.
3. **Pullback magnitude** — long requires `close[1] <= close[4] - 0.5*ATR(20,H4)[1]`
   (a real pullback of at least half an ATR over the last three bars); short mirrors
   with `close[1] >= close[4] + 0.5*ATR(20,H4)[1]`.
4. **D1 macro-bias agreement** — long requires `SMA(50,D1)[1] >= SMA(50,D1)[11]`
   (rising/flat daily trend); short mirrors with `<=`.
5. **Entry uniqueness** — no same-direction entry within the past 10 H4 bars.
6. **Trend establishment** — at least 8 of the past 12 H4 bars closed on the trend
   side of SMA(200) (regime is established, not a fresh cross).

A spread guard skips entries when `spread > 0.15*ATR(20,H4)` (but never fail-closes
on a zero spread, which `.DWX` symbols legitimately quote in the tester). Entries are
market orders at ask (long) / bid (short) with a backstop stop at `1.5*ATR(20,H4)`
against the trigger and no fixed take-profit.

Exits are Connors-canonical mean-line touches plus safety stops, all evaluated per
tick while a position is open:
- **Time-stop** — close fully once the position is `>= 12` H4 bars old.
- **RSI-overshoot hard exit** — within the first 3 bars, close a long if
  `RSI(2) > 95`, close a short if `RSI(2) < 5`.
- **TP1** — partial close 75% when price touches SMA(5,H4) back through the mean
  line (bid `>=` SMA(5) for longs, ask `<=` SMA(5) for shorts).
- **TP2** — close the remainder when price reaches SMA(10,H4) (bid `>=` SMA(10)
  for longs, ask `<=` SMA(10) for shorts).

One position per magic (HR14). All exits live in `Strategy_ManageOpenPosition`;
`Strategy_ExitSignal` returns false.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `rsi_period` | 2 | 2-5 | RSI period (Connors ultra-short) |
| `rsi_oversold` | 10.0 | 5-20 | Long RSI(2) extreme threshold |
| `rsi_overbought` | 90.0 | 80-95 | Short RSI(2) extreme threshold |
| `trend_sma_period` | 200 | 100-300 | Long-term trend SMA on H4 |
| `exit_sma_fast` | 5 | 3-10 | TP1 mean-line SMA period |
| `exit_sma_mid` | 10 | 8-20 | TP2 mean-line SMA period |
| `atr_period` | 20 | 10-30 | ATR period for pullback/stop sizing |
| `pullback_atr_mult` | 0.5 | 0.25-1.0 | Min pullback in ATR over 3 bars |
| `entry_uniqueness_bars` | 10 | 5-20 | Min bars between same-direction entries |
| `trend_establish_lookback` | 12 | 8-24 | Window for trend-establishment count |
| `trend_establish_min_bars` | 8 | 5-12 | Min bars on trend side within window |
| `sl_atr_mult` | 1.5 | 1.0-2.5 | Backstop stop in ATR against trigger |
| `time_stop_bars` | 12 | 6-24 | Max hold in H4 bars |
| `rsi_overshoot` | 95.0 | 90-99 | RSI(2) hard-exit level (long; short uses 100-x) |
| `rsi_overshoot_window_bars` | 3 | 1-6 | Early window for RSI-overshoot exit |
| `spread_atr_mult_cap` | 0.15 | 0.05-0.5 | Max spread as a fraction of ATR |
| `partial_close_pct` | 0.75 | 0.25-0.9 | Fraction closed at TP1 |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — deep, liquid FX major; clean H4 mean reversion inside SMA(200) trend.
- `GBPUSD.DWX` — liquid major with regular pullback-in-trend behaviour.
- `USDJPY.DWX` — trending major where the D1 macro-bias gate adds value.
- `AUDUSD.DWX` — commodity-linked major with orderly H4 pullbacks.
- `USDCAD.DWX` — commodity-linked major, complementary regime to AUDUSD.
- `XAUUSD.DWX` — gold; strong persistent trends make the SMA(200) filter effective and
   the ATR-scaled pullback/stop adapts to its higher volatility.

**Explicitly NOT for:**
- Index / equity CFDs (e.g. `NDX.DWX`, `WS30.DWX`) — overnight index swaps and gap
  behaviour distort the short-hold H4 mean-reversion edge; kept to FX majors + gold.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `D1 SMA(50) macro-bias read (shift 1 and 11)` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | `hours to a few days (time-stop 12 H4 bars = 2 days)` |
| Expected drawdown profile | `moderate; ~15% target, mean-reversion clusters correlate across symbols` |
| Regime preference | `mean-revert (pullback-in-trend)` |
| Win rate target (qualitative) | `high` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/` (ForexFactory
trading-systems Connors RSI-2 cluster; grounded in Larry Connors & Cesar Alvarez,
*Short Term Trading Strategies That Work*, TradingMarkets Publishing 2008,
ISBN 978-0-9819239-0-1, ch. 5)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_20082_connors-rsi2-pullback-h4.md`

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
| v1 | 2026-08-11 | Initial build from card | build(claude): QM5_20082 |

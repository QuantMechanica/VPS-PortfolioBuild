# QM5_11139_bt-pink-20high — Strategy Spec

**EA ID:** QM5_11139
**Slug:** `bt-pink-20high`
**Source:** `7c42dba8-ef06-5c8f-b837-0cafea39ecbe` (Daniel Rodriguez / backtrader pinkfish-challenge sample)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Long-only N-bar high breakout (Donchian-style) with a fixed-hold exit, on D1.
On the close of each daily bar the EA computes the highest high of the 20
CLOSED bars that precede the just-closed signal bar (shifts 2..21). If the
just-closed signal bar (shift 1) prints a high above that prior-20-bar high, a
fresh 20-bar high has been made and the EA buys at the next bar open
(market-on-new-closed-bar). Only closed bars feed the signal, so it cannot
repaint on a gapless `.DWX` CFD. The position is closed by a time stop after 2
closed D1 bars in market. There is no profit target (per the source baseline);
an emergency stop sits at the wider (lower) of `entry - 2.5 * ATR(14)` and the
signal-bar low.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_high_lookback` | 20 | 10-50 | N-bar highest-high lookback over prior closed bars |
| `strategy_hold_bars` | 2 | 1-5 | Close the position after this many closed D1 bars in market |
| `strategy_atr_period` | 14 | 7-28 | ATR period for the emergency stop |
| `strategy_sl_atr_mult` | 2.5 | 2.0-3.0 | Emergency stop distance = mult × ATR |
| `strategy_spread_pct_of_stop` | 15.0 | 5-30 | Skip entry if spread exceeds this % of the stop distance (fail-open on zero spread) |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, news,
> qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are documented
> in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX, trends produce clean 20-bar D1 breakouts.
- `GBPUSD.DWX` — liquid major FX with multi-day momentum legs.
- `XAUUSD.DWX` — strong trending commodity, frequent fresh highs.
- `GDAXI.DWX` — DAX 40 index; card said GER40, ported to the matrix symbol GDAXI.DWX.
- `NDX.DWX` — Nasdaq 100, persistent uptrend regime suits breakout-and-hold.
- `WS30.DWX` — Dow 30, broad large-cap index breakouts.

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only custom symbol (not broker-routable); the card lists
  it only as an optional proxy, so it is omitted from the live-portable basket.

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
| Trades / year / symbol | `~25` |
| Typical hold time | `2 trading days (fixed hold)` |
| Expected drawdown profile | `frequent small losses from failed breakouts; bounded by ATR stop` |
| Regime preference | `breakout / momentum` |
| Win rate target (qualitative) | `low-medium (short fixed hold truncates trends)` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `7c42dba8-ef06-5c8f-b837-0cafea39ecbe`
**Source type:** `OSS backtester sample (Python)`
**Pointer:** `https://github.com/mementum/backtrader/blob/master/samples/pinkfish-challenge/pinkfish-challenge.py`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11139_bt-pink-20high.md`

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

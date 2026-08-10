# QM5_12355_orev-powertrend — Strategy Spec

**EA ID:** QM5_12355
**Slug:** `orev-powertrend`
**Source:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab` (see `strategy-seeds/sources/72f9fcfa-6c75-5544-80c4-31e15c9817ab/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Long-only D1 trend-persistence system. On each closed D1 bar the EA computes
EMA(21), SMA(50) and ATR(21). A long is taken only when the trend has been
persistently strong: every one of the last 10 closed bars has its low above
EMA(21), every one of the last 5 closed bars has EMA(21) above SMA(50), SMA(50)
is rising versus the prior bar, and the signal bar is bullish (close[1] >
open[1]). With no open position for this magic/symbol the EA buys at the next
bar open. The long is closed when EMA(21) falls below SMA(50) on a closed bar
(a state check, not a same-bar double cross). A wide catastrophic ATR hard stop
and the V5 Friday-close sweep backstop the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 21 | 14-30 | EMA fast trend line (Powertrend EMA21) |
| `strategy_sma_period` | 50 | 40-75 | SMA slow trend line (Powertrend SMA50) |
| `strategy_low_above_ema_window` | 10 | 5-15 | Require low > EMA over the last N closed bars |
| `strategy_ema_above_sma_window` | 5 | 3-8 | Require EMA > SMA over the last N closed bars |
| `strategy_atr_period` | 21 | 14-30 | ATR period for the catastrophic stop |
| `strategy_atr_stop_mult` | 4.0 | 3.0-6.0 | Catastrophic stop distance = mult × ATR(period) |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 cash index; strong, persistent secular uptrends suit a low-above-EMA persistence gate.
- `NDX.DWX` — Nasdaq 100; high-momentum US large-cap index, same trend-persistence regime.
- `WS30.DWX` — Dow 30; broad US large-cap trend exposure, decorrelates slightly from tech-heavy NDX.
- `EURUSD.DWX` — most liquid FX major; sustained directional swings give the persistence filter room to work.
- `XAUUSD.DWX` — gold; pronounced multi-month trends, a classic trend-persistence instrument.

**Explicitly NOT for:**
- Range-bound / mean-reverting instruments — the 10-bar low-above-EMA gate rarely qualifies without a durable trend.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar()` (single-consume latch; state advanced once per new D1 bar) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~10 (card estimate 4-16) |
| Typical hold time | Days to weeks (holds while EMA stays above SMA) |
| Expected drawdown profile | ~20% expected DD; trend-following gives back open profit on trend breaks |
| Regime preference | Trend-following (persistent bullish regime) |
| Win rate target (qualitative) | Low-to-medium (trend systems: fewer winners, larger average win) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `72f9fcfa-6c75-5544-80c4-31e15c9817ab`
**Source type:** forum/repo (open-source GitHub algorithmic-trading code)
**Pointer:** `oreilm49/quantconnect`, `Powertrend/main.py` — https://github.com/oreilm49/quantconnect/blob/master/Powertrend/main.py
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_12355_orev-powertrend.md`

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
| v1 | 2026-08-10 | Initial build from card | task 756354c8-615c-4560-b6d9-c45b5b037b97 |

> When this EA cycles back to Q01 from a Q02 zero-trade event, add a row:
> `| v2 | YYYY-MM-DD | Q02 all-symbol zero-trades; widened entry filter X | <commit> |`

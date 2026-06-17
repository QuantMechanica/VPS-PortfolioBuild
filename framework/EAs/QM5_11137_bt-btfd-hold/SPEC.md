# QM5_11137_bt-btfd-hold — Strategy Spec

**EA ID:** QM5_11137
**Slug:** `bt-btfd-hold`
**Source:** `7c42dba8-ef06-5c8f-b837-0cafea39ecbe` (Daniel Rodriguez / backtrader BTFD sample)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Buy-the-dip with a fixed holding period, long-only on the D1 timeframe. On the
close of each daily bar the EA measures the intraday drop of that bar using the
`highlow` approach: `low / high - 1`. When this drop is at least `fall_pct`
(default 1.0%, i.e. `low/high - 1 <= -0.01`), the EA opens one long position at
market. The position is closed exactly `hold_bars` (default 2) closed D1 bars
after the entry bar — a pure time stop, mirroring the source's `hold=2` default.
The source baseline has no profit target; a protective emergency stop (the wider
of `stop_atr_mult * ATR(14)` and `stop_min_adverse_pct` of entry) guards against
catastrophic adverse moves only. One open position per symbol/magic at a time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fall_pct` | 1.0 | 0.5-2.0 | Dip trigger: `low[1]/high[1]-1 <= -fall_pct%` fires a long |
| `strategy_hold_bars` | 2 | 1-5 | Close the position exactly N closed D1 bars after entry |
| `strategy_atr_period` | 14 | 5-50 | ATR period for the emergency protective stop |
| `strategy_stop_atr_mult` | 2.5 | 1.5-3.5 | Emergency stop = mult × ATR |
| `strategy_stop_min_adverse_pct` | 2.0 | 1.0-3.0 | Emergency-stop floor as % adverse move of entry (wider of the two wins) |
| `strategy_spread_pct_of_stop` | 15.0 | 5.0-30.0 | Skip a trade if spread exceeds this % of the emergency-stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — Nasdaq 100; equity-index dip-buy is the source's native regime
- `WS30.DWX` — Dow 30; same equity-index mean-reversion behaviour
- `GDAXI.DWX` — DAX 40; ported from card's `GER40` (not in matrix); EU large-cap index dip
- `XAUUSD.DWX` — gold; sharp-drop short-term rebound candidate (card listed `XAUUSD`)
- `EURUSD.DWX` — major FX; card R3 portability test for dip behaviour outside equities
- `GBPUSD.DWX` — major FX; same FX-portability test
- `SP500.DWX` — S&P 500; the source's native `^GSPC` analogue (backtest-only Custom Symbol)

**Explicitly NOT for:**
- `SPX500.DWX` / `SPY.DWX` / `ES.DWX` — not the canonical Custom Symbol name; `SP500.DWX` is the only valid S&P proxy

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
| Trades / year / symbol | `~35` |
| Typical hold time | `2 days (fixed hold)` |
| Expected drawdown profile | `countertrend — risk of catching falling markets; overnight/weekend gaps on D1` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `7c42dba8-ef06-5c8f-b837-0cafea39ecbe`
**Source type:** `forum` (open-source backtester sample code)
**Pointer:** `https://github.com/mementum/backtrader/blob/master/samples/btfd/btfd.py`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11137_bt-btfd-hold.md`

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
| v1 | 2026-06-17 | Initial build from card | pending build commit |

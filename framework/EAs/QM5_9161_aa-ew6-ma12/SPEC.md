# QM5_9161_aa-ew6-ma12 — Strategy Spec

**EA ID:** QM5_9161
**Slug:** `aa-ew6-ma12`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

Each EA instance applies Alpha Architect's equal-weight monthly trend rule to a single DWX index or commodity proxy. On the first trading day of each new calendar month the EA evaluates the last completed D1 bar's close against a 252-bar simple moving average (12-month proxy; MN1 is untestable in MT5 tester). If close > SMA(252) the EA holds one long position sized by RISK_FIXED/$RISK_PERCENT at a catastrophic 3 × ATR(20, D1) stop; if close ≤ SMA(252) the sleeve goes flat. No intra-month re-entry or reversal occurs.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 252 | 100-500 | D1-bar SMA lookback; 252 ≈ 12 calendar months |
| `strategy_atr_period` | 20 | 5-50 | ATR lookback for catastrophic stop distance |
| `strategy_atr_stop_mult` | 3.0 | 1.0-6.0 | ATR multiplier for initial catastrophic stop |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 proxy; backtest-only (broker does not route orders)
- `NDX.DWX` — Nasdaq 100; live-tradable US large-cap index proxy
- `WS30.DWX` — Dow Jones 30; live-tradable US large-cap / REIT proxy
- `GDAXI.DWX` — DAX 40; European equity proxy (ported from GER40.DWX not in matrix)
- `UK100.DWX` — FTSE 100; European equity proxy
- `XAUUSD.DWX` — Gold; GSCI commodity sleeve proxy
- `XTIUSD.DWX` — WTI crude oil; GSCI energy sleeve proxy

**Explicitly NOT for:**
- `JPN225.DWX` / `JP225.DWX` — not in dwx_symbol_matrix.csv; omitted
- `SPX500.DWX` / `ES.DWX` — not canonical; use SP500.DWX
- Forex pairs — monthly trend rule designed for equity/commodity asset classes only

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default); monthly rebalance state advances once per broker calendar month after the framework new-bar gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (at most one entry per calendar month) |
| Typical hold time | 1–12 months |
| Expected drawdown profile | Trend-following; drawdown during extended bear markets |
| Regime preference | trend-following |
| Win rate target (qualitative) | low-medium (large average winners vs small losers) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** blog / paper
**Pointer:** Wesley Gray PhD, "Tactical Asset Allocation Series Part 3 (Equal-Weight with Moving Averages)", Alpha Architect, 2012-11-25
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9161_aa-ew6-ma12.md`

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
| v1 | 2026-06-10 | Initial build from card | 15e951dc-ad54-4999-9afb-33da8a7815af |

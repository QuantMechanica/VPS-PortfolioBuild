# QM5_10022_rw-dual-mom — Strategy Spec

**EA ID:** QM5_10022
**Slug:** `rw-dual-mom`
**Source:** `dcbac84f-6ecf-5d21-9630-50faa69306ec`
**Author of this spec:** Claude
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On the first D1 bar of each calendar month the EA computes the 6-month total return (last 126 D1 closes) for each member of the four-symbol universe: SP500.DWX, NDX.DWX, WS30.DWX, XAUUSD.DWX. Symbols are ranked by this return (relative momentum). The EA enters long on the current chart symbol if and only if it ranks inside the top 3 (cross-sectional filter) AND its own 6-month return is positive (absolute momentum filter). If already in a position that no longer qualifies at month-end, the position is closed. A catastrophic stop of 3 × ATR(20, D1) is placed at entry; the primary exit is the monthly rotation check.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_formation_period` | 126 | 60–252 | D1 bars for 6-month return (lookback window) |
| `strategy_max_held` | 3 | 1–4 | Maximum universe members selected simultaneously |
| `strategy_atr_period` | 20 | 10–50 | ATR period for catastrophic SL |
| `strategy_atr_sl_mult` | 3.0 | 1.5–6.0 | Catastrophic SL = N × ATR(period, D1) |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 US large-cap index; primary US equity benchmark in the rotation (backtest-only; not broker-routable)
- `NDX.DWX` — Nasdaq 100 US tech index; second US equity benchmark, live-tradable
- `WS30.DWX` — Dow Jones 30 US blue-chip index; third US equity benchmark, live-tradable
- `XAUUSD.DWX` — Gold spot; risk-off diversifier with low correlation to equities in stress regimes

**Explicitly NOT for:**
- Any forex pair — strategy relies on equity/commodity momentum, not rate differentials

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | ATR(20, D1) for catastrophic SL; no other MTF reads |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (monthly rebalance cadence) |
| Typical hold time | 1 month (20–23 trading days) |
| Expected drawdown profile | Low-frequency; catastrophic SL 3× ATR(D1) wide |
| Regime preference | Trend / momentum (long-only index rotation) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `dcbac84f-6ecf-5d21-9630-50faa69306ec`
**Source type:** article / blog
**Pointer:** Robot Wealth / Kris Longmore, "Dual Momentum Investing: A Quant's Review", robotwealth.com
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10022_rw-dual-mom.md`

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
| v1 | 2026-06-10 | Initial build from card | b0eb5dce-bf5e-447a-b207-b45a64e34c42 |

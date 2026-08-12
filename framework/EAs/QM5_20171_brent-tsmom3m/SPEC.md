# QM5_20171_brent-tsmom3m — Strategy Spec

**EA ID:** QM5_20171
**Slug:** `brent-tsmom3m`
**Source:** `MOP-TSMOM-2012` (see `strategy-seeds/sources/MOP-TSMOM-2012/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-26

## 1. Strategy Logic

On the first D1 bar of each broker month, compare the last completed Brent
close with the completed close 63 D1 bars earlier. Buy when
`log(Close[1] / Close[64])` is positive and sell when it is negative. Close
the package at the next monthly boundary or after 31 calendar days, and attach
a frozen `3.5 * ATR(20)` hard stop at entry.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_momentum_lookback_d1` | 63 | 63 | Completed D1 return horizon |
| `strategy_min_abs_return_pct` | 0.0 | 0.0 | Strict return-sign threshold |
| `strategy_atr_period` | 20 | 20 | Completed D1 risk estimator |
| `strategy_atr_sl_mult` | 3.5 | 3.5 | Frozen hard-stop distance |
| `strategy_max_hold_days` | 31 | 31 | Stale package close |
| `strategy_max_spread_points` | 1000 | 1000 | Entry spread ceiling |

## 3. Symbol Universe

**Designed for:**

- `XBRUSD.DWX` — registered Brent CFD carrier for the source-backed energy trend.

**Explicitly NOT for:**

- `XTIUSD.DWX` — WTI already has a separately registered three-month carrier.
- `XNGUSD.DWX` — natural gas already has a separately registered carrier.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Monthly calendar key only; price and ATR are D1 |
| Bar gating | `QM_IsNewBar()` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 renewed packages; minimum acceptable average is 5 |
| Typical hold time | One broker month, capped at 31 calendar days |
| Expected drawdown profile | High; Brent gaps, roll/basis, and trend whipsaw are first-order risks |
| Regime preference | Persistent medium-horizon uptrends or downtrends |
| Win rate target (qualitative) | Low to medium, with asymmetric trend payoffs |

## 6. Source Citation

**Source ID:** `MOP-TSMOM-2012`  
**Source type:** peer-reviewed paper  
**Pointer:** `strategy-seeds/sources/MOP-TSMOM-2012/` and DOI `10.1016/j.jfineco.2011.11.003`  
**R1–R4 verdict (Q00):** all PASS; see `artifacts/cards_approved/QM5_20171_brent-tsmom3m_card.md`

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`).

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-26 | Initial build from card | paced commodity/energy sleeve mission |

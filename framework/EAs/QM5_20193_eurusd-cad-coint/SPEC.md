# QM5_20193_eurusd-cad-coint — Strategy Spec

**EA ID:** QM5_20193
**Slug:** `eurusd-cad-coint`
**Source:** `claude_cross_asset_discovery_2026-06-09` with the OWNER-ratified
Chan SRC02 pair-trade method
**Author of this spec:** Codex
**Last revised:** 2026-08-01

---

## 1. Strategy Logic

After each newly closed D1 bar, compute the fixed spread
`ln(EURUSD.DWX) - (-0.839757300) * ln(USDCAD.DWX)`. Score the newest spread
against the mean and sample standard deviation of the strictly preceding 60
aligned D1 spreads. Open both legs short when `z > 2.0`, open both legs long
when `z < -2.0`, and close the complete package when `abs(z) < 0.5`. Each leg
also receives a hard `2.0 * ATR(20, D1)` stop; partial entry or an orphaned
leg is flattened immediately.

---

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---:|---|
| `strategy_z_lookback_d1` | 60 | 40, 60, 90 | Strictly prior spread-calibration bars |
| `strategy_beta` | -0.839757300 | fixed | DEV-fitted structural hedge coefficient |
| `strategy_entry_z` | 2.0 | 1.75, 2.0, 2.25 | Absolute entry threshold |
| `strategy_exit_z` | 0.5 | 0.25, 0.5, 0.75 | Mean-reach exit threshold |
| `strategy_atr_period_d1` | 20 | 14, 20, 30 | Per-leg hard-stop ATR period |
| `strategy_atr_sl_mult` | 2.0 | 1.5, 2.0, 2.5 | Per-leg hard-stop multiplier |
| `strategy_deviation_points` | 20 | fixed for Q02 | Market-order deviation |

The fitted beta is structural and is not an arbitrary Q03 neighborhood axis.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — fixed host and first traded leg from the frozen scan row.
- `USDCAD.DWX` — fixed companion and second traded leg from the same row.

**Explicitly not for:**

- Any substituted FX symbol — substitution changes the fitted residual and is
  a different hypothesis.
- Bare broker symbols — research and backtest artifacts retain the `.DWX`
  suffix; no live artifact is authorized.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; both legs use aligned closed D1 bars |
| Bar gating | `QM_IsNewBar(EURUSD.DWX, PERIOD_D1)` consumed once per signal bar |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 3 completed package entries per leg |
| Basket state changes | approximately 6-7 per year |
| Typical hold time | multi-day; scan half-life 160.705 D1 bars |
| Expected drawdown profile | high and regime-sensitive; conservative 30% prior |
| Regime preference | common-USD residual mean reversion |
| Win rate target | unknown; Q02 is the first platform-economic judge |

The fixed scan recorded DEV net Sharpe `0.006938`, OOS net Sharpe `0.734143`,
OOS return `4.351185%`, and 14 OOS state changes. These are adverse/weak
frontier priors, not a promotion claim.

---

## 6. Source Citation

**Source ID:** `claude_cross_asset_discovery_2026-06-09`
**Source type:** OWNER-requested in-house fixed scan plus Tier-A book method
**Pointer:** `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`,
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
--include-negative-hedges`, and
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2-R4 PASS in
`artifacts/cards_approved/QM5_20193_eurusd-cad-coint_card.md`

Chan supplies the deterministic pair-trading method but makes no performance
claim for EURUSD/USDCAD.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 package budget (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3%-0.5% |

The backtest setfiles explicitly use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The package budget is split by absolute hedge weights
`1.0` and `0.839757300`; each leg is independently bounded by its ATR stop.
ENV-to-mode validation remains enforced by `QM_FrameworkInit`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-01 | Initial build from approved card | Build task `31d54db7-2160-451f-a324-cfb25c678dd5` |

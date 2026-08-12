# QM5_20207_usdcad-audusd — Strategy Spec

**EA ID:** QM5_20207
**Slug:** `usdcad-audusd`
**Source:** `claude_cross_asset_discovery_2026-06-09` with the OWNER-ratified
Chan SRC02 pair-trade method
**Author of this spec:** Codex
**Last revised:** 2026-08-03

---

## 1. Strategy Logic

After each newly closed D1 bar, compute the fixed spread
`ln(USDCAD.DWX) - (-0.460267756) * ln(AUDUSD.DWX)`. Score the newest spread
against the mean and sample standard deviation of the strictly preceding 60
aligned D1 spreads. Open both legs short when `z > 2.0`, open both legs long
when `z < -2.0`, and close the complete package when `abs(z) < 0.5`. Each leg
also receives a hard `2.0 * ATR(20, D1)` stop. Both normalized volumes are
preflighted; partial entry or an orphaned leg is flattened immediately.

---

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---:|---|
| `strategy_z_lookback_d1` | 60 | 40, 60, 90 | Strictly prior spread-calibration bars |
| `strategy_beta` | -0.460267756 | fixed | DEV-fitted structural hedge coefficient |
| `strategy_entry_z` | 2.0 | 1.75, 2.0, 2.25 | Absolute entry threshold |
| `strategy_exit_z` | 0.5 | 0.25, 0.5, 0.75 | Mean-reach exit threshold |
| `strategy_atr_period_d1` | 20 | 14, 20, 30 | Per-leg hard-stop ATR period |
| `strategy_atr_sl_mult` | 2.0 | 1.5, 2.0, 2.5 | Per-leg hard-stop multiplier |
| `strategy_deviation_points` | 20 | fixed for Q02 | Market-order deviation |

The fitted beta is structural and is not an arbitrary Q03 neighborhood axis.

---

## 3. Symbol Universe

**Designed for:**

- `USDCAD.DWX` — fixed host and first traded leg from the frozen scan row.
- `AUDUSD.DWX` — fixed companion and second traded leg from the same row.

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
| Bar gating | `QM_IsNewBar(USDCAD.DWX, PERIOD_D1)` consumed once per signal bar |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 5 completed package entries per leg |
| Basket state changes | 20 across the 2023-2024 OOS window |
| Typical hold time | multi-day; scan half-life 50.048 D1 bars |
| Expected drawdown profile | high and regime-sensitive; conservative 30% prior |
| Regime preference | common-USD residual mean reversion |
| Win rate target | unknown; Q02 is the first platform-economic judge |

The fixed scan recorded DEV net Sharpe `0.610821`, OOS net Sharpe `0.485169`,
OOS return `2.072809%`, and 20 OOS state changes. These are adverse/weak
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
`artifacts/cards_approved/QM5_20207_usdcad-audusd_card.md`

Chan supplies the deterministic pair-trading method but makes no performance
claim for USDCAD/AUDUSD.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 package budget (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Not authorized by this build |
| Full live (post-Q13 PASS) | RISK_PERCENT | Not authorized by this build |

The backtest setfiles explicitly use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The package budget is split by absolute hedge weights
`1.0` and `0.460267756`; each leg is independently bounded by its ATR stop.
ENV-to-mode validation remains enforced by `QM_FrameworkInit`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-03 | Initial build from approved card | Next-ranked non-duplicate FX sleeve |

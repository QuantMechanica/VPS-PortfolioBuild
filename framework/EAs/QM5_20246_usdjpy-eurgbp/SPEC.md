# QM5_20246_usdjpy-eurgbp — Strategy Spec

**EA ID:** QM5_20246
**Slug:** `usdjpy-eurgbp`
**Source:** `claude_cross_asset_discovery_2026-06-09` with the OWNER-ratified Chan SRC02 pair-trade method
**Author of this spec:** Codex
**Last revised:** 2026-08-06

---

## 1. Strategy Logic

After each newly closed D1 bar, compute the fixed spread
`ln(USDJPY.DWX) - (-1.281773609960) * ln(EURGBP.DWX)`. Score the newest spread
against the mean and sample standard deviation of the strictly preceding 60
aligned D1 spreads. Open both legs short when `z > 2.0`, open both legs long
when `z < -2.0`, and close the package when `abs(z) < 0.5`. Each traded leg
also receives a hard `2.0 * ATR(20, D1)` stop. Both normalized volumes are
preflighted before entry; a partial entry or orphaned leg is flattened.

---

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---:|---|
| `strategy_z_lookback_d1` | 60 | 40, 60, 90 | Strictly prior spread-calibration bars |
| `strategy_beta` | -1.281773609960 | fixed | DEV-fitted structural hedge coefficient |
| `strategy_entry_z` | 2.0 | 1.75, 2.0, 2.25 | Absolute entry threshold |
| `strategy_exit_z` | 0.5 | 0.25, 0.5, 0.75 | Mean-reach exit threshold |
| `strategy_atr_period_d1` | 20 | 14, 20, 30 | Per-leg hard-stop ATR period |
| `strategy_atr_sl_mult` | 2.0 | 1.5, 2.0, 2.5 | Per-leg hard-stop multiplier |
| `strategy_deviation_points` | 20 | fixed for Q02 | Market-order deviation |

The fitted beta is structural and is not a Q03 neighborhood axis.

---

## 3. Symbol Universe

**Designed for:**

- `USDJPY.DWX` — fixed tester host and first traded leg.
- `EURGBP.DWX` — fixed companion and second traded leg.
- `GBPUSD.DWX` and `EURUSD.DWX` — conversion-history dependencies for EURGBP
  accounting; order-free and without magic slots.

**Explicitly not for:** substituted symbols, bare broker names, live
environments, or live setfiles.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none; aligned closed D1 bars on both legs |
| Bar gating | `QM_IsNewBar(USDJPY.DWX, PERIOD_D1)` once per signal bar |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 3 completed package entries per leg |
| OOS basket state changes | 13 across 2023–2024 in the frozen scan |
| Typical hold time | multi-day; scan half-life 132.813 D1 bars |
| Expected drawdown profile | high and regime-sensitive; conservative 30% prior |
| Regime preference | USDJPY/EURGBP fixed-residual mean reversion |
| Win rate target | unknown; Q02 is the first platform-economic judge |

The fixed scan recorded DEV net Sharpe `0.252701098850`, OOS net Sharpe
`-0.456864966287`, and OOS return `-6.371810072221%`. These are adverse priors,
not a promotion claim.

---

## 6. Source Citation

**Source ID:** `claude_cross_asset_discovery_2026-06-09`
**Source type:** OWNER-requested in-house fixed scan plus Tier-A book method
**Pointer:** `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`,
`framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
--include-negative-hedges`, and
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
**R1–R4 verdict (Q00):** recorded in
`strategy-seeds/cards/approved/QM5_20246_usdjpy-eurgbp_card.md`

Chan supplies the method but makes no USDJPY/EURGBP performance claim.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02–Q10) | RISK_FIXED | $1,000 package budget |
| Live burn-in | RISK_PERCENT | Not authorized by this build |
| Full live | RISK_PERCENT | Not authorized by this build |

The backtest setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The package budget is split by absolute hedge weights
`1.0` and `1.281773609960`; each leg is bounded by its ATR stop.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-06 | Initial approved-card build | Next-rank-60 non-duplicate fixed-scan FX basket |

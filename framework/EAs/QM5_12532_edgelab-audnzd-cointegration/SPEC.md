# QM5_12532_edgelab-audnzd-cointegration - Strategy Spec

**EA ID:** QM5_12532
**Slug:** `edgelab-audnzd-cointegration`
**Source:** `claude_cross_asset_discovery_2026-06-09` (see `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

On each D1 close the EA reads AUDUSD.DWX and NZDUSD.DWX closes and computes the spread `ln(AUDUSD) - 0.93 * ln(NZDUSD)`. It calculates a 60-bar z-score of that spread. If z is above +2.0 it opens a short-spread pair, short AUDUSD and long NZDUSD; if z is below -2.0 it opens a long-spread pair, long AUDUSD and short NZDUSD. The pair is closed when the cached spread z-score is back inside `abs(z) < 0.5`; each leg also carries a hard 2.0 * ATR(20, D1) stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_z_lookback_d1` | 60 | 20+ | D1 bars used to compute spread mean and standard deviation. |
| `strategy_beta` | 0.93 | >0 | Hedge-ratio coefficient in `ln(AUDUSD) - beta * ln(NZDUSD)`. |
| `strategy_entry_z` | 2.0 | >0 | Absolute z-score threshold for pair entry. |
| `strategy_exit_abs_z` | 0.5 | 0+ | Absolute z-score threshold for mean-reversion exit. |
| `strategy_atr_period_d1` | 20 | 1+ | D1 ATR period used for each leg's safety stop. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiple for each leg's hard stop. |
| `strategy_max_spread_points` | 0 | 0+ | Optional max broker spread in points for both legs; 0 disables it. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - only strategy-specific
> inputs are listed here.

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` - first leg of the approved AUDUSD/NZDUSD cointegrating pair.
- `NZDUSD.DWX` - second leg of the approved AUDUSD/NZDUSD cointegrating pair.

**Explicitly NOT for:**
- Other `.DWX` symbols - the card is a specific two-leg AUDUSD/NZDUSD cointegration strategy, not a generic FX basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `7` |
| Typical hold time | days to weeks |
| Expected drawdown profile | about `8%` expected drawdown, with card-level <=5% daily / <=10% total drawdown constraints downstream |
| Regime preference | mean-reversion in a stationary AUDUSD/NZDUSD spread |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `claude_cross_asset_discovery_2026-06-09`
**Source type:** paper plus in-house AI research
**Pointer:** `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12532_edgelab-audnzd-cointegration.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-10 | Initial build from card | 7f1000ad-b718-407b-99a0-bd88568712eb |

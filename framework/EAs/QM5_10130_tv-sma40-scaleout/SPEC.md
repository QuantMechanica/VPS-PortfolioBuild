# QM5_10130_tv-sma40-scaleout - Strategy Spec

**EA ID:** QM5_10130
**Slug:** `tv-sma40-scaleout`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades a 40-bar SMA continuation rule on H4 bars. It opens long when the last closed bar crosses from below to above SMA(40), and opens short when the last closed bar crosses from above to below SMA(40). The initial stop is 2.0 * ATR(14), with a staged scale-out at +1R and +2R when lot size permits. The remaining position exits on a cross back through SMA(40) or at the +3R take-profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 40 | 2-200 | SMA lookback used for entry and cross-back exit. |
| `strategy_atr_period` | 14 | 1-100 | ATR lookback used for the initial stop distance. |
| `strategy_atr_sl_mult` | 2.0 | 0.1-10.0 | Multiplier applied to ATR(14) for the protective stop. |
| `strategy_tp1_r` | 1.0 | 0.1-10.0 | First partial-close trigger in R multiples. |
| `strategy_tp2_r` | 2.0 | 0.1-10.0 | Second partial-close trigger in R multiples. |
| `strategy_tp3_r` | 3.0 | 0.1-10.0 | Final take-profit distance in R multiples. |
| `strategy_partial_fraction` | 0.33 | 0.01-0.90 | Fraction of initial volume attempted at each scale-out trigger. |
| `strategy_max_spread_stop_fraction` | 0.10 | 0.00-1.00 | Blocks new entries when spread exceeds this fraction of initial stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for. Be explicit about both inclusions
and exclusions.

**Designed for:**
- `EURUSD.DWX` - major FX pair with enough H4 history for SMA and ATR continuation tests.
- `GBPUSD.DWX` - major FX pair included in the card's portable P2 basket.
- `XAUUSD.DWX` - gold CFD included by the card for non-FX trend continuation behavior.
- `SP500.DWX` - broad US index custom symbol included by the card for backtest-only index behavior.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the broker/test matrix has no canonical DWX data for them.
- Live-only `SP500.DWX` deployment - SP500.DWX is backtest-only and requires T6 gate handling outside this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

How this EA should behave in production. Calibrates downstream gate expectations.

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | `H4 continuation trades; several bars to several days` |
| Expected drawdown profile | `ATR-stopped trend continuation with partial profit-taking` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView public script`
**Pointer:** `https://www.tradingview.com/script/c5VbhJaL-40-SMA-Scaling-Strategy/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10130_tv-sma40-scaleout.md`

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
| v1 | 2026-06-09 | Initial build from card | 67e195fa-76e1-43e9-b23d-25c0ad4794ba |

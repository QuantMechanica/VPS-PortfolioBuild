# QM5_12968_xag-weekly-oversold-swing - Strategy Spec

**EA ID:** QM5_12968
**Slug:** `xag-weekly-oversold-swing`
**Source:** `CEO-SURVIVOR-PORT-12915-2026-07-03`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

---

## 1. Strategy Logic

This EA implements the approved XAG survivor-port card. It opens a long
position when the last closed D1 close is above SMA(200) and is the lowest
close in the last 10 D1 bars. It exits when the last closed D1 close recovers
above SMA(10) or after 15 D1 bars, whichever comes first. A 2.5 x ATR(14)
protective stop supplies the framework risk-sizing distance.

The OnTick path keeps management and exits active before the entry-only news
gate, matching the current V5 ordering requirement.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_regime_period` | 200 | 50-300 | Long-only trend regime filter |
| `strategy_entry_lookback_low` | 10 | 5-30 | Lowest-close entry lookback |
| `strategy_sma_exit_period` | 10 | 3-30 | Mean-recovery exit threshold |
| `strategy_time_stop_days` | 15 | 5-30 | Maximum D1 bars held |
| `strategy_atr_period` | 14 | 5-30 | Protective stop ATR period |
| `strategy_atr_sl_mult` | 2.5 | 1.0-5.0 | Protective stop ATR multiple |

## 3. Symbol Universe

**Designed for:**
- `XAGUSD.DWX` - silver exposure gives a metal mean-reversion port distinct
  from the SP500 parent and from existing XAU-focused sleeves.

**Explicitly NOT for:**
- Other `.DWX` symbols - the approved card is a single-symbol survivor port and
  forbids parameter re-optimisation during the build.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 9 |
| Typical hold time | 5-15 trading days |
| Expected drawdown profile | Moderate-to-harsh swing drawdown, card estimate 15% |
| Regime preference | Mean-reversion pullbacks inside an uptrend |
| Win rate target (qualitative) | Medium-high |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `CEO-SURVIVOR-PORT-12915-2026-07-03`
**Source type:** OWNER survivor-port card with book lineage
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12968_xag-weekly-oversold-swing.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12968_xag-weekly-oversold-swing.md`

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3%-0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). Friday close defaults to disabled because the
card explicitly permits multi-day weekend holds for the swing class.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-03 | Initial build from card | `104621a0-5cca-4a9b-bec0-207b2af87354` |

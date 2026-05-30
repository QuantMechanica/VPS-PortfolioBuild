# QM5_9107_aa-mom-filter111 - Strategy Spec

**EA ID:** QM5_9107
**Slug:** aa-mom-filter111
**Source:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA evaluates the DWX proxy basket at the monthly rebalance. It computes 11-1 momentum as `Close(1) / Close(12) - 1`, then keeps only symbols whose 10-0 proxy momentum, `Close(0) / Close(10) - 1`, also ranks inside the same top decile. A passing symbol opens a long position with a 3.0 x ATR(20,D1) initial stop; an existing position closes at the next monthly rebalance when the symbol no longer passes both rank filters. The optional symmetric short-decile mode is declared as an input but disabled by default for the P2 baseline.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_min_monthly_bars | 24 | 24-120 | Minimum monthly history before a symbol can rank. |
| strategy_mom_11_1_recent_shift | 1 | 0-6 | Recent close shift for the 11-1 momentum filter. |
| strategy_mom_11_1_old_shift | 12 | 6-24 | Older close shift for the 11-1 momentum filter. |
| strategy_mom_10_0_recent_shift | 0 | 0-6 | Recent close shift for the 10-0 persistence filter. |
| strategy_mom_10_0_old_shift | 10 | 6-24 | Older close shift for the 10-0 persistence filter. |
| strategy_top_decile_pct | 10.0 | 1.0-50.0 | Percentile bucket used for rank inclusion. |
| strategy_enable_short_decile | false | false/true | Enables optional symmetric bottom-decile shorts. |
| strategy_atr_period_d1 | 20 | 5-100 | Daily ATR period used for the initial stop. |
| strategy_atr_sl_mult | 3.0 | 0.5-10.0 | ATR multiple for initial stop distance. |
| strategy_spread_median_mult | 2.5 | 0.5-10.0 | Blocks new entries when current spread is above this multiple of the 20-day median spread. |

---

## 3. Symbol Universe

**Designed for:**
- AUDCAD.DWX - DWX forex proxy included in the approved cross-sectional basket.
- AUDCHF.DWX - DWX forex proxy included in the approved cross-sectional basket.
- AUDJPY.DWX - DWX forex proxy included in the approved cross-sectional basket.
- AUDNZD.DWX - DWX forex proxy included in the approved cross-sectional basket.
- AUDUSD.DWX - DWX forex proxy included in the approved cross-sectional basket.
- CADCHF.DWX - DWX forex proxy included in the approved cross-sectional basket.
- CADJPY.DWX - DWX forex proxy included in the approved cross-sectional basket.
- CHFJPY.DWX - DWX forex proxy included in the approved cross-sectional basket.
- EURAUD.DWX - DWX forex proxy included in the approved cross-sectional basket.
- EURCAD.DWX - DWX forex proxy included in the approved cross-sectional basket.
- EURCHF.DWX - DWX forex proxy included in the approved cross-sectional basket.
- EURGBP.DWX - DWX forex proxy included in the approved cross-sectional basket.
- EURJPY.DWX - DWX forex proxy included in the approved cross-sectional basket.
- EURNZD.DWX - DWX forex proxy included in the approved cross-sectional basket.
- EURUSD.DWX - DWX forex proxy included in the approved cross-sectional basket.
- GBPAUD.DWX - DWX forex proxy included in the approved cross-sectional basket.
- GBPCAD.DWX - DWX forex proxy included in the approved cross-sectional basket.
- GBPCHF.DWX - DWX forex proxy included in the approved cross-sectional basket.
- GBPJPY.DWX - DWX forex proxy included in the approved cross-sectional basket.
- GBPNZD.DWX - DWX forex proxy included in the approved cross-sectional basket.
- GBPUSD.DWX - DWX forex proxy included in the approved cross-sectional basket.
- GDAXI.DWX - DWX index proxy included in the approved cross-sectional basket.
- NDX.DWX - DWX index proxy included in the approved cross-sectional basket.
- NZDCAD.DWX - DWX forex proxy included in the approved cross-sectional basket.
- NZDCHF.DWX - DWX forex proxy included in the approved cross-sectional basket.
- NZDJPY.DWX - DWX forex proxy included in the approved cross-sectional basket.
- NZDUSD.DWX - DWX forex proxy included in the approved cross-sectional basket.
- SP500.DWX - DWX S&P 500 proxy included in the approved cross-sectional basket.
- UK100.DWX - DWX index proxy included in the approved cross-sectional basket.
- USDCAD.DWX - DWX forex proxy included in the approved cross-sectional basket.
- USDCHF.DWX - DWX forex proxy included in the approved cross-sectional basket.
- USDJPY.DWX - DWX forex proxy included in the approved cross-sectional basket.
- WS30.DWX - DWX index proxy included in the approved cross-sectional basket.
- XAGUSD.DWX - DWX commodity proxy included in the approved cross-sectional basket.
- XAUUSD.DWX - DWX commodity proxy included in the approved cross-sectional basket.
- XNGUSD.DWX - DWX commodity proxy included in the approved cross-sectional basket.
- XTIUSD.DWX - DWX commodity proxy included in the approved cross-sectional basket.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no build-time registration or tester support.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 execution with monthly ranking refs |
| Multi-timeframe refs | PERIOD_MN1 for momentum ranks, PERIOD_D1 for ATR stop and spread median |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` plus `QM_IsNewBar(_Symbol, PERIOD_D1)` for monthly exit cadence |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Not specified in card frontmatter; monthly top-decile rebalance implies sparse turnover. |
| Typical hold time | Monthly to quarterly, per rebalance variant. |
| Expected drawdown profile | Momentum trend sleeve with drawdowns during cross-asset reversals. |
| Regime preference | Cross-sectional momentum. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Source type:** Alpha Architect blog
**Pointer:** Larry Swedroe, "Enhancing Momentum Strategies", 2025-06-13, https://alphaarchitect.com/momentum-investing/
**R1-R4 verdict (Q00):** all R1, R2, and R4 PASS; R3 body approves a DWX cross-sectional proxy basket per `artifacts/cards_approved/QM5_9107_aa-mom-filter111.md`.

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
| v1 | 2026-05-25 | Initial build from card | b92e0567-e40e-4c04-abd7-25919d28a2ab |

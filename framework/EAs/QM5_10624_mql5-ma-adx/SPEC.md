# QM5_10624_mql5-ma-adx - Strategy Spec

**EA ID:** QM5_10624
**Slug:** mql5-ma-adx
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA evaluates completed H1 bars only. It goes long when EMA(8) is rising across the latest closed bars, the previous close is above that EMA, ADX(8) is greater than 22, and +DI is greater than -DI. It goes short when EMA(8) is falling across the latest closed bars, the previous close is below that EMA, ADX(8) is greater than 22, and -DI is greater than +DI. Exits are the source fixed stop loss and take profit, with V5 Friday Close and kill-switch exits left active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma_period` | 8 | >=2 | EMA period used for slope and price relation. |
| `strategy_adx_period` | 8 | >=2 | ADX and DI period. |
| `strategy_adx_min` | 22.0 | >0 | Minimum ADX level required before entry. |
| `strategy_stop_loss_pips` | 30 | >0 | Fixed stop distance, implemented with V5 fixed-pip stop helper. |
| `strategy_take_profit_pips` | 100 | >0 | Fixed take-profit distance from market entry. |

Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-stated liquid FX target with DWX data available.
- `GBPUSD.DWX` - Card-stated liquid FX target with DWX data available.
- `USDJPY.DWX` - Card-stated liquid FX target with DWX data available.
- `XAUUSD.DWX` - Card-stated liquid gold target with DWX data available.

**Explicitly NOT for:**
- Non-DWX symbols - Research and backtest artifacts must keep the `.DWX` suffix.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol data guarantee.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | Not specified in card frontmatter; H1 fixed SL/TP trend trades are expected to hold from hours to several days. |
| Expected drawdown profile | Fixed-risk per-trade trend-following sleeve; losses are capped by fixed stop unless broker execution differs. |
| Regime preference | MA/ADX trend continuation. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/123
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10624_mql5-ma-adx.md`

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
| v1 | 2026-05-31 | Initial build from card | deb4d745-343d-4e91-a08a-d7edcf6ef4b0 |

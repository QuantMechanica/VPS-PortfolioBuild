# QM5_1641_aa-qend-mom-season - Strategy Spec

**EA ID:** QM5_1641
**Slug:** `aa-qend-mom-season`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

On the first D1 bar of each new month, the EA ranks a fixed DWX index basket by 12-1 momentum, using D1 month-end closes as the MN1 proxy: `Close(2) / Close(13) - 1`. It opens long exposure only when the current holding month is March, June, September, or December, never January, and only if the host symbol is in the positive top third of the ranked basket. Open positions are closed at the next monthly rebalance, then re-opened only if the symbol remains selected. Each entry receives a 3.0 x ATR(20,D1) initial stop and no fixed take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_roc_months` | 12 | 2-24 | Older month index used in the 12-1 momentum formula. |
| `strategy_exclude_recent_months` | 1 | 1-3 | Number of most recent completed months excluded from the momentum calculation. |
| `strategy_min_completed_months` | 14 | 14-36 | Minimum D1-derived month-end closes required before ranking. |
| `strategy_month_copy_bars` | 360 | 300-600 | D1 bars copied to derive completed month-end closes. |
| `strategy_atr_period_d1` | 20 | 5-60 | D1 ATR period for the initial stop. |
| `strategy_atr_sl_mult` | 3.0 | 0.5-10.0 | Initial stop distance as a multiple of D1 ATR. |
| `strategy_spread_lookback_d1` | 20 | 5-60 | D1 spread samples used for median spread filter. |
| `strategy_spread_median_mult` | 2.5 | 1.0-10.0 | Entry is blocked when current spread exceeds this multiple of median spread. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq 100 proxy for US large-cap momentum exposure.
- `WS30.DWX` - Dow 30 proxy for US large-cap momentum exposure.
- `SP500.DWX` - S&P 500 custom symbol proxy; valid for backtest registration with the standard T6 caveat.
- `GDAXI.DWX` - DAX 40 proxy for European country-index momentum exposure.
- `UK100.DWX` - FTSE 100 proxy for European country-index momentum exposure.

**Explicitly NOT for:**
- `FCHI.DWX` - Card frontmatter mentions FCHI, but it is not present in `framework/registry/dwx_symbol_matrix.csv`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Not canonical DWX symbols for the available S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | D1 ATR, D1 month-end close extraction across the registered basket |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `12` |
| Typical hold time | `About one month` |
| Expected drawdown profile | `Momentum rotation with fixed ATR catastrophe stops and monthly turnover.` |
| Regime preference | `Cross-sectional momentum in quarter-ending months.` |
| Win rate target (qualitative) | `Medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** `blog`
**Pointer:** `https://alphaarchitect.com/momentum-seasonality/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1641_aa-qend-mom-season.md`

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
| v1 | 2026-06-18 | Initial build from card | 1e38e441-7235-4b67-9fcc-48dd861e81df |

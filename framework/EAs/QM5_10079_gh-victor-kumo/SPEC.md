<!--
QuantMechanica V5 - EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_10079_gh-victor-kumo - Strategy Spec

**EA ID:** QM5_10079
**Slug:** `gh-victor-kumo`
**Source:** `3b3ec48a-0755-5187-9331-afb36e174175` (see `strategy-seeds/sources/3b3ec48a-0755-5187-9331-afb36e174175/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades D1 Ichimoku Kumo breakouts on the card's forex and metals symbols. It reads Tenkan 9, Kijun 26, and Senkou 52 through the framework Ichimoku helpers. A long entry fires when the Kumo is bullish on the two latest completed bars and the prior bar low was below the upper cloud boundary while the latest closed bar low is fully above it. A short entry is the mirror condition below the lower cloud boundary during a bearish Kumo. The EA exits a long when the developing bar low crosses below the opposite cloud boundary, exits a short when the developing bar high crosses above it, and places the initial stop 3% from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tenkan_period` | 9 | 1-200 | Ichimoku Tenkan-sen period |
| `strategy_kijun_period` | 26 | 1-200 | Ichimoku Kijun-sen period and cloud displacement |
| `strategy_senkou_b_period` | 52 | 1-300 | Ichimoku Senkou Span B period |
| `strategy_stop_percent` | 3.0 | >0 | Initial stop distance as a percent of entry price |

> Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; major forex pair with OHLC data suitable for D1 Ichimoku breakout.
- `GBPUSD.DWX` - card target; major forex pair with OHLC data suitable for D1 Ichimoku breakout.
- `USDJPY.DWX` - card target; major forex pair with OHLC data suitable for D1 Ichimoku breakout.
- `XAUUSD.DWX` - card target; metal CFD with OHLC data suitable for D1 Ichimoku breakout.

**Explicitly NOT for:**
- Index CFDs - not listed in the approved card's target symbol universe.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not valid for DWX backtests.

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
| Trades / year / symbol | 5 |
| Expected trade frequency | low-frequency D1 swing |
| Typical hold time | days to weeks |
| Expected drawdown profile | trend-following drawdowns during range-bound cloud churn |
| Regime preference | breakout / trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `3b3ec48a-0755-5187-9331-afb36e174175`
**Source type:** GitHub open-source EA
**Pointer:** Victor Algo, Ichimoku Kumo Break Out EA, GitHub path `victor-algo/channel/LIVE BOT - Creation de trading bot from scratch/Ichimoku Kumo Break Out/Expert/IchimokuKumoBO.mq5`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10079_gh-victor-kumo.md`

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
| v1 | 2026-06-20 | Initial build from card | d2837616-f2f3-4bed-849f-5d8b4c448245 |

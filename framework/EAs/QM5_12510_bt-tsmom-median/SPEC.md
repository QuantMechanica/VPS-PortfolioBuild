# QM5_12510_bt-tsmom-median — Strategy Spec

**EA ID:** QM5_12510
**Slug:** `bt-tsmom-median`
**Source:** `2d7aaa5f-321c-524b-99ce-bc921cddfc60` (see `strategy-seeds/sources/2d7aaa5f-321c-524b-99ce-bc921cddfc60/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

Enter long at the open of the next D1 bar when the prior completed D1 close is strictly above the 252-bar rolling median of D1 closes, where the median window is shifted one bar so the current close never appears inside the median computation. Close the long at the next D1 bar open when the prior close falls to or below that lagged median. An emergency stop is placed 3.5 × ATR(20, D1) below entry; the signal exit is the primary closing mechanism. No short entries. A 270-bar warmup period is required before the first trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_median_period` | 252 | 63–504 | Rolling-median lookback in D1 bars (≈12 months at default) |
| `strategy_warmup_bars` | 270 | 253–504 | Minimum completed D1 bars before first trade is allowed |
| `strategy_atr_period` | 20 | 10–50 | ATR period used for the emergency stop distance |
| `strategy_stop_atr_mult` | 3.5 | 2.0–6.0 | Emergency stop = multiplier × ATR(period, D1) below entry |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX with long D1 history; trend-following edge documented in source basket
- `GBPUSD.DWX` — liquid major FX; analogous trend characteristics to EURUSD
- `USDJPY.DWX` — liquid major FX with well-documented carry-and-trend regimes
- `AUDUSD.DWX` — commodity-linked major FX; trend-following historically positive
- `XAUUSD.DWX` — gold; strong trend-following history, used in source bt basket
- `GDAXI.DWX` — DAX 40 index (ported from card's GER40.DWX which is not in dwx_symbol_matrix; GDAXI is the canonical DWX DAX symbol)
- `NDX.DWX` — Nasdaq 100; US large-cap growth index with strong trend momentum
- `WS30.DWX` — Dow 30; US large-cap index complementing NDX in diversified basket

**Explicitly NOT for:**
- `GER40.DWX` — not present in dwx_symbol_matrix; ported to GDAXI.DWX (see open_questions in build artifact)
- `SP500.DWX` — card does not list SP500 in primary basket; excluded from P2 baseline

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` (default, PERIOD_CURRENT = D1) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~8 (card: 4–12 conservative estimate) |
| Typical hold time | Weeks to months (slow trend-following, median filter has ~1-month lag) |
| Expected drawdown profile | Shallow extended drawdowns during sideways regimes; deep infrequent drawdowns during sharp trend reversals |
| Regime preference | trend |
| Win rate target (qualitative) | low–medium (asymmetric returns, few large winners) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `2d7aaa5f-321c-524b-99ce-bc921cddfc60`
**Source type:** forum/repository
**Pointer:** https://github.com/pmorissette/bt — `docs/source/Trend_1.rst`, Trend Example 1, commit `2630651f212c025f0cec351d6319ad81d587ad6e`
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_12510_bt-tsmom-median.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | dffaa4a4-53bd-4e6a-bc32-263ebcc0ca18 |

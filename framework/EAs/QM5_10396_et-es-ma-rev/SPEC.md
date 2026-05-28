# QM5_10396_et-es-ma-rev — Strategy Spec

**EA ID:** QM5_10396
**Slug:** `et-es-ma-rev`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades an M30 index moving-average reversal system. A long entry is opened on the next eligible bar after the last completed close crosses above SMA(63). A short entry is opened on the next eligible bar after the last completed close crosses below SMA(6). If an opposite signal appears while a position is open, the EA closes the current position and suppresses the immediate same-bar replacement entry so any new opposite entry can occur on a later bar.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_long_sma_period` | 63 | 50-75 | SMA period used for close-cross-above long signals. |
| `strategy_short_sma_period` | 6 | 5-10 | SMA period used for close-cross-below short signals. |
| `strategy_atr_period` | 20 | 1-100 | ATR period used to size the initial stop. |
| `strategy_atr_sl_mult` | 2.0 | 1.5-2.5 | ATR multiple for the initial stop loss. |
| `strategy_session_filter_enabled` | true | true/false | Enables the regular-session entry/exit time filter. |
| `strategy_session_trade_start_hhmm` | 1700 | 0000-2359 | Broker-time session start after skipping the first 30 minutes of ES regular trading. |
| `strategy_session_end_hhmm` | 2300 | 0000-2359 | Broker-time session end for regular-session index trading. |
| `strategy_max_spread_stop_frac` | 0.10 | 0.00-1.00 | Blocks entries when spread exceeds this fraction of stop distance. |
| `strategy_max_spread_points` | 0 | 0-10000 | Optional absolute spread cap in points; 0 disables this cap. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — direct S&P 500 custom-symbol port for ES/SPX-style index exposure.
- `NDX.DWX` — liquid US large-cap index analogue for Nasdaq 100 exposure.
- `WS30.DWX` — liquid US large-cap index analogue for Dow 30 exposure.
- `GDAXI.DWX` — available DWX DAX custom symbol used as the matrix-valid port for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `framework/registry/dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` — not canonical available DWX symbols for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Several M30 bars to multiple sessions, until the opposite SMA reversal or stop. |
| Expected drawdown profile | Low-to-medium cadence trend-following whipsaw risk from asymmetric moving averages. |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `jboydston, Mechanical ES system, Elite Trader, 2003-04-09, https://www.elitetrader.com/et/threads/mechanical-es-system.16095/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10396_et-es-ma-rev.md`

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
| v1 | 2026-05-25 | Initial build from card | 5f0e1c9b-5dfb-40e5-87ca-8511d4f96b0f |

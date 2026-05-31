# QM5_10497_mql5-3sma — Strategy Spec

**EA ID:** QM5_10497
**Slug:** mql5-3sma
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades a three-SMA stack on the completed M15 bar. It opens long when SMA(10) is above SMA(30) by 0.10 ATR(14) and SMA(30) is above SMA(60) by the same spread; it opens short when the stack is reversed by the same spread. It exits a long when SMA(10) falls below SMA(30) plus half the entry spread, exits a short when SMA(10) rises above SMA(30) minus half the entry spread, or exits either side after 96 M15 bars. Protective exits use a 1.5 ATR(14) stop and a 2.0R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_fast_period` | 10 | integer > 0 | Fast SMA period used as SMA1. |
| `strategy_sma_mid_period` | 30 | integer > 0 | Middle SMA period used as SMA2. |
| `strategy_sma_slow_period` | 60 | integer > 0 | Slow SMA period used as SMA3. |
| `strategy_atr_period` | 14 | integer > 0 | ATR period for spread, minimum-volatility filter, and stop distance. |
| `strategy_ma_spread_atr_mult` | 0.10 | double > 0 | Required SMA separation as a multiple of ATR(14). |
| `strategy_exit_spread_factor` | 0.50 | double >= 0 | Exit threshold as a fraction of the entry spread. |
| `strategy_atr_sl_mult` | 1.50 | double > 0 | Protective stop distance as an ATR multiple. |
| `strategy_rr_target` | 2.00 | double > 0 | Take-profit reward/risk multiple. |
| `strategy_time_stop_bars` | 96 | integer >= 0 | Maximum hold measured in M15 bars; 0 disables the time stop. |
| `strategy_min_atr_points` | 1.0 | double >= 0 | Minimum ATR in points required before entries are allowed. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card R3 primary P2 basket member; liquid FX major with OHLC-derived SMA portability.
- `GBPUSD.DWX` — card R3 primary P2 basket member; liquid FX major with OHLC-derived SMA portability.
- `USDJPY.DWX` — card R3 primary P2 basket member; liquid FX major with OHLC-derived SMA portability.
- `XAUUSD.DWX` — card R3 primary P2 basket member; liquid metal CFD with OHLC-derived SMA portability.

**Explicitly NOT for:**
- Non-DWX symbols — V5 research and backtest symbols must use the canonical `.DWX` matrix names.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — they are not available for the DWX backtest pipeline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | up to 96 M15 bars, with earlier stack-decay exits |
| Expected drawdown profile | trend-following losses during flat or choppy SMA-stack regimes |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/21495 and `artifacts/cards_approved/QM5_10497_mql5-3sma.md`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10497_mql5-3sma.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-05-28 | Initial build from card | caaefa36-c001-4aa4-97a6-e944f9bcd871 |

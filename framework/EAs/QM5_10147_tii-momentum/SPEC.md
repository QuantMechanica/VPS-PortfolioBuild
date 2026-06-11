# QM5_10147_tii-momentum - Strategy Spec

**EA ID:** QM5_10147
**Slug:** `tii-momentum`
**Source:** `d3c009d7-a8d6-5251-b572-4777b207c2b9` (see `strategy-seeds/sources/d3c009d7-a8d6-5251-b572-4777b207c2b9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA calculates Trend Intensity Index from close prices against a simple moving average over the selected period. It enters long when TII crosses upward through the centerline and enters short, when enabled, when TII crosses downward through the centerline. A long exits after TII first moves above the upper level and then crosses back below it; before that upper-level move, a long exits if TII returns to or below the centerline. A short mirrors the same rule around the lower level and centerline.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_tii_period` | 60 | 30-90 in P3 card sweep | SMA and TII lookback period. |
| `strategy_tii_centerline` | 50.0 | 45.0-55.0 in P3 card sweep | Centerline crossed for entry and fallback exit. |
| `strategy_tii_upper` | 80.0 | 70.0-90.0 in P3 card sweep | Long extreme level that arms pullback exit. |
| `strategy_tii_lower` | 20.0 | 10.0-30.0 in P3 card sweep | Short extreme level that arms pullback exit. |
| `strategy_shorts_enabled` | true | true/false | Enables the optional mirrored short mode from the card. |
| `strategy_atr_period` | 14 | fixed research default | ATR period for the emergency stop. |
| `strategy_atr_stop_mult` | 3.0 | 2.0-4.0 in P3 card sweep | ATR multiple for emergency stop distance. |
| `strategy_max_spread_atr_frac` | 0.05 | >=0.0 | Blocks new trading when current spread exceeds this fraction of ATR. |

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `AUDCHF.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `AUDJPY.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `AUDNZD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `AUDUSD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `CADCHF.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `CADJPY.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `CHFJPY.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `EURAUD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `EURCAD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `EURCHF.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `EURGBP.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `EURJPY.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `EURNZD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `EURUSD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `GBPAUD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `GBPCAD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `GBPCHF.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `GBPJPY.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `GBPNZD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `GBPUSD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `GDAXI.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `NDX.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `NZDCAD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `NZDCHF.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `NZDJPY.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `NZDUSD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `SP500.DWX` - OHLC close data supports the symbol-agnostic TII rule; backtest-only per DWX discipline.
- `UK100.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `USDCAD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `USDCHF.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `USDJPY.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `WS30.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `XAGUSD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `XAUUSD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `XNGUSD.DWX` - OHLC close data supports the symbol-agnostic TII rule.
- `XTIUSD.DWX` - OHLC close data supports the symbol-agnostic TII rule.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not broker/custom-symbol validated for this build.

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
| Trades / year / symbol | `10` |
| Typical hold time | days to weeks |
| Expected drawdown profile | Momentum sleeve with ATR emergency stop and centerline fallback exits. |
| Regime preference | trend-following / momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d3c009d7-a8d6-5251-b572-4777b207c2b9`
**Source type:** `article`
**Pointer:** `https://raposa.trade/blog/4-ways-to-trade-the-trend-intensity-indicator/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10147_tii-momentum.md`

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
| v1 | 2026-06-12 | Initial build from card | cb948bde-5e53-4d2b-a04f-600aa69ae6ef |

# QM5_10539_mql5-stoch-chaik - Strategy Spec

**EA ID:** QM5_10539
**Slug:** `mql5-stoch-chaik`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA evaluates closed H12 bars and builds a Stochastic Chaikin volatility cloud from the bar high-low range. A long signal occurs when the cloud value turns upward after being flat or falling, and a short signal occurs when the cloud value turns downward after being flat or rising. Entries use market orders with an ATR hard stop and a fixed 2R target. An opposite cloud color change is used as the discretionary strategy exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_smooth_period` | 10 | 1+ | First smoothing period applied to high-low range. |
| `strategy_stoch_length` | 5 | 2+ | Lookback for stochastic normalization of smoothed range. |
| `strategy_signal_smooth_period` | 5 | 1+ | Final smoothing period for the cloud value. |
| `strategy_atr_period` | 14 | 1+ | ATR lookback for the hard stop. |
| `strategy_atr_sl_mult` | 2.0 | 1.5 / 2.0 / 3.0 sweep | Stop distance in ATR multiples. |
| `strategy_tp_rr` | 2.0 | 0.1+ | Fixed reward/risk target multiple. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - source test instrument and liquid FX baseline.
- `GBPUSD.DWX` - liquid FX major for the same OHLC volatility signal.
- `XAUUSD.DWX` - liquid metal symbol from the approved R3 basket.
- `GDAXI.DWX` - available DAX custom symbol used as the matrix-valid port for card-stated `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H12` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | hours to days, bounded by opposite cloud change, SL, TP, or Friday close |
| Expected drawdown profile | volatility-expansion signal with ATR-defined per-trade loss |
| Regime preference | volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/18040`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10539_mql5-stoch-chaik.md`

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
| v1 | 2026-05-29 | Initial build from card | d72d89f6-3ae0-4d13-b2e7-ca286440d3e8 |

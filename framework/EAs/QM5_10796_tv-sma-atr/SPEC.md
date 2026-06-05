# QM5_10796_tv-sma-atr - Strategy Spec

**EA ID:** QM5_10796
**Slug:** `tv-sma-atr`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA evaluates a fast and slow simple moving average on the closed bar. It opens long when SMA(15) crosses above SMA(45), and opens short when SMA(15) crosses below SMA(45). On entry it sets a static hard stop at 2.0 times ATR(14) from the entry price. When enabled, it closes an open position on the opposite closed-bar SMA crossover.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_sma_period` | 15 | 10-20 | Fast SMA period used for crossover entry. |
| `strategy_slow_sma_period` | 45 | 40-60 | Slow SMA period used for crossover entry. |
| `strategy_atr_period` | 14 | 14-20 | ATR period used to size the static stop. |
| `strategy_atr_stop_multiplier` | 2.0 | 1.5-2.5 | Multiplier applied to ATR for stop distance. |
| `strategy_opposite_cross_exit` | true | true or false | Close on the opposite SMA crossover when true. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair with native DWX history and SMA/ATR data.
- `GBPUSD.DWX` - liquid major FX pair with native DWX history and SMA/ATR data.
- `USDJPY.DWX` - liquid major FX pair with native DWX history and SMA/ATR data.
- `XAUUSD.DWX` - canonical DWX gold symbol for the card's XAUUSD target.
- `GDAXI.DWX` - canonical DWX DAX proxy used because `GER40.DWX` is not in the DWX matrix.
- `NDX.DWX` - liquid US large-cap index CFD available in the DWX matrix.
- `WS30.DWX` - liquid US large-cap index CFD available in the DWX matrix.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated name is not present in `dwx_symbol_matrix.csv`; this build uses `GDAXI.DWX`.
- `XAUUSD` - unsuffixed broker symbol is normalized to `XAUUSD.DWX` for backtest registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30, H1, H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 60 |
| Expected trade frequency | not specified in card frontmatter |
| Typical hold time | not specified in card frontmatter; trades persist until fixed ATR stop, opposite crossover, or Friday close |
| Expected drawdown profile | whipsaw risk in range-bound regimes |
| Regime preference | trend-following |
| Win rate target qualitative | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy script
**Pointer:** `https://www.tradingview.com/script/IPOHOSd1-atr-stop-loss-for-double-SMA-v6/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10796_tv-sma-atr.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-05 | Initial build from card | cad3b502-bf75-4ddd-8a44-f69fdc63af2b |

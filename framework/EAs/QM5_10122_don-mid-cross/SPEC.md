# QM5_10122_don-mid-cross - Strategy Spec

**EA ID:** QM5_10122
**Slug:** don-mid-cross
**Source:** d3c009d7-a8d6-5251-b572-4777b207c2b9 (see `sources/raposa-trade-python-backtesting`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA calculates a Donchian channel on completed D1 bars using the highest high and lowest low over the configured lookback. The middle value is `(upper + lower) / 2`. On the next bar it enters long when the previous completed close is above that middle value. If short mode is enabled, it enters short when the previous completed close is below the middle value; otherwise a close below the middle value is used only to exit an existing long. The emergency stop is an ATR stop using `strategy_atr_stop_mult * ATR(strategy_atr_period)`.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_donchian_period` | 20 | 10-60 tested by card | Donchian channel lookback in completed D1 bars. |
| `strategy_shorts_enabled` | false | false/true | Enables short entries and reversal behaviour when close is below the Donchian middle value. |
| `strategy_entry_on_close` | true | true | Preserves the card's completed-bar signal with next-bar execution. |
| `strategy_atr_period` | 14 | fixed research default | ATR period for the emergency stop. |
| `strategy_atr_stop_mult` | 3.0 | 2.0-4.0 tested by card | ATR multiplier for emergency stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `AUDCAD.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `AUDCHF.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `AUDJPY.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `AUDNZD.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `AUDUSD.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `CADCHF.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `CADJPY.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `CHFJPY.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `EURAUD.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `EURCAD.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `EURCHF.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `EURGBP.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `EURJPY.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `EURNZD.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `EURUSD.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `GBPAUD.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `GBPCAD.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `GBPCHF.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `GBPJPY.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `GBPNZD.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `GBPUSD.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `GDAXI.DWX` - verified DWX index symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `NDX.DWX` - verified DWX index symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `NZDCAD.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `NZDCHF.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `NZDJPY.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `NZDUSD.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `SP500.DWX` - verified DWX index custom symbol; valid for backtest, with live T6 routing restriction handled downstream.
- `UK100.DWX` - verified DWX index symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `USDCAD.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `USDCHF.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `USDJPY.DWX` - verified DWX forex symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `WS30.DWX` - verified DWX index symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `XAGUSD.DWX` - verified DWX metals symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `XAUUSD.DWX` - verified DWX metals symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `XNGUSD.DWX` - verified DWX energy symbol; card states OHLC-only logic is portable to liquid DWX symbols.
- `XTIUSD.DWX` - verified DWX energy symbol; card states OHLC-only logic is portable to liquid DWX symbols.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must use verified `.DWX` names from `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 20 |
| Typical hold time | days, until opposite Donchian middle-value close or emergency stop |
| Expected drawdown profile | trend-following whipsaw risk around the Donchian middle value |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d3c009d7-a8d6-5251-b572-4777b207c2b9
**Source type:** blog/tutorial
**Pointer:** https://raposa.trade/blog/three-strategies-for-trading-the-donchian-channel-in-python/ and approved card `artifacts/cards_approved/QM5_10122_don-mid-cross.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10122_don-mid-cross.md`

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
| v1 | 2026-06-12 | Initial build from card | 736b7779-e11a-47f5-b758-a0486b4e05e3 |

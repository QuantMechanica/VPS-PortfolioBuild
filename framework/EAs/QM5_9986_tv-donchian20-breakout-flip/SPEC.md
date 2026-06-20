# QM5_9986_tv-donchian20-breakout-flip - Strategy Spec

**EA ID:** QM5_9986
**Slug:** tv-donchian20-breakout-flip
**Source:** 30591366-874b-5bee-b47c-da2fca20b728 (see `sources/tradingview-popular-pine-scripts`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

On each H1 close, the EA checks whether the just-closed candle closed above the highest high of the prior 20 closed H1 bars or below the lowest low of those prior 20 bars. A long signal opens at the next H1 bar when the close breaks above the channel; a short signal opens when the close breaks below the channel. If the opposite breakout appears while a position is open, the EA closes the current position and submits the reverse entry in the same new-bar handler. Initial SL and TP are placed as ATR multiples to translate the source instrument's point-based defaults onto DWX symbols.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_donchian_period` | 20 | 15-30 P3 sweep candidate | Prior closed H1 bars used for the Donchian high/low channel. |
| `strategy_use_sma_filter` | false | true/false | Enables the optional SMA trend filter from the card. |
| `strategy_sma_period` | 200 | 100-300 P3 sweep candidate | SMA period used when the optional trend filter is enabled. |
| `strategy_atr_period` | 14 | >=1 | ATR period for DWX SL/TP translation. |
| `strategy_atr_sl_mult` | 1.0 | 1.0-2.0 P3 sweep candidate | Initial stop distance in ATR multiples. |
| `strategy_atr_tp_mult` | 2.0 | 1.5-4.0 P3 sweep candidate | Static take-profit distance in ATR multiples. |
| `strategy_use_flat_range_filter` | false | true/false | Enables the optional Donchian-width chop filter. |
| `strategy_flat_atr_mult` | 0.5 | 0.5-0.7 P3 sweep candidate | Blocks entries when channel width is below this multiple of ATR scaled by `sqrt(strategy_donchian_period)`. |
| `strategy_use_session_filter` | false | true/false | Enables the optional broker-time session filter. |
| `strategy_session_start_hour` | 0 | 0-23 | Broker-time session start hour when the session filter is enabled. |
| `strategy_session_end_hour` | 24 | 1-24 | Broker-time session end hour when the session filter is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major listed in the card's target basket.
- `GBPUSD.DWX` - FX major listed in the card's target basket.
- `USDJPY.DWX` - FX major listed in the card's target basket.
- `XAUUSD.DWX` - Gold CFD listed in the card's target basket.
- `XTIUSD.DWX` - Oil CFD listed in the card's target basket.
- `NDX.DWX` - Nasdaq 100 index CFD listed in the card's target basket.
- `WS30.DWX` - Dow 30 index CFD listed in the card's target basket.
- `SP500.DWX` - S&P 500 custom symbol listed as supplementary backtest coverage.

**Explicitly NOT for:**
- `VN30F1M` - Source instrument is not available in the DWX symbol matrix.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Not canonical DWX S&P 500 symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Several H1 bars to several days; no card time stop |
| Expected drawdown profile | Trend-breakout whipsaw risk in flat ranges, bounded by initial ATR SL |
| Regime preference | Breakout / volatility expansion |
| Win rate target (qualitative) | Medium-low with larger TP than SL |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView script
**Pointer:** https://www.tradingview.com/script/N51L77rX-PSOL-01-Donchian-Channels/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9986_tv-donchian20-breakout-flip.md`

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
| v1 | 2026-06-20 | Initial build from card | 17192dec-9524-4108-9402-2d26a276da34 |

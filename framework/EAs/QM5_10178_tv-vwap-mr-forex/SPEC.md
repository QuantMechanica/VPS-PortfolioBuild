# QM5_10178_tv-vwap-mr-forex - Strategy Spec

**EA ID:** QM5_10178
**Slug:** `tv-vwap-mr-forex`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see TradingView script pointer in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades range-bound forex mean reversion on M15 bars. It computes a 20-bar rolling VWAP from typical price weighted by tick volume, then builds volume-weighted absolute-deviation bands around that VWAP. A long entry fires when the last closed bar crosses below the lower band with RSI(14) at or below 30, ADX(14) at or below 25, and no tick-volume spike; shorts mirror the rule above the upper band with RSI at or above 70. Positions exit when price returns to VWAP, when the 24-bar time stop expires, or when the fixed protective stop is hit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_CURRENT` | M15 or M30 intended | Signal timeframe, with setfiles using M15 as the primary card timeframe. |
| `strategy_vwap_period` | `20` | 2-100 | Rolling lookback for VWAP and deviation bands. |
| `strategy_band_deviation_mult` | `2.0` | 0.5-4.0 | Multiplier applied to the VWAP absolute-deviation band. |
| `strategy_rsi_period` | `14` | 2-50 | RSI lookback on the signal timeframe. |
| `strategy_rsi_long_level` | `30.0` | 5-50 | Maximum RSI value for long entries. |
| `strategy_rsi_short_level` | `70.0` | 50-95 | Minimum RSI value for short entries. |
| `strategy_volume_sma_period` | `20` | 2-100 | Tick-volume SMA lookback for spike filtering. |
| `strategy_volume_spike_mult` | `2.0` | 1.0-5.0 | Blocks entries when closed-bar tick volume exceeds this multiple of its SMA. |
| `strategy_adx_period` | `14` | 2-50 | ADX lookback for range-regime filtering. |
| `strategy_adx_max` | `25.0` | 5-40 | Maximum ADX allowed for new mean-reversion entries. |
| `strategy_atr_period` | `14` | 2-50 | ATR lookback for stop-distance capping. |
| `strategy_atr_stop_mult` | `1.5` | 0.5-5.0 | ATR multiple used as the maximum protective stop distance. |
| `strategy_percent_stop` | `0.75` | 0.1-5.0 | Fixed percent adverse-move stop candidate. |
| `strategy_max_spread_stop_fraction` | `0.15` | 0.0-0.5 | Blocks genuinely wide spreads relative to stop distance. |
| `strategy_time_stop_bars` | `24` | 1-200 | Maximum holding period in signal bars. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major liquid forex pair named by the approved card.
- `GBPUSD.DWX` - major liquid forex pair named by the approved card.
- `USDJPY.DWX` - major liquid forex pair named by the approved card.
- `EURGBP.DWX` - liquid forex cross named by the approved card.

**Explicitly NOT for:**
- `XAUUSD.DWX` - metal volatility and session behavior are outside the forex VWAP source premise.
- `NDX.DWX` - index microstructure is outside the card's range-bound forex universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | intraday, up to 24 M15 bars |
| Expected drawdown profile | Mean-reversion stop losses cluster during trend breakouts; ADX and volume-spike filters are intended to reduce trend-regime exposure. |
| Regime preference | range-bound mean reversion |
| Win rate target (qualitative) | medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** `https://www.tradingview.com/script/9SEB7IHb-VWAP-Mean-Reversion-Strategy-Range-Bound-Forex-RSI-Volume/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10178_tv-vwap-mr-forex.md`

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
| v1 | 2026-06-26 | Initial build-spec completion from approved card | build task 66b8bb49 |

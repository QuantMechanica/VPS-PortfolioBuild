# QM5_10815_tv-post-vwap — Strategy Spec

**EA ID:** QM5_10815
**Slug:** `tv-post-vwap`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see TradingView source citation in the approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

The EA trades a closed-bar reversal after a high-volume absorption bar around session VWAP. A long setup requires the absorption bar to stretch below VWAP by at least the configured ATR fraction, print a lower wick with high relative tick volume, close back inside the prior bar range, and then have the next closed bar reclaim the absorption high. A short setup mirrors the rule above VWAP with an upper wick and breakdown below the absorption low. The stop is placed beyond the absorption swing by an ATR buffer and capped at a maximum ATR distance; the default target is session VWAP, with optional fixed-R target variants.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | >=1 | ATR period used for stretch, stop buffer, and maximum stop cap. |
| `strategy_volume_lookback` | 20 | >=3 | Closed-bar lookback used to compute average tick volume. |
| `strategy_vwap_stretch_atr` | 0.50 | >0 | Minimum VWAP stretch in ATR units for the absorption bar. |
| `strategy_volume_ratio` | 1.50 | >0 | Minimum absorption-bar volume relative to the lookback average. |
| `strategy_wick_share` | 0.55 | 0.0-1.0 | Minimum wick share of the absorption bar range. |
| `strategy_stop_buffer_atr` | 0.25 | >=0 | ATR buffer beyond the absorption swing for stop placement. |
| `strategy_max_stop_atr` | 2.50 | >0 | Maximum permitted stop distance in ATR units. |
| `strategy_target_rr` | 0.0 | >=0 | Fixed-R target when >0; 0 means target session VWAP. |
| `strategy_time_stop_m15_bars` | 24 | >=1 | M15 bar count for the time stop. |
| `strategy_time_stop_h1_bars` | 12 | >=1 | H1 bar count for the time stop. |
| `strategy_session_filter` | true | true/false | Enables the liquid-session time filter. |
| `strategy_session_start_hour` | 7 | 0-23 | Broker-hour start of the allowed trading window. |
| `strategy_session_end_hour` | 21 | 0-23 | Broker-hour end of the allowed trading window. |
| `strategy_max_spread_points` | 0 | >=0 | Optional spread cap; 0 disables the strategy-specific cap. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid FX major with tick volume, ATR, OHLC, and VWAP proxy availability.
- `GBPUSD.DWX` — liquid FX major with the same VWAP and volume inputs.
- `USDJPY.DWX` — liquid FX major suitable for intraday VWAP reversal testing.
- `XAUUSD.DWX` — liquid metal symbol with tick-volume and intraday reversal behaviour.
- `GDAXI.DWX` — available DAX proxy in the DWX matrix; used for the card's `GER40.DWX` target.
- `NDX.DWX` — liquid US large-cap index proxy for intraday VWAP reversals.
- `WS30.DWX` — liquid US large-cap index proxy for intraday VWAP reversals.

**Explicitly NOT for:**
- `GER40.DWX` — not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` and `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 70 |
| Typical hold time | up to 24 M15 bars or 12 H1 bars unless VWAP/SL/TP hits first |
| Expected drawdown profile | repeated small losses during strong trend days that continue away from VWAP |
| Regime preference | intraday mean-reversion after volume absorption |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView strategy page
**Pointer:** `https://www.tradingview.com/script/j6iKZmCf-Post-Absorption-VWAP-Reversal-Engine-V1-6/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10815_tv-post-vwap.md`

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
| v1 | 2026-06-05 | Initial build from card | 7cee81ec-0496-469d-aee2-117a5d80b015 |

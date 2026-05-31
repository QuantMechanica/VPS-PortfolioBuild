# QM5_10698_tv-liq-retest - Strategy Spec

**EA ID:** QM5_10698
**Slug:** `tv-liq-retest`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (TradingView open-source strategy)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA searches recent confirmed pivot lows as support and confirmed pivot highs as resistance. On each closed bar it selects the nearest support below the close or resistance above the close if that level is within `ATR * strategy_max_dist_atr`. A long entry requires the closed bar to wick through support, close back above it, and close bullish; a short entry requires the symmetric rejection at resistance. Exits are placed at fixed ATR SL/TP by default, with percent SL/TP available as a disabled-by-default card variant.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pivot_left` | 3 | >= 1 | Bars to the older side for confirming a pivot level. |
| `strategy_pivot_right` | 3 | >= 1 | Bars to the newer side for confirming a pivot level. |
| `strategy_max_levels` | 12 | >= 1 | Maximum recent support or resistance levels considered per side. |
| `strategy_scan_bars` | 180 | > left + right | Closed bars scanned for confirmed pivots. |
| `strategy_atr_period` | 14 | >= 1 | ATR period used for level distance, wick size, and ATR exits. |
| `strategy_max_dist_atr` | 1.0 | > 0 | Maximum distance from close to selected level in ATR units. |
| `strategy_min_wick_atr` | 0.10 | >= 0 | Minimum sweep wick beyond the selected level in ATR units. |
| `strategy_sl_atr_mult` | 1.0 | > 0 | ATR stop-loss multiplier when ATR exit mode is active. |
| `strategy_tp_atr_mult` | 1.0 | > 0 | ATR take-profit multiplier when ATR exit mode is active. |
| `strategy_percent_exit` | false | true/false | Use percent SL/TP instead of ATR SL/TP. |
| `strategy_percent_sl` | 0.50 | > 0 | Percent stop-loss distance when percent exit mode is active. |
| `strategy_percent_tp` | 0.50 | > 0 | Percent take-profit distance when percent exit mode is active. |
| `strategy_filter_ema` | false | true/false | Require EMA fast above slow for longs and below slow for shorts. |
| `strategy_ema_fast` | 20 | >= 1 | Fast EMA period for optional EMA filter. |
| `strategy_ema_slow` | 50 | > fast | Slow EMA period for optional EMA filter. |
| `strategy_filter_vwap` | false | true/false | Require close above/below a tick-volume VWAP-like series. |
| `strategy_vwap_bars` | 48 | >= 1 | Bars used in the VWAP-like tick-volume calculation. |
| `strategy_filter_volume` | false | true/false | Require closed-bar tick volume above SMA volume times multiplier. |
| `strategy_volume_sma_bars` | 20 | >= 1 | Tick-volume SMA lookback for optional volume filter. |
| `strategy_volume_mult` | 1.20 | > 0 | Tick-volume multiplier for optional volume filter. |
| `strategy_max_spread_points` | 0 | >= 0 | Optional spread gate in points; 0 disables it. |
| `strategy_session_enabled` | false | true/false | Optional broker-hour session gate. |
| `strategy_session_start_h` | 0 | 0-23 | Broker session start hour if session gate is enabled. |
| `strategy_session_end_h` | 24 | 0-24 | Broker session end hour if session gate is enabled. |
| `strategy_session_flat` | false | true/false | Close open positions outside the optional session. |
| `strategy_trailing_enabled` | false | true/false | Enable optional ATR trailing stop variant. |
| `strategy_trail_atr_mult` | 1.0 | > 0 | ATR trailing multiplier if trailing is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major from the card's R3 basket.
- `GBPUSD.DWX` - liquid FX major from the card's R3 basket.
- `USDJPY.DWX` - liquid FX major from the card's R3 basket.
- `XAUUSD.DWX` - canonical DWX gold symbol for the card's `XAUUSD` target.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's unavailable `GER40.DWX` name.
- `NDX.DWX` - liquid Nasdaq index from the card's R3 basket.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no DWX tick data contract.
- `GER40.DWX` - not present in the DWX matrix; DAX exposure is represented by `GDAXI.DWX`.
- `XAUUSD` without `.DWX` - research/backtest symbols keep the `.DWX` suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5 / M15 / M30` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 140 |
| Typical hold time | not specified in frontmatter; expected intraday to short swing because exits are static SL/TP |
| Expected drawdown profile | moderate cadence level-retest reversal with stale-level and large-sweep-candle risk |
| Regime preference | mean-revert liquidity-sweep rejection |
| Win rate target (qualitative) | not specified in frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/GjkwcL4B/`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10698_tv-liq-retest.md`

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
| v1 | 2026-05-31 | Initial build from card | 013fe930-f350-4c47-8592-afc178733f73 |

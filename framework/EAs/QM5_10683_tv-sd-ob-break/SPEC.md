# QM5_10683_tv-sd-ob-break - Strategy Spec

**EA ID:** QM5_10683
**Slug:** tv-sd-ob-break
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

This EA trades the long-only P2 baseline from the approved TradingView supply-demand/order-block card. On each closed H1 or M15 bar, it looks for a recent bearish demand/order-block candle followed by bullish displacement, then enters long when the latest close breaks above that zone. The breakout must also close above EMA(50), show a tick-volume spike, and have bullish MACD-style momentum. The initial stop is below the detected zone low plus a 0.25 ATR buffer, the deterministic target is 2.0R, and open long trades use ATR trailing while profitable.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ema_period | 50 | >=1 | EMA trend filter period. |
| strategy_atr_period | 14 | >=1 | ATR period for displacement, stop buffer, and trailing. |
| strategy_macd_fast | 12 | >=1 | Fast EMA period for MACD momentum. |
| strategy_macd_slow | 26 | > fast | Slow EMA period for MACD momentum. |
| strategy_macd_signal | 9 | >=1 | MACD signal smoothing period. |
| strategy_zone_lookback_bars | 40 | >=6 | Maximum bars scanned for a valid demand/order-block zone. |
| strategy_bullish_sequence_bars | 2 | >=1 | Consecutive bullish candles required after the bearish order-block candle. |
| strategy_impulse_atr_mult | 0.75 | >0 | Minimum bullish displacement after the order block, measured in ATR. |
| strategy_volume_lookback_bars | 20 | >=1 | Tick-volume average lookback for the volume-spike filter. |
| strategy_volume_spike_mult | 1.20 | >=1.0 | Current closed-bar tick volume must exceed average volume by this multiple. |
| strategy_sl_atr_buffer_mult | 0.25 | >0 | ATR buffer below the zone low for the initial stop. |
| strategy_rr_target | 2.00 | >0 | Fixed take-profit multiple of initial risk. |
| strategy_trail_atr_mult | 2.00 | >0 | ATR multiple for trailing stop management. |
| strategy_max_spread_points | 0 | >=0 | Optional spread guard in points; 0 disables it because the card did not specify a spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- XAUUSD.DWX - Card names XAUUSD; metal CFD with DWX tick-volume proxy.
- EURUSD.DWX - Card names EURUSD; liquid FX baseline symbol.
- GBPUSD.DWX - Card names GBPUSD; liquid FX baseline symbol.
- NDX.DWX - Card names NDX; liquid index CFD baseline symbol.
- GDAXI.DWX - DAX equivalent in the DWX matrix for the card's GER40.DWX basket item.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; use GDAXI.DWX.
- SP500.DWX - Not part of this card's R3 primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | intraday to multi-day, depending on 2R target or ATR trailing stop |
| Expected drawdown profile | Breakout strategy drawdowns during failed zone breaks and low-participation regimes. |
| Regime preference | volatility-expansion breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/lQ5zIOGa-Supply-Demand-Zones-Order-Block-Pro-Fusion-Auto-Order/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10683_tv-sd-ob-break.md`

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
| v1 | 2026-06-14 | Initial build from card | 7e09541d-dad8-4cc1-a416-216a1a0269ee |

# QM5_10847_tv-inside-gem - Strategy Spec

**EA ID:** QM5_10847
**Slug:** `tv-inside-gem`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades confirmed breakouts from an inside-bar compression pattern on H1. It looks for a mother bar followed by one or more inside bars, requires either at least two inside bars or one inside bar with a midpoint sweep, then enters on the next bar after the close breaks above or below the mother-bar range. A fixed score gate combines duration, directional inside-bar closes, midpoint sweep, 4H and 1H candle alignment, RSI alignment, RSI divergence penalty, and breakout-bar close quality. Exits are handled by the initial stop outside the opposite side of the mother-bar structure with a 0.25 ATR(14) buffer, fixed 2.0R take profit, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_min_score` | 5 | 1-20 | Minimum fixed breakout-quality score required for entry. |
| `strategy_min_inside_bars` | 2 | 1-8 | Minimum inside bars required unless one-bar sweep mode qualifies. |
| `strategy_allow_one_inside_sweep` | true | true/false | Allows one inside bar when it sweeps the mother-bar midpoint. |
| `strategy_max_inside_bars` | 8 | 1-12 | Maximum bounded inside-bar sequence scanned per new bar. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the structure-stop buffer. |
| `strategy_atr_buffer_mult` | 0.25 | 0.01-2.00 | ATR multiplier added beyond the opposite mother-bar side. |
| `strategy_rr_target` | 2.0 | 0.5-5.0 | Take-profit distance as R multiple of stop distance. |
| `strategy_rsi_period` | 14 | 2-100 | RSI period used for alignment and divergence score components. |
| `strategy_bo_quality_threshold` | 0.70 | 0.10-1.00 | Breakout close-location threshold for the score multiplier. |
| `strategy_session_start_hour` | 9 | 0-23 | Broker-hour start for the trading session. |
| `strategy_session_end_hour` | 23 | 0-23 | Broker-hour end for the trading session. |
| `strategy_patron_tf` | PERIOD_H4 | M30-H4 | Higher timeframe candle used for MTF conflict blocking. |
| `strategy_manager_tf` | PERIOD_H1 | M30-H4 | Manager timeframe candle used for MTF conflict blocking. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with deep H1 OHLC history and liquid breakout structure.
- `GBPUSD.DWX` - FX major named in the R3 portable basket.
- `XAUUSD.DWX` - Gold CFD named in the R3 portable basket and suitable for volatility compression breakouts.
- `GDAXI.DWX` - DAX custom symbol available in `dwx_symbol_matrix.csv`; used as the canonical available port for the card's `GER40.DWX` target.
- `NDX.DWX` - Nasdaq 100 index CFD named in the R3 portable basket.

**Explicitly NOT for:**
- `GER40.DWX` - Card-stated DAX symbol is not present in `dwx_symbol_matrix.csv`; registration uses `GDAXI.DWX` instead.
- `SP500.DWX` - Mentioned only as a possible later test target, not part of the card's primary P2 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | H4 patron candle direction, H1 manager candle direction |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Not specified in card frontmatter; expected hours to days from H1 breakout with 2R target. |
| Expected drawdown profile | Not specified in card frontmatter; compression breakout with fixed SL and no averaging. |
| Regime preference | Volatility-expansion breakout. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** TradingView script `Inside Gem (pxeo) - V8.19 Strategy`, author handle `PIXEO`, Apr 24, https://www.tradingview.com/script/kq3f7SfA/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10847_tv-inside-gem.md`

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
| v1 | 2026-06-06 | Initial build from card | bb3fcb15-7840-4433-8950-5edde0c8d175 |

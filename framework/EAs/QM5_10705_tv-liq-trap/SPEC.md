# QM5_10705_tv-liq-trap - Strategy Spec

**EA ID:** QM5_10705
**Slug:** tv-liq-trap
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-04

---

## 1. Strategy Logic

The EA trades failed breaks of the previous daily high and previous daily low. A short setup occurs when the last closed intraday bar trades above the previous daily high and closes back below it. A long setup occurs when the last closed intraday bar trades below the previous daily low and closes back above it. Stops are placed beyond the trap candle extreme by an ATR buffer, and take profit is placed at a fixed R multiple from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 1+ | ATR lookback for stop buffer. |
| `strategy_atr_buffer_mult` | 1.0 | 0.5+ tested | ATR multiplier added beyond the trap candle extreme. |
| `strategy_min_atr_buffer_mult` | 0.5 | 0.5+ | Floor that prevents reducing the stop below the tested ATR buffer floor. |
| `strategy_rr_target` | 2.0 | 1.5-2.5 tested | Take-profit distance in R from entry. |
| `strategy_trade_start_hour` | 0 | 0-23 | Broker-hour start for optional session filtering. |
| `strategy_trade_end_hour` | 24 | 0-24 | Broker-hour end for optional session filtering; start=end means all day. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread cap in points; 0 disables the cap. |
| `strategy_cash_open_skip_minutes` | 0 | 0+ | Optional skip minutes after configured major cash opens; 0 disables. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with liquid intraday OHLC and previous-day levels.
- `GBPUSD.DWX` - FX major with liquid intraday OHLC and previous-day levels.
- `USDJPY.DWX` - FX major with liquid intraday OHLC and previous-day levels.
- `XAUUSD.DWX` - Gold CFD equivalent for the card's XAUUSD basket member.
- `NDX.DWX` - Nasdaq 100 index CFD from the card basket.
- `GDAXI.DWX` - DWX matrix DAX symbol used for the card's GER40.DWX intent.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no verified DWX backtest data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15`, `M30`, `H1` |
| Multi-timeframe refs | `PERIOD_D1` previous-day high/low |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 130 |
| Typical hold time | Intraday to one trading day |
| Expected drawdown profile | Trend-day breakouts can hit the ATR-adjusted stop before reverting. |
| Regime preference | Mean-revert after liquidity sweep |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/p6JuhRRE-Liquidity-Trap-Strategy-ATR-Optimized/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10705_tv-liq-trap.md`

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
| v1 | 2026-06-04 | Initial build from card | de2e3bba-8ad0-4801-a473-57b378968d93 |

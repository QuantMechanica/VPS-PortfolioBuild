# QM5_10705_tv-liq-trap_v2 - Strategy Spec

**EA ID:** QM5_10705
**Slug:** tv-liq-trap
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA fades failed breaks of the previous trading day's high and low on a closed intraday bar. A short signal occurs when the last closed bar trades above the previous day high and closes back below it; a long signal occurs when the last closed bar trades below the previous day low and closes back above it. The EA submits a market order on the first tick after that closed trap candle, sets the stop beyond the trap candle extreme by an ATR buffer, and sets take profit at a fixed R multiple. Only one submitted trap trade is allowed per broker day.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | 1+ | ATR period used for the stop buffer. |
| strategy_atr_buffer_mult | 1.0 | 0.5+ effective floor | ATR multiplier added beyond the trap candle high or low. |
| strategy_min_atr_buffer_mult | 0.5 | 0.5+ | Floor preventing the ATR buffer from being reduced below the card-tested minimum. |
| strategy_rr_target | 2.0 | 1.5-2.5 test range | Take-profit distance in R from entry to stop. |
| strategy_trade_window | 0 | 0, 1, 2 | 0 all day, 1 London/NY overlap, 2 NY only. |
| strategy_london_ny_start_minute | 780 | 0-1439 | Broker-time start minute for the London/NY overlap window. |
| strategy_london_ny_end_minute | 1020 | 0-1439 | Broker-time end minute for the London/NY overlap window. |
| strategy_ny_start_minute | 870 | 0-1439 | Broker-time start minute for the NY-only window. |
| strategy_ny_end_minute | 1260 | 0-1439 | Broker-time end minute for the NY-only window. |
| strategy_skip_cash_open_minutes | 0 | 0+ | Optional minutes to skip after configured London and NY cash opens. |
| strategy_london_open_minute | 480 | 0-1439 | Broker-time London cash-open minute for the optional skip window. |
| strategy_ny_cash_open_minute | 870 | 0-1439 | Broker-time NY cash-open minute for the optional skip window. |
| strategy_max_spread_points | 0 | 0+ | Optional spread ceiling in points; 0 disables the strategy-level spread cap. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - FX major with intraday OHLC and daily extremes in the DWX matrix.
- GBPUSD.DWX - FX major from the card's portable basket.
- USDJPY.DWX - FX major from the card's portable basket.
- XAUUSD.DWX - Canonical DWX suffix for the card's XAUUSD gold target.
- NDX.DWX - Liquid US index CFD from the card's portable basket.
- GDAXI.DWX - Matrix-listed DAX equivalent for the card's GER40.DWX target.

**Explicitly NOT for:**
- GER40.DWX - Not listed in `dwx_symbol_matrix.csv`; use GDAXI.DWX for DAX exposure.
- XAUUSD - Backtest registry requires the `.DWX` suffix; use XAUUSD.DWX.
- SPY.DWX, SPX500.DWX, ES.DWX - Not part of this card's R3 basket and not canonical S&P 500 symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15, M30, H1 |
| Multi-timeframe refs | Previous day high/low from D1; ATR on the chart timeframe |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 130 |
| Typical hold time | Intraday to multi-hour; exits at ATR-buffered SL, fixed R target, or framework Friday close |
| Expected drawdown profile | Vulnerable to trend days that continue after sweeping the prior-day extreme |
| Regime preference | Mean-reversion after failed liquidity sweeps |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/p6JuhRRE-Liquidity-Trap-Strategy-ATR-Optimized/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10705_tv-liq-trap_v2.md`

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
| v1 | 2026-05-31 | Initial build from card | de2e3bba-8ad0-4801-a473-57b378968d93 |


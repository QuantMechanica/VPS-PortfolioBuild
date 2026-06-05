# QM5_10798_tv-ema9-full - Strategy Spec

**EA ID:** QM5_10798
**Slug:** `tv-ema9-full`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-05

---

## 1. Strategy Logic

This EA trades the first closed candle that is fully above or fully below EMA(9). A long entry fires when the last closed candle has low > EMA(9) and the prior candle was not fully above EMA(9); a short entry fires when the last closed candle has high < EMA(9) and the prior candle was not fully below EMA(9). Long positions close when the closed-bar close crosses back below EMA(9), and short positions close when the closed-bar close crosses back above EMA(9). The hard stop is the closer of 1.5 ATR(14) or the entry candle's opposite extreme plus a 0.25 ATR buffer.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 9 | 1+ | EMA length used for full-candle entry and cross exit. |
| `strategy_atr_period` | 14 | 1+ | ATR period used for the hard-stop distance. |
| `strategy_atr_stop_mult` | 1.5 | >0 | ATR multiplier for the volatility stop candidate. |
| `strategy_entry_extreme_buffer` | 0.25 | >=0 | ATR buffer beyond the entry candle's opposite extreme. |
| `strategy_session_enabled` | true | true/false | Enables the liquid-session broker-time gate. |
| `strategy_session_start_hour` | 8 | 0-23 | Broker hour when the trading session opens. |
| `strategy_session_end_hour` | 21 | 0-23 | Broker hour when the trading session closes. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread ceiling in points; 0 disables the ceiling. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair in the card's P2 basket.
- `GBPUSD.DWX` - liquid major FX pair in the card's P2 basket.
- `USDJPY.DWX` - liquid major FX pair in the card's P2 basket.
- `XAUUSD.DWX` - canonical DWX gold symbol corresponding to the card's XAUUSD target.
- `GDAXI.DWX` - available DWX DAX custom symbol used for the card's GER40 target.
- `NDX.DWX` - liquid Nasdaq 100 index CFD in the card's P2 basket.
- `WS30.DWX` - liquid Dow 30 index CFD in the card's P2 basket.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is used instead.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 220 |
| Typical hold time | minutes to hours |
| Expected drawdown profile | high-cadence scalping drawdown controlled by ATR hard stops and EMA-cross exits |
| Regime preference | intraday trend continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** https://www.tradingview.com/script/zTbBxN70-9-EMA-First-Full-Candle-Entry-EMA-Cross-Exit-Strategy/
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10798_tv-ema9-full.md`

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
| v1 | 2026-06-05 | Initial build from card | ad4a6a28-df9f-4d03-b454-5e4e2ab45083 |

# QM5_11565_connors-3down-days-sma200-d1 - Strategy Spec

**EA ID:** QM5_11565
**Slug:** `connors-3down-days-sma200-d1`
**Source:** `278c6e13-0726-5779-83fe-a38f5a2e480f` (see `sources/connors-larry-short-term-trading-strategies-that-work`)
**Author of this spec:** Codex
**Last revised:** 2026-07-07

---

## 1. Strategy Logic

The EA trades daily pullbacks in the direction of a SMA(200) trend filter. It buys when the last closed D1 close is above SMA(200) and the last three closed D1 bars each closed lower than the prior bar. It sells when the last closed D1 close is below SMA(200) and the last four closed D1 bars each closed higher than the prior bar. Long exits occur when RSI(2) on the last closed D1 bar rises above 65; short exits occur when the last closed D1 close falls below SMA(5).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_sma_period` | 200 | 2+ | Trend-state SMA period. |
| `strategy_long_down_days` | 3 | 1-15 | Consecutive lower closes required for a long entry. |
| `strategy_short_up_days` | 4 | 1-15 | Consecutive higher closes required for a short entry. |
| `strategy_rsi_period` | 2 | 2+ | RSI period for the long exit. |
| `strategy_long_rsi_exit` | 65.0 | 0-100 | Long exit threshold for RSI. |
| `strategy_short_exit_sma` | 5 | 2+ | SMA period for the short exit. |
| `strategy_atr_period` | 14 | 2+ | ATR period for the protective stop. |
| `strategy_atr_stop_mult` | 2.0 | >0 | ATR multiple for the protective stop. |
| `strategy_stop_cap_pips` | 150 | >0 | Maximum stop distance in pips. |
| `strategy_spread_cap_pips` | 15 | >0 | Entry spread cap; zero modelled spread is allowed. |
| `strategy_block_friday_entry` | true | true/false | Blocks new entries on broker-time Friday. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 states D1 EURUSD.DWX is available for the Forex port.
- `GBPUSD.DWX` - Card R3 states D1 GBPUSD.DWX is available for the Forex port.
- `USDJPY.DWX` - Card R3 states D1 USDJPY.DWX is available for the Forex port.

**Explicitly NOT for:**
- `SPY.DWX` - Not a valid DWX symbol; original SPY concept is ported to Forex by the approved card.
- `SP500.DWX` - Available in the matrix, but the approved card specifically targets the Forex port.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 40 |
| Typical hold time | short D1 mean-reversion hold; card cites the next five trading days as the source effect window |
| Expected drawdown profile | pullback mean-reversion losses are bounded by the ATR stop capped at 150 pips |
| Regime preference | trend-filtered mean reversion |
| Win rate target (qualitative) | medium/high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `278c6e13-0726-5779-83fe-a38f5a2e480f`
**Source type:** book
**Pointer:** Larry Connors & Cesar Alvarez, "Short-Term Trading Strategies That Work", TradingMarkets Publishing, 2009; Strategies 1-2 plus S&P Short strategy.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11565_connors-3down-days-sma200-d1.md`

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
| v1 | 2026-07-07 | Initial build from card | 915122e3-91a4-4add-b509-c86ac9ff9e68 |

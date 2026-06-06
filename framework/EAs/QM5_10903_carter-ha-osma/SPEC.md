# QM5_10903_carter-ha-osma - Strategy Spec

**EA ID:** QM5_10903
**Slug:** `carter-ha-osma`
**Source:** `6facee24-8a58-5bbf-88e9-38d44291db50` (see `strategy-seeds/sources/6facee24-8a58-5bbf-88e9-38d44291db50/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA trades EURUSD.DWX and GBPUSD.DWX on H1 after a closed candle confirms all four momentum conditions. A long entry requires a bullish Heiken Ashi candle crossing above SMA(14), OsMA(12,26,9) crossing above zero, Momentum(10) crossing above 100, and RSI(5) crossing above 50; shorts mirror those rules below the same thresholds. The stop is placed beyond the last 10-bar swing with a 2-pip buffer, the primary target is 2R, and an open trade exits early when OsMA crosses back through zero against the position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_period` | 14 | 2-200 | SMA period used for the Heiken Ashi cross filter. |
| `strategy_osma_fast` | 12 | 1-100 | Fast EMA period for the MACD-derived OsMA value. |
| `strategy_osma_slow` | 26 | 2-200 | Slow EMA period for the MACD-derived OsMA value. |
| `strategy_osma_signal` | 9 | 1-100 | MACD signal period used in OsMA calculation. |
| `strategy_momentum_period` | 10 | 1-200 | Lookback for close-to-close Momentum scaled around 100. |
| `strategy_rsi_period` | 5 | 1-100 | RSI period used for the 50-level confirmation cross. |
| `strategy_swing_lookback` | 10 | 2-100 | Closed H1 bars searched for the swing stop anchor. |
| `strategy_stop_buffer_pips` | 2 | 0-50 | Extra stop buffer beyond the swing high or low. |
| `strategy_take_profit_rr` | 2.0 | 0.5-10.0 | Fixed reward-to-risk target multiplier. |
| `strategy_ha_seed_bars` | 32 | 2-200 | Bars used to seed the recursive Heiken Ashi calculation. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - the card names EURUSD as a source symbol and the DWX matrix marks it canonical.
- `GBPUSD.DWX` - the card names GBPUSD as a source symbol and the DWX matrix marks it canonical.

**Explicitly NOT for:**
- `SP500.DWX` - the card is a forex H1 strategy, not an index strategy.
- `XAUUSD.DWX` - the card does not provide metal calibration or source support.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `moderate trend-following drawdown during range-bound markets` |
| Regime preference | `trend / momentum-confirmation` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6facee24-8a58-5bbf-88e9-38d44291db50`
**Source type:** `book`
**Pointer:** `G:/My Drive/QuantMechanica/Ebook/PDF resources/20 Forex Trading Strategies - Thomas Carter.pdf`, Strategy #4, pages 10-11
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10903_carter-ha-osma.md`

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
| v1 | 2026-06-06 | Initial build from card | 12118c80-8d6b-4395-b8cd-aef03258cc27 |

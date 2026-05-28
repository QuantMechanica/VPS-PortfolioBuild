# QM5_10413_et-123-bounce - Strategy Spec

**EA ID:** QM5_10413
**Slug:** `et-123-bounce`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades a M15 three-bar exhaustion pattern during the liquid session. A long setup requires three falling lows and non-rising highs, then places a buy limit at the last closed bar low when the RSI filter is oversold. A short setup requires three rising highs and non-falling lows, then places a sell limit at the last closed bar high when the RSI filter is overbought. Exits are the fixed ATR stop, a 1R profit target, the 15:55 session exit, or a 10-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_session_start_hhmm` | 945 | 0-2359 | Broker-time start of the entry session. |
| `strategy_session_end_hhmm` | 1545 | 0-2359 | Broker-time end of the entry session. |
| `strategy_exit_hhmm` | 1555 | 0-2359 | Broker-time flat-before-session-end exit. |
| `strategy_atr_period` | 20 | 2-100 | ATR period used for stop distance. |
| `strategy_atr_sl_mult` | 1.0 | 0.25-5.0 | Stop distance multiplier on ATR. |
| `strategy_target_r_mult` | 1.0 | 0.25-5.0 | Profit target as a multiple of stop risk. |
| `strategy_exit_bars` | 10 | 1-100 | Maximum bars to hold an open position. |
| `strategy_use_rsi_filter` | true | true/false | Enables the card's baseline RSI filter. |
| `strategy_rsi_period` | 14 | 2-100 | RSI period for the optional exhaustion filter. |
| `strategy_rsi_long_max` | 30.0 | 1-50 | Long entries require RSI below this value. |
| `strategy_rsi_short_min` | 70.0 | 50-99 | Short entries require RSI above this value. |
| `strategy_max_spread_stop_frac` | 0.20 | 0.01-1.00 | Rejects setups when spread is too large versus stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - card targets S&P 500 exposure and the matrix provides the backtest-only custom symbol.
- `NDX.DWX` - card targets liquid US index CFDs and this is the Nasdaq 100 DWX symbol.
- `WS30.DWX` - card targets liquid US index CFDs and this is the Dow 30 DWX symbol.
- `GDAXI.DWX` - card names GER40 and the DWX matrix exposes DAX exposure as GDAXI.DWX.
- `XAUUSD.DWX` - card includes metals and the matrix provides gold as XAUUSD.DWX.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.

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
| Trades / year / symbol | `80` |
| Typical hold time | Intraday, max 10 M15 bars or same-session flat exit |
| Expected drawdown profile | Bounded by one ATR stop per entry and one active position per symbol/magic |
| Regime preference | Mean-revert intraday exhaustion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/easylanguage-question.5307/page-5`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10413_et-123-bounce.md`

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
| v1 | 2026-05-25 | Initial build from card | 5854b475-6be9-4996-8ab3-d119799ec254 |

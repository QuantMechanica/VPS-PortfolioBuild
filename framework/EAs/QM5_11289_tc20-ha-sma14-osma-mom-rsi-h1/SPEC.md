# QM5_11289_tc20-ha-sma14-osma-mom-rsi-h1 — Strategy Spec

**EA ID:** QM5_11289
**Slug:** `tc20-ha-sma14-osma-mom-rsi-h1`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Multi-indicator trend confluence on H1 (Thomas Carter, "20 Forex Trading
Strategies", Strategy #4). The entry uses one fresh cross as the trigger and the
remaining indicators as persistent states, so the five conditions do not need
to coincide as separate cross events on the same bar.

Long when, on the last closed H1 bar, OsMA(12,26,9) = MACD-main minus
MACD-signal crosses up through zero (the trigger event) AND the Heiken-Ashi
candle is bullish with its HA-close above SMA(14) AND Momentum(10) is above 100
AND RSI(5) is above 50. Short is the mirror (OsMA crosses down through zero,
bearish HA below SMA, Momentum below 100, RSI below 50). Heiken-Ashi is rebuilt
deterministically from a bounded 50-bar warmup of raw OHLC using the canonical
recurrence (HA-open = average of previous HA-open/HA-close; HA-close = OHLC/4).
Stop-loss is the swing low/high over the configured lookback; take-profit is
twice the stop distance (RR 2). The position also exits early if OsMA crosses
back through zero against it.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_period` | 14 | 5-50 | SMA(close) trend gate the HA-close must clear |
| `strategy_macd_fast` | 12 | 5-20 | OsMA fast EMA (MACD main) |
| `strategy_macd_slow` | 26 | 20-50 | OsMA slow EMA (MACD main) |
| `strategy_macd_signal` | 9 | 5-15 | OsMA signal EMA |
| `strategy_mom_period` | 10 | 5-30 | Momentum period; level 100 = flat |
| `strategy_rsi_period` | 5 | 3-21 | RSI period; level 50 = midline |
| `strategy_swing_lookback` | 12 | 5-50 | Bars back for swing low/high SL anchor |
| `strategy_tp_rr` | 2.0 | 1.0-4.0 | TP = RR multiple of SL distance |
| `strategy_min_sl_pips` | 5.0 | 1-30 | Floor on SL distance to avoid degenerate stops |
| `strategy_spread_cap_pips` | 20.0 | 1-100 | Card spread cap; fail-OPEN on zero modelled spread |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — primary card pair; deep liquid H1 trend behaviour.
- `GBPUSD.DWX` — primary card pair; trends well on H1 with comparable cost.
- `USDJPY.DWX` — P2 portable pair named in the card; pip-scaling handled via pip_factor.

**Explicitly NOT for:**
- Index / metal / energy `.DWX` symbols — the card mechanises an FX-major H1
  trend system; momentum-100 and RSI-50 thresholds were calibrated on FX.

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
| Trades / year / symbol | `~70` |
| Typical hold time | `hours (intraday to ~1-2 days)` |
| Expected drawdown profile | `moderate; most-selective filter in the TC20 H1 set keeps trade count low` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)", 2014, Strategy #4 (local PDF archive)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11289_tc20-ha-sma14-osma-mom-rsi-h1.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build lane |

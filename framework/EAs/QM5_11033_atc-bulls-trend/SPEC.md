# QM5_11033_atc-bulls-trend — Strategy Spec

**EA ID:** QM5_11033
**Slug:** `atc-bulls-trend`
**Source:** `9441393d-5ffc-5b43-87be-bd532110f204` (see `strategy-seeds/sources/9441393d-5ffc-5b43-87be-bd532110f204/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Bulls Power trend-change continuation, mechanised from the ATC 2010 "Bulls
Indicator" EA (Tauzowski). On each closed H1 bar the EA computes Bulls Power =
High − EMA(close, `bulls_period`) and its slope over `trend_lookback` bars,
normalised by ATR so the threshold is scale-invariant across FX pairs. It goes
**long** when Bulls Power is positive, the normalised slope is rising at least
`slope_threshold`, and the prior close is above the EMA. It goes **short** when
Bulls Power is negative (optionally also requiring Bears Power = Low − EMA to be
negative), the normalised slope is falling at most −`slope_threshold`, and the
prior close is below the EMA. Stop distance = max(`sl_min_pips` equivalent,
`sl_atr_mult` × ATR); take profit = `tp_rr` × stop (card baseline 2R). An
optional early exit closes the position when Bulls Power re-crosses zero against
the trade before SL/TP. Trades fire only inside the London/NY broker-time window
and, optionally, only when ADX ≥ `adx_threshold`. One position per symbol/magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bulls_period` | 13 | 8-34 | EMA period for Bulls/Bears Power and the trend EMA |
| `strategy_trend_lookback` | 5 | 3-8 | Bars back used for the Bulls Power slope |
| `strategy_slope_threshold` | 0.25 | 0.25-0.75 | Minimum \|slope\|/ATR (ATR-normalized units) to act |
| `strategy_bear_confirm` | false | bool | Also require Bears Power < 0 to allow a short |
| `strategy_atr_period` | 14 | 10-20 | ATR period for slope normalisation and stop floor |
| `strategy_sl_atr_mult` | 1.5 | 1.0-2.0 | Stop distance = mult × ATR (the larger of this / pip floor) |
| `strategy_sl_min_pips` | 40 | 30-50 | Stop floor in pips equivalent |
| `strategy_tp_rr` | 2.0 | 1.5-3.0 | Take-profit = tp_rr × stop distance (card: 2R) |
| `strategy_zero_cross_exit` | true | bool | Early close on Bulls Power zero re-cross against the trade |
| `strategy_session_start_broker` | 9 | 0-23 | London/NY window start hour (broker time) |
| `strategy_session_end_broker` | 22 | 0-23 | London/NY window end hour (broker time) |
| `strategy_use_adx_filter` | true | bool | Require ADX ≥ threshold for trend-change confirmation |
| `strategy_adx_period` | 14 | 10-20 | ADX period |
| `strategy_adx_threshold` | 18.0 | 14-25 | ADX trend-change confirmation floor |
| `strategy_spread_pct_of_stop` | 15.0 | 5-30 | Skip if spread > this % of stop distance (fail-open on .DWX) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid FX major; clean London/NY trend impulses suit Bulls Power continuation.
- `GBPUSD.DWX` — high-volatility major with pronounced London/NY directional moves.
- `EURJPY.DWX` — JPY cross with strong trend persistence; pip-scaling handled via `QM_StopRulesPipsToPriceDistance`.
- `USDJPY.DWX` — liquid JPY major; trend-following continuation per source basket.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — the card's basket and session model are FX-specific (London/NY liquid hours).

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
| Trades / year / symbol | `70` (card: conservative 50-120) |
| Typical hold time | `hours to a few days` (H1 trend-change continuation) |
| Expected drawdown profile | `bounded by fixed SL, 2R TP, fixed risk, one position per magic` |
| Regime preference | `trend / momentum-breakout` |
| Win rate target (qualitative) | `medium` (2R target implies sub-50% break-even) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9441393d-5ffc-5b43-87be-bd532110f204`
**Source type:** `forum` (MQL5 Articles / ATC 2010 interview)
**Pointer:** `https://www.mql5.com/en/articles/537` (Tomasz Tauzowski)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11033_atc-bulls-trend.md`

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
| v1 | 2026-06-17 | Initial build from card | pending compile/register (central step) |

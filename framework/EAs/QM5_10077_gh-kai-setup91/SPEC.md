# QM5_10077_gh-kai-setup91 - Strategy Spec

**EA ID:** QM5_10077
**Slug:** gh-kai-setup91
**Source:** 3b3ec48a-0755-5187-9331-afb36e174175 (see `sources/github-mql5-stars-20`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA runs on M5 and samples EMA(9) on closed bars. A buy signal exists when the latest closed-bar EMA is above the prior closed-bar EMA; a sell signal exists when it is below. At the start of each broker-time trading day the stored prior signal is reset, then a sell-to-buy transition places a buy stop at the signal candle high with stop loss at that candle low, while a buy-to-sell transition places a sell stop at the signal candle low with stop loss at that candle high. Pending orders are removed on opposite EMA signals, all orders and positions are flattened at 17:30 broker time, and open-position stops are moved to the opposite signal candle breakout price when an opposite EMA signal appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_M5` | MT5 timeframe enum | Signal timeframe from the source default. |
| `strategy_ema_period` | `9` | `>= 2` | EMA period used for rising/falling slope detection. |
| `strategy_entry_start_hhmm` | `900` | `0000-2359` | Broker-time session start for new pending entries. |
| `strategy_entry_end_hhmm` | `1600` | `0000-2359` | Broker-time session end for new pending entries. |
| `strategy_flat_hhmm` | `1730` | `0000-2359` | Broker-time flat time for pending-order removal and position close. |
| `strategy_take_profit_points` | `1000` | `> 0` | Fixed take-profit distance in symbol points from entry. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 target; liquid major FX pair with DWX M5 OHLC data.
- `GBPUSD.DWX` - Card R3 target; liquid major FX pair with DWX M5 OHLC data.
- `USDJPY.DWX` - Card R3 target; liquid major FX pair with DWX M5 OHLC data.
- `XAUUSD.DWX` - Card R3 target; gold symbol with DWX M5 OHLC data.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no broker/custom-symbol data guarantee for the V5 pipeline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, strategy_timeframe)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Intraday; exits by TP/SL management or 17:30 broker-time flat close. |
| Expected drawdown profile | Fixed-risk intraday breakout profile with one active position or pending order per symbol/magic. |
| Regime preference | EMA-turn pending breakout during the 09:00-16:00 broker-time session. |
| Win rate target (qualitative) | Not specified in card frontmatter. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3b3ec48a-0755-5187-9331-afb36e174175
**Source type:** GitHub source code
**Pointer:** DevTrader / kaiovalente, `9_1.mq5`, https://github.com/kaiovalente/mql5/blob/master/9_1.mq5
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10077_gh-kai-setup91.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-11 | Initial build from card | 07ce097c-5047-4e80-bb7d-567fbdbcec73 |

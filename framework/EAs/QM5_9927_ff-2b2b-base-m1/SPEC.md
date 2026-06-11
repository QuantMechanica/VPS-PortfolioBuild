# QM5_9927_ff-2b2b-base-m1 - Strategy Spec

**EA ID:** QM5_9927
**Slug:** `ff-2b2b-base-m1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades M1 liquidity-sweep reversals during the first 180 minutes after the configured London or New York open. A long setup starts when price sweeps below the latest 20-bar M1 swing low near an H1/H4/prior-session support level, then prints two bullish breaks with a pullback base between them. It buys when the Break-2 candle or a subsequent retest trades into the second-base-to-second-break zone and closes bullish, with the short side mirrored at resistance; stale retest states expire after the configured break-window length so newer closed-bar setups can form. Exits are the initial SL/TP, a close back beyond Base 1 against the trade, or a 45-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_london_open_hour_broker | 10 | 0-23 | Broker-time hour for the London open entry window. |
| strategy_london_open_min_broker | 0 | 0-59 | Broker-time minute for the London open entry window. |
| strategy_ny_open_hour_broker | 16 | 0-23 | Broker-time hour for the New York open entry window. |
| strategy_ny_open_min_broker | 30 | 0-59 | Broker-time minute for the New York open entry window. |
| strategy_session_minutes | 180 | 1-360 | Minutes after each open when new entries are allowed. |
| strategy_atr_period | 14 | 2-100 | ATR period used for M1 sweep/SL/spread and M15 key-level distance. |
| strategy_sweep_lookback | 20 | 5-100 | M1 swing lookback for liquidity sweep detection. |
| strategy_sweep_atr_mult | 0.15 | 0.01-2.00 | Required sweep distance beyond the swing level as ATR(M1) multiple. |
| strategy_break_lookback | 5 | 2-30 | M1 lookback used for Break 1 close beyond recent highs/lows. |
| strategy_max_break_bars | 12 | 1-60 | Maximum bars allowed from sweep to Break 1 and Break 1 to Break 2. |
| strategy_keylevel_atr_m15_mult | 0.60 | 0.05-5.00 | Max distance from H1/H4/prior-session level as ATR(M15) multiple. |
| strategy_spread_atr_max | 0.15 | 0.01-1.00 | Max spread as a fraction of ATR(M1) for new entries. |
| strategy_sl_atr_mult | 0.25 | 0.01-2.00 | Stop offset beyond Base 2 as ATR(M1) multiple. |
| strategy_rr_target | 1.50 | 0.10-10.00 | Risk multiple for the uncapped profit target. |
| strategy_fx_tp_cap_pips | 40 | 1-200 | FX TP cap in pips; EA uses the closer of this cap and R target. |
| strategy_xau_tp_atr_cap | 3.00 | 0.10-20.00 | XAUUSD TP cap as ATR(M1) multiple. |
| strategy_time_stop_bars | 45 | 1-300 | Maximum M1 bars to hold a position. |
| strategy_news_blackout_minutes | 15 | 0-120 | High-impact news blackout minutes before and after events. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card primary FX major with DWX M1 data.
- `GBPUSD.DWX` - card FX major basket member with DWX M1 data.
- `USDJPY.DWX` - card FX major basket member with JPY pip handling and DWX M1 data.
- `XAUUSD.DWX` - card metal basket member with ATR-capped target and DWX M1 data.

**Explicitly NOT for:**
- Non-DWX symbols - V5 build and backtest artifacts require canonical `.DWX` symbols.
- Non-M1 charts - the card is an M1 execution strategy and the EA blocks new entries on other chart periods.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | M15 ATR, H1/H4 support/resistance, prior D1 session high/low |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

London and New York opens are represented as broker-time inputs because the card does not specify a timezone conversion rule.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 160 |
| Typical hold time | Intraday scalps, maximum 45 M1 bars |
| Expected drawdown profile | Frequent small losses with capped risk per trade |
| Regime preference | Liquidity-sweep reversal after session-open volatility |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** ForexFactory thread "1M Scalping 2B2B" by Inthebox, https://www.forexfactory.com/thread/1333089-1m-scalping-2b2b
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9927_ff-2b2b-base-m1.md`

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
| v1 | 2026-06-10 | Initial build from card | f0b72d26-f58d-4596-8912-b22874ab174a |
| v2 | 2026-06-11 | Bounded stale post-Break-2 retest states after Q01 smoke trade-count review | d731be7a-e8de-45fc-bc9d-3b0b60214845 |
| v3 | 2026-06-11 | Allow closed Break-2 candle to satisfy entry-zone touch after smoke MIN_TRADES_NOT_MET | d731be7a-e8de-45fc-bc9d-3b0b60214845 |

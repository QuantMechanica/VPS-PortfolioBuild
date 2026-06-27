# QM5_10001_ff-static-fib-open - Strategy Spec

**EA ID:** QM5_10001
**Slug:** `ff-static-fib-open`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

---

## 1. Strategy Logic

At Tokyo open, the EA anchors a static price ladder to the current M15 open. It places one stop order at open +/- 34 pips only when the H1 bias agrees with SMA(70), RSI(21), and M15 stochastic(15,3,3). The initial stop is the open price, the default take-profit is open +/- 89 pips, and the optional runner target is open +/- 144 pips. Pending orders are cancelled at the broker time stop; open positions are moved to breakeven after a favorable 20-pip move and closed by the time stop if still open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_tokyo_open_hour_broker` | 0 | 0-23 | Broker-hour used as the Tokyo-open anchor. |
| `strategy_tokyo_open_minute` | 0 | 0-59 | Broker-minute used as the Tokyo-open anchor. |
| `strategy_time_stop_hour_broker` | 20 | 0-23 | Broker hour for pending-order cancellation and time-stop exit. |
| `strategy_entry_offset_pips` | 34 | >0 | Distance from open to the initial stop entry. |
| `strategy_tp1_offset_pips` | 89 | >entry offset | Baseline target distance from open. |
| `strategy_runner_offset_pips` | 144 | >entry offset | Optional runner target distance from open. |
| `strategy_use_runner_target` | false | true/false | Use 144-pip runner target instead of 89-pip TP1. |
| `strategy_sma_period_h1` | 70 | >=1 | H1 SMA trend filter period. |
| `strategy_rsi_period_h1` | 21 | >=1 | H1 RSI bias filter period. |
| `strategy_stoch_k_m15` | 15 | >=1 | M15 stochastic K period. |
| `strategy_stoch_d_m15` | 3 | >=1 | M15 stochastic D period. |
| `strategy_stoch_slow_m15` | 3 | >=1 | M15 stochastic slowing. |
| `strategy_stoch_long_min` | 60.0 | 0-100 | Minimum stochastic value for long setup. |
| `strategy_stoch_short_max` | 30.0 | 0-100 | Maximum stochastic value for short setup. |
| `strategy_atr_period_m15` | 14 | >=1 | ATR period for entry-distance sanity filter. |
| `strategy_min_entry_atr_mult` | 0.4 | >0 | Minimum entry distance as ATR multiple. |
| `strategy_max_entry_atr_mult` | 2.5 | >min | Maximum entry distance as ATR multiple. |
| `strategy_be_trigger_pips` | 20 | >=0 | Favorable move before breakeven adjustment. |
| `strategy_be_buffer_pips` | 3 | >=0 | Breakeven buffer in pips. |
| `strategy_max_spread_points` | 35 | >=0 | Wide-spread block threshold; zero spread is allowed. |
| `strategy_news_blackout_minutes` | 15 | >=0 | Custom high-impact pre-news blackout window. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - major FX pair from the card's P2 basket.
- `EURUSD.DWX` - major FX pair from the card's P2 basket.
- `USDJPY.DWX` - major FX pair from the card's P2 basket.
- `GBPJPY.DWX` - major JPY cross from the card's P2 basket.

**Explicitly NOT for:**
- `SP500.DWX` - index CFD, not part of the ForexFactory FX open-price rule.
- `XAUUSD.DWX` - metal CFD, not part of the card's FX basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `H1` SMA(70), `H1` RSI(21), `M15` ATR/stochastic |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 160 |
| Typical hold time | Intraday, Tokyo open to same-day time stop or target |
| Expected drawdown profile | Breakout-style losses bounded by the open-price stop distance |
| Regime preference | Intraday open-price breakout with trend-confirmed bias |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `https://www.forexfactory.com/thread/33615-simple-trading-system-for-intradayshort-term`
**R1-R4 verdict (Q00):** all PASS; see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_10001_ff-static-fib-open.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3%-0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-27 | Initial spec for Q02 INFRA rebuild | build task `1e0f8486-4193-4f89-8c06-59ef47e6f3d6` |

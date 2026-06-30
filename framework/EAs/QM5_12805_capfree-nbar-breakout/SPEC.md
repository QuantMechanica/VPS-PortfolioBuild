# QM5_12805_capfree-nbar-breakout - Strategy Spec

**EA ID:** QM5_12805
**Slug:** capfree-nbar-breakout
**Source:** capfree-scalping-ea-antigravity-spec-2026
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

The EA runs on M5 and maintains stop-pending breakout orders around the highest high and lowest low of the last 100 closed bars. A buy stop is placed at the N-bar high plus the configured order distance, and a sell stop is placed at the N-bar low minus the configured order distance; old stop orders are removed and refreshed as the range changes. Entries are allowed only during the broker-time session, after the H1 RSI(14, typical price) remains inside the 20-80 exhaustion band, and optionally in the H4 EMA200 trend direction. Exits use the hard SL/TP, the selected trailing-stop mode, session-end flatting, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_bars_n` | 100 | 1-500 | Closed-bar high/low lookback for the breakout channel. |
| `strategy_expiration_bars` | 300 | 1-2000 | Pending order lifetime, expressed in current-chart bars. |
| `strategy_session_start_hour` | 6 | 0-23 | Broker hour when order placement may begin. |
| `strategy_session_end_hour` | 21 | 0-23 | Broker hour when order placement stops and session flatting may occur. |
| `strategy_close_at_session_end` | true | true/false | Close open positions outside the configured session. |
| `strategy_max_spread_points` | 0.0 | 0+ | Maximum ask-bid spread in points; 0 disables the cap and does not block zero-spread DWX tests. |
| `strategy_percent_profile` | true | true/false | Use the source Prop profile: distances as percentages of price/SL. |
| `strategy_order_distance_pct_of_sl` | 50.0 | 0+ | Percent of SL distance used as the pending-order offset. |
| `strategy_sl_pct` | 0.4 | 0+ | Percent-profile hard stop distance as percent of entry price. |
| `strategy_tp_pct` | 0.4 | 0+ | Percent-profile hard target distance as percent of entry price. |
| `strategy_fixed_order_distance_pips` | 10 | 1+ | Fixed-profile pending-order offset, pips-scaled by the framework. |
| `strategy_fixed_sl_pips` | 20 | 1+ | Fixed-profile hard stop distance in pips. |
| `strategy_fixed_tp_pips` | 20 | 1+ | Fixed-profile hard target distance in pips. |
| `strategy_rsi_filter_enabled` | true | true/false | Enable H1 RSI exhaustion gate. |
| `strategy_rsi_period` | 14 | 2-100 | H1 RSI period. |
| `strategy_rsi_lower` | 20.0 | 0-100 | Lower allowed RSI bound. |
| `strategy_rsi_upper` | 80.0 | 0-100 | Upper allowed RSI bound. |
| `strategy_ma_filter_enabled` | false | true/false | Enable optional H4 EMA trend filter from the source spec. |
| `strategy_ma_period` | 200 | 2-500 | H4 EMA trend-filter period. |
| `strategy_ma_max_distance_pct` | 3.0 | 0+ | Maximum allowed H4 close distance from EMA before blocking orders. |
| `strategy_trail_type` | 0 | 0-2 | Trailing mode: 0 fixed/percent, 1 previous candle, 2 fast EMA. |
| `strategy_fixed_trail_trigger_pips` | 2 | 1+ | Fixed-profile profit distance before trailing activates. |
| `strategy_fixed_trail_distance_pips` | 1 | 1+ | Fixed-profile trailing stop distance. |
| `strategy_trail_trigger_pct_of_sl` | 10.0 | 0+ | Percent-profile trailing trigger as percent of SL distance. |
| `strategy_trail_distance_pct_of_sl` | 5.0 | 0+ | Percent-profile trailing distance as percent of SL distance. |
| `strategy_trail_prev_candles` | 1 | 1-20 | Previous-candle trailing lookback. |
| `strategy_trail_fast_ema_period` | 5 | 2-100 | Fast EMA period for MA trailing mode. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - Card names XAUUSD/gold as the first low-commission target and percent-profile asset.
- `NDX.DWX` - Canonical DWX equivalent for Nasdaq/US100 exposure.
- `GDAXI.DWX` - Canonical DWX equivalent for GER40/DAX exposure in the available matrix.
- `SP500.DWX` - Canonical DWX equivalent for US500/S&P 500; valid for backtest registration.

**Explicitly NOT for:**
- `BTCUSD.DWX` - Card/source mention BTC, but it is not present in `dwx_symbol_matrix.csv`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - Not canonical DWX symbols; the available S&P 500 custom symbol is `SP500.DWX`.
- FX majors/crosses - The card defers FX because the 20-pip M5 breakout is expected to be cost-sensitive under round-trip commission.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | H1 RSI(14, typical price); optional H4 EMA200 trend/overextension filter |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Typical hold time | Intraday, usually minutes to hours; session-end flatting prevents overnight holds. |
| Expected drawdown profile | About 10% expected DD from card frontmatter. |
| Regime preference | Volatility-expansion breakout in liquid gold/index markets. |
| Win rate target (qualitative) | Medium; thin scalping edge is expected to be cost-sensitive. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** capfree-scalping-ea-antigravity-spec-2026
**Source type:** OWNER-directed video/spec extraction
**Pointer:** `G:\My Drive\capfree_scalper_spec.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12805_capfree-nbar-breakout.md`

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
| v1 | 2026-06-30 | Initial build from card | 6b199ebf-40a1-4739-b0ac-8126ab1e38a8 |

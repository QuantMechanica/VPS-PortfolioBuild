# QM5_11465_suhr-bank-trading-stop-run-fade-h1 - Strategy Spec

**EA ID:** QM5_11465
**Slug:** `suhr-bank-trading-stop-run-fade-h1`
**Source:** `966a64b0-7975-5f93-81f6-ddc316a4e029`
**Author of this spec:** Codex
**Last revised:** 2026-08-22

---

## 1. Strategy Logic

This H1 FX EA fades structural stop runs. On each new H1 bar it first checks
the latest closed candle against the previous completed D1 high/low. If neither
previous-day level was swept, it checks the rolling 20-bar H1 high/low ending
at shift 2. A setup begins when the candle trades at least three pips through a
level. A later candle must close back inside that level, and a market entry is
allowed only while price is within 15 pips of the level and the entire sequence
is no more than five H1 bars old.

The protective stop is one pip beyond the recorded stop-run candle extreme and
setups requiring more than 60 pips of stop distance are skipped. The take profit
is the nearest valid opposing structural level among the recent 10-bar H1
extreme and the opposite previous-day extreme. An outside candle that sweeps
both high and low candidates at the same priority is directionally ambiguous
and is skipped. Positions otherwise exit through SL, TP, or the framework's
Friday-close guard.

All price thresholds use the framework pip-to-price helper, so five-digit and
JPY symbols share the same rules. Raw OHLC reads are bounded and execute only
on the framework's new-bar path.

---

## 2. Parameters

| Parameter | Default | P3 card range | Meaning |
|---|---:|---|---|
| `strategy_level_mode` | prior day then swing | prior-only / swing-only / both | Selects the manipulation-level source; baseline gives prior D1 levels priority. |
| `strategy_swing_lookback_bars` | 20 | fixed baseline | Closed H1 bars used for the rolling swing high/low, starting at shift 2. |
| `strategy_target_lookback_bars` | 10 | fixed baseline | Closed H1 bars used for the opposing target extreme. |
| `strategy_stop_run_pips` | 3 | 2 / 3 / 5 | Minimum excursion beyond a manipulation level. |
| `strategy_pullback_window_pips` | 15 | 10 / 15 / 20 | Maximum absolute entry distance from the manipulation level. |
| `strategy_max_sequence_bars` | 5 | 3 / 5 / 7 | Maximum bars after the stop-run candle in which confirmation and entry may occur. |
| `strategy_sl_buffer_pips` | 1 | 0 / 1 / 2 | Stop buffer beyond the stop-run extreme. |
| `strategy_max_stop_pips` | 60 | fixed baseline | Hard cap on entry-to-stop distance. |
| `strategy_max_spread_pips` | 20 | fixed baseline | Hard entry spread cap; zero-spread DWX tests remain allowed. |

Framework inputs, including the two-axis news controls, RNG seed, stress
rejection control, and Friday close, are defined in
`framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed and registered for:**

- `EURUSD.DWX` - active magic slot 0.
- `GBPUSD.DWX` - active magic slot 1.
- `USDJPY.DWX` - active magic slot 2.
- `AUDUSD.DWX` - active magic slot 3.
- `USDCAD.DWX` - active magic slot 4.

**Explicitly not in scope:** indices, metals, energy, rates, crypto, and FX
pairs not named by the approved card. Each portable symbol runs as its own
tester instance with its registry-backed `qm_magic_slot_offset`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe references | Previous completed D1 high/low |
| Structural H1 references | Shifts 2-21 for baseline swing levels; shifts 1-10 for target extremes |
| Bar gating | One canonical `QM_IsNewBar()` consume in `OnTick` |

The strategy hook also fails closed for entry when the host chart is not H1.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 10 |
| Frequency profile | Low-frequency structural mean reversion |
| Typical hold time | Intraday to several H1 bars; no strategy-specific active time stop |
| Drawdown profile | False-breakout fades can cluster losses during persistent range expansion |
| Regime preference | Stop-run rejection around obvious prior-day or recent swing liquidity levels |

An unfilled setup expires after five H1 bars. The card's time limit applies to
the setup sequence (`cancel if not triggered`), not to an already active trade.

---

## 6. Source Citation

The strategy is mechanised from Sterling Suhr, "Bank Trading Stop Run Fade,"
in TradingPub's *6 Simple Strategies for Trading Forex* (~2015), associated
with DayTradingForexLive.com. The durable approved card records R1 as
`TIER_C` / conditional because this is a named but self-published source. Under
the OWNER R1 policy dated 2026-07-23, R1 is informational; the card is OWNER
approved with R2, R3, and R4 all `PASS`. No claim of independent performance
verification is made.

Approved-card copy: `docs/strategy_card.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02-Q10) | `RISK_FIXED` | $1,000 per trade |
| Live burn-in (Q13) | `RISK_PERCENT` | Determined only by the authorized live process |
| Full live (post-Q13) | `RISK_PERCENT` | Determined only by portfolio allocation |

The EA source defaults to `RISK_PERCENT=0.0` and `RISK_FIXED=1000.0`.
Generated Q02 setfiles must retain those fixed-risk values. Sizing is performed
only by the V5 framework from the structural SL; the strategy never computes
lots.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-22 | Initial mechanical build from OWNER-approved card | Standard build task `4d5f4cc2-d995-45e9-a2ea-9e066b2f17ca` |

# QM5_10642_et-newhigh-scalp - Strategy Spec

**EA ID:** QM5_10642
**Slug:** et-newhigh-scalp
**Source:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64 (see Elite Trader technical-analysis source collection)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA trades only during the first hour after the relevant cash-index session open, after waiting the first 15 minutes. On M1, it calculates the highest high and lowest low of the prior 20 completed bars; a current ask break above that high opens a long, and a current bid break below that low opens a short. It skips days where the first 15-minute range is less than half the median first 15-minute range of recent sessions, skips wide spreads, opens at most one trade per symbol and magic per day, trails immediately by max(5 ticks, 0.35 x ATR(14,M1)), and closes any open position at 60 minutes after session open.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_breakout_lookback_bars | 20 | 10-30 | Completed M1 bars used for the prior high/low breakout level. |
| strategy_window_start_minutes | 15 | 15 | Minutes after cash open before entries are allowed. |
| strategy_window_end_minutes | 60 | 45-90 | Minutes after cash open when entries stop and open trades are time-closed. |
| strategy_atr_period | 14 | 14 | ATR lookback on M1 for the trailing stop component. |
| strategy_atr_trail_mult | 0.35 | 0.25-0.50 | ATR multiplier used in max(5 ticks, ATR distance). |
| strategy_min_trail_ticks | 5 | 4-5 | Minimum trail distance in symbol ticks. |
| strategy_max_spread_trail_frac | 0.25 | 0.00-0.25 | Maximum spread as a fraction of trail distance. |
| strategy_first_range_min_mult | 0.50 | 0.00-0.75 | Minimum first 15-minute range versus the recent-session median; 0 disables. |
| strategy_direction_mode | 0 | -1, 0, 1 | -1 short only, 0 symmetric, 1 long only. |
| strategy_us_open_hour_broker | 16 | broker hour | Broker-time hour used for US cash-index open. |
| strategy_us_open_minute_broker | 30 | broker minute | Broker-time minute used for US cash-index open. |
| strategy_eu_open_hour_broker | 9 | broker hour | Broker-time hour used for DAX cash-index open. |
| strategy_eu_open_minute_broker | 0 | broker minute | Broker-time minute used for DAX cash-index open. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom-symbol port named in the card's R3 basket; backtest-only T6 caveat remains outside build scope.
- NDX.DWX - Nasdaq 100 index port named in the card's R3 basket.
- GDAXI.DWX - Matrix-supported DAX 40 custom symbol used as the nearest available port for the card's GER40.DWX reference.

**Explicitly NOT for:**
- GER40.DWX - Card-stated DAX alias is not present in `framework/registry/dwx_symbol_matrix.csv`; registering it would violate DWX symbol discipline.
- SPX500.DWX, SPY.DWX, ES.DWX - S&P 500 variants are not the canonical available custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` for entry evaluation; bounded M1 range scans are cached by day or run only inside the new-bar-gated entry hook. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, maximum 45 minutes from first eligible entry to 60-minute session time stop |
| Expected drawdown profile | Scalping breakout with small ATR/tick trailing stops and one trade per day cap |
| Regime preference | Opening-session volatility expansion and directional breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64
**Source type:** forum
**Pointer:** Elite Trader thread "Questions - Buy New Highs, Sell New Lows Strategy", 2011-10-12 to 2011-10-19
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10642_et-newhigh-scalp.md`

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
| v1 | 2026-06-14 | Initial build from card | 69f3e99c-bbde-4d76-819a-48341ffee890 |

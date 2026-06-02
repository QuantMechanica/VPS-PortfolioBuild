# QM5_10712_tv-ict-retest - Strategy Spec

**EA ID:** QM5_10712
**Slug:** tv-ict-retest
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (TradingView script `ICT Session Breakout v3`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA locks the previous 24-hour session high and low at a configurable CET session boundary. A long setup starts when a closed M5 or M15 candle opens below the previous session high and closes above it; a short setup starts when a candle opens above the previous session low and closes below it. After the break, price must move back inside the prior range by the configured reentry distance, wait the minimum number of bars, and the latest closed bar must touch the reentry line within the tolerance before the EA enters at market. Exits are the fixed/ATR stop, fixed/ATR take profit, the framework Friday close, or the enabled broker day-end flat rule.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_session_boundary_hour_cet` | 8 | 0-23 | CET hour used to roll and lock the prior session range. |
| `strategy_broker_to_cet_hours` | -1 | -12 to 12 | Deterministic broker-time to CET conversion offset. |
| `strategy_reentry_pips` | 5 | 1-100 | Distance back inside the broken level required after the breakout. |
| `strategy_entry_tolerance_pips` | 5 | 1-100 | Maximum tolerance around the reentry line for the market-entry retest. |
| `strategy_min_bars_after_break` | 3 | 0-50 | Minimum closed bars to wait after the breakout candle. |
| `strategy_sl_pips` | 10 | 1-500 | FX stop distance for EURUSD and GBPUSD. |
| `strategy_tp_pips` | 20 | 1-1000 | FX take-profit distance for EURUSD and GBPUSD. |
| `strategy_atr_period` | 14 | 2-200 | ATR period for XAUUSD and index stop/target normalization. |
| `strategy_atr_sl_mult` | 1.0 | 0.1-10.0 | ATR stop multiplier for XAUUSD and indices. |
| `strategy_atr_tp_mult` | 2.0 | 0.1-20.0 | ATR take-profit multiplier for XAUUSD and indices. |
| `strategy_max_spread_stop_fraction` | 0.15 | 0.01-1.0 | Blocks entries when spread exceeds this fraction of planned stop distance. |
| `strategy_session_scan_bars` | 600 | 100-2000 | Closed bars scanned to reconstruct prior and current session state. |
| `strategy_day_end_flat_enabled` | true | true/false | Enables the optional New York day-end flat rule from the card. |
| `strategy_day_end_flat_hour_broker` | 23 | 0-23 | Broker hour at or after which open positions are flattened. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed FX target with EURUSD-style pip stop and target.
- `GBPUSD.DWX` - Card-listed FX target with EURUSD-style pip stop and target.
- `XAUUSD.DWX` - Card-listed metal target using ATR-normalized stop and target.
- `GDAXI.DWX` - DWX matrix DAX symbol used in place of card-stated `GER40.DWX`, which is not present in the matrix.
- `NDX.DWX` - Card-listed Nasdaq index target using ATR-normalized stop and target.

**Explicitly NOT for:**
- `GER40.DWX` - Not present in `framework/registry/dwx_symbol_matrix.csv`; DAX exposure is represented by `GDAXI.DWX`.
- Symbols outside the registered DWX basket - No magic slot is registered for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 120 |
| Typical hold time | Intraday, usually minutes to hours due fixed/ATR bracket and day-end flat |
| Expected drawdown profile | Breakout-retest losses should be bounded by the planned stop distance per trade |
| Regime preference | Breakout / volatility expansion around prior-session levels |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView open-source strategy script
**Pointer:** TradingView script `ICT Session Breakout v3`, author handle `Burdiga84`, https://www.tradingview.com/script/7IFb4Zx7/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10712_tv-ict-retest.md`

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
| v1 | 2026-05-31 | Initial build from card | 8707a2a1-9b8b-4fce-a2b0-d40012a44e63 |

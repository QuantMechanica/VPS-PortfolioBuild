# QM5_10039_ff-hline-sma50-h1 - Strategy Spec

**EA ID:** QM5_10039
**Slug:** `ff-hline-sma50-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see ForexFactory source citation in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades H1 round-number breakouts in the direction of the 50-period simple moving average. On each closed H1 bar, if the close is above SMA50, it finds the nearest 25-pip grid level above both the close and SMA50, requires that level to be at least 10 pips from SMA50, and places a buy stop 3 pips beyond the level. Short entries mirror the rule below SMA50 with a sell stop 3 pips below the selected grid level.

Each pending order expires after 3 H1 bars. Filled positions use a 30-pip stop, a 50-pip target, a breakeven-plus-1-pip stop move after 12.5 pips of favourable movement, and a 10 H1 bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_period` | 50 | >= 1 | H1 SMA period used as the trend-side filter. |
| `strategy_grid_pips` | 25 | >= 1 | Distance between horizontal round-number grid levels. |
| `strategy_entry_offset_pips` | 3 | >= 1 | Stop-order offset beyond the selected grid level. |
| `strategy_grid_sma_min_pips` | 10 | >= 0 | Minimum distance between selected grid level and SMA50. |
| `strategy_opposite_min_pips` | 5 | >= 0 | Minimum distance from close to the next opposite grid level. |
| `strategy_sl_pips` | 30 | >= 1 | Fixed stop-loss distance. |
| `strategy_tp_pips` | 50 | >= 1 | Fixed take-profit distance. |
| `strategy_be_trigger_pips` | 12.5 | > 0 | Favourable movement before stop is moved to breakeven. |
| `strategy_be_buffer_pips` | 1.0 | >= 0 | Breakeven stop buffer beyond entry. |
| `strategy_pending_bars` | 3 | >= 1 | Pending stop lifetime in H1 bars. |
| `strategy_time_stop_bars` | 10 | >= 1 | Maximum hold after fill in H1 bars. |
| `strategy_max_spread_sl_frac` | 0.10 | 0.0-1.0 | Entry is skipped when spread exceeds this fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair with standard non-JPY 25-pip grid behaviour.
- `GBPUSD.DWX` - liquid major FX pair with standard non-JPY 25-pip grid behaviour.
- `EURJPY.DWX` - liquid JPY cross; grid maps to 0.25 JPY increments.
- `USDJPY.DWX` - liquid JPY major; grid maps to 0.25 JPY increments.

**Explicitly NOT for:**
- Index and commodity `.DWX` symbols - card mechanics are pip-grid FX rules, not point-value index or metal rules.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 65 |
| Typical hold time | Pending order up to 3 H1 bars; filled trade up to 10 H1 bars |
| Expected drawdown profile | Fixed 30-pip stop with one active position or pending order per symbol and magic. |
| Regime preference | Breakout with SMA50 trend-side filter |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** Fx-ken, "Simple Horizontal Line Trading H1", ForexFactory, 2019-06-10, https://www.forexfactory.com/thread/922813-simple-horizontal-line-trading-h1
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10039_ff-hline-sma50-h1.md`

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
| v1 | 2026-06-09 | Initial build from card | 1d4a97bf-55cc-4224-bd9c-388072168607 |

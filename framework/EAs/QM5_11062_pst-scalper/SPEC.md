# QM5_11062_pst-scalper - Strategy Spec

**EA ID:** QM5_11062
**Slug:** `pst-scalper`
**Source:** `352af9de-f372-5cf2-9a86-681a26224597` (Rob Carver / pst-group pysystemtrade scalper)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA implements the pysystemtrade scalper bracket mean-reversion rule. On each closed M1 bar it estimates a horizon range `R` as the mean of the last four completed 600-second horizon ranges, clamps `R` using the source min/max formulas, then places a symmetric pair of pending limit orders around current mid price. The buy bracket is `mid - 0.75*(R/2)` and the sell bracket is `mid + 0.75*(R/2)`; each pending order carries a stop at `(0.875 - 0.75)*R`, floored to at least three ticks. Trading is limited to a configurable broker-time liquid session, stops opening new brackets within three horizons of session end, and cancels unmatched pending orders when the state becomes flat or the session closes.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_horizon_seconds` | 600 | 300-900 card tests | Source horizon used for range windows and pending-order expiration |
| `strategy_range_segments` | 4 | >=4 | Completed horizon ranges averaged to estimate `R` |
| `strategy_limit_mult_F` | 0.75 | source default | Bracket offset fraction: limit = mid +/- F*(R/2) |
| `strategy_stop_mult_K` | 0.875 | 0.85-0.90 card tests | Stop multiple; stop gap from fill = (K-F)*R |
| `strategy_spread_mult` | 0.25 | 0.15-0.35 card tests | Skip entry when modeled spread is greater than this multiple of `R` |
| `strategy_slippage_ticks` | 1.0 | >=0.5 | Source min_R input; slippage ticks used in the minimum R formula |
| `strategy_min_slippage_units_L_to_K` | 5 | source default | Source minimum slippage units between limit and stop levels |
| `strategy_min_stop_ticks` | 3 | source default | Minimum stop distance from bracket fill, in ticks |
| `strategy_std_dev_budget_ccy` | 150.0 | source default | Source daily standard-deviation budget used in the maximum R formula |
| `strategy_min_R_override_points` | 0.0 | 0 or >0 | Optional per-symbol override for minimum R in points; 0 uses source formula |
| `strategy_max_R_override_points` | 0.0 | 0 or >0 | Optional per-symbol override for maximum R in points; 0 uses source formula |
| `strategy_session_start_h` | 7 | 0-23 | Broker hour when bracket placement may begin |
| `strategy_session_end_h` | 20 | 0-23 | Broker hour when bracket placement ends and pending orders are cancelled |
| `strategy_cutoff_horizons` | 3 | >=1 | Stop opening brackets within this many horizons of session end |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 target; liquid FX major suitable for intraday limit-order testing.
- `GBPUSD.DWX` - card R3 target; liquid FX major with active intraday range behaviour.
- `USDJPY.DWX` - card R3 target; liquid FX major; tick and point scaling come from symbol metadata.
- `AUDUSD.DWX` - card R3 target; liquid FX major in the approved portable basket.
- `NDX.DWX` - card R3 target; liquid index CFD with high intraday activity.
- `WS30.DWX` - card R3 target; liquid index CFD with high intraday activity.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - no DWX tick-data support.
- Thin crosses or high-spread symbols - the bracket edge is spread-sensitive by construction.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

M1 is the closest standard MT5 timeframe to the card's tick or one-second sampling requirement while allowing the 600-second source horizon to be represented as ten M1 bars.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | minutes; pending brackets expire after one horizon |
| Expected drawdown profile | many small bracket wins/losses; sensitive to tick quality, spread, and fill assumptions |
| Regime preference | intraday mean reversion |
| Win rate target (qualitative) | medium-high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `352af9de-f372-5cf2-9a86-681a26224597`
**Source type:** open-source code
**Pointer:** https://github.com/pst-group/pysystemtrade/blob/develop/systems/provided/scalper/components.py and `configuration.py`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11062_pst-scalper.md`

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
| v1 | 2026-06-23 | Initial build from card | 5e005c99-2e54-4474-b49a-1427c9fe9288 |

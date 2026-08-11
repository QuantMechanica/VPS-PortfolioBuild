# QM5_12486_shv-supertrend - Strategy Spec

**EA ID:** QM5_12486
**Slug:** `shv-supertrend`
**Source:** `af7930c8-6c65-52d1-9c01-040490b5ad39`
**Author of this spec:** Codex
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

The EA reconstructs a standard SuperTrend state from completed daily bars. It
uses ATR(7), a band multiplier of 3.0, and the source's trailing upper/lower
band state machine. A change from the upper-band state to the lower-band state
enters long; the mirrored change enters short. An opposite state closes the
open position, allowing the symmetric reversal rule to act at the completed-bar
boundary. Only one position per symbol and registered magic may be open.

The bounded SuperTrend reconstruction and ATR(20) emergency-stop value are
cached once per completed D1 bar. Entry, exit, and spread checks consume that
single cache so modeled ticks cannot change closed-bar state or repeat the
history scan.

---

## 2. Parameters

| Parameter | Default | Test range / status | Meaning |
|---|---:|---|---|
| `strategy_st_atr_period` | 7 | 7, 10, 14 | SuperTrend ATR period. |
| `strategy_st_multiplier` | 3.0 | 2.0, 3.0, 4.0 | Distance of the basic bands from midpoint in ATR units. |
| `strategy_st_seed_bars` | 200 | fixed baseline | Closed D1 bars used to initialise the recursive band state. |
| `strategy_sl_atr_period` | 20 | fixed baseline | ATR period for the independent emergency stop. |
| `strategy_sl_atr_mult` | 3.0 | fixed baseline | Emergency-stop distance in ATR(20) units. |
| `strategy_spread_pct_of_stop` | 15.0 | non-negative | Blocks entries when positive modeled spread exceeds this percentage of stop distance. |

---

## 3. Symbol Universe

The approved and registered universe is:

- `EURUSD.DWX`
- `GBPUSD.DWX`
- `USDJPY.DWX`
- `AUDUSD.DWX`
- `XAUUSD.DWX`
- `NDX.DWX`
- `WS30.DWX`

The rule uses OHLC and ATR only. It has no equity-specific, cross-symbol, or
external-data dependency. Symbols outside the registered universe are not part
of this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe references | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |
| Data reads | completed D1 bars only (`shift >= 1`) |

The EA rejects non-D1 tester/chart configurations during initialisation.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year per symbol | approximately 16 from the approved card |
| Typical hold time | days to weeks |
| Frequency class | structural low-frequency |
| Regime preference | persistent directional trends |
| Primary failure mode | whipsaw during range-bound volatility |

The emergency ATR stop bounds adverse movement between completed-bar regime
checks. The Friday-close and central news controls remain framework-owned.

---

## 6. Source Citation

**Source ID:** `af7930c8-6c65-52d1-9c01-040490b5ad39`

**Primary source:** Shashank Vemuri, `Finance/technical_indicators/super_trend.py`,
public GitHub repository:
`https://github.com/shashankvemuri/Finance/blob/master/technical_indicators/super_trend.py`

**Approved card:**
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_12486_shv-supertrend.md`

The G0 card records R1-R4 as PASS: durable source lineage, deterministic
mechanics, DWX-compatible OHLC data, and no machine learning, grid, martingale,
or multi-position mechanics.

---

## 7. Risk Model

| Environment | Risk mode | Value |
|---|---|---|
| Backtest pipeline | `RISK_FIXED` | USD 1,000 per trade |
| Live environments | `RISK_PERCENT` | portfolio allocation only after downstream approval |

All canonical Q02 setfiles use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Framework environment/risk validation remains active.

---

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-11 | Added canonical Q01 spec; documented D1 cache repair after repeated Q02 timeouts from per-tick history reconstruction. |

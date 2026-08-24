# QM5_1612_aa-dsp-hplwma10 - Strategy Spec

**EA ID:** QM5_1612
**Slug:** aa-dsp-hplwma10
**Source:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Author of this spec:** Codex
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

On each newly completed D1 bar, the EA calculates the card's fixed ten-close
high-pass linear weighted moving average. It opens long on a non-positive to
positive zero-cross and short on a non-negative to negative zero-cross. An open
position exits on the first completed D1 bar where the signal crosses back
through zero; every entry carries an initial 2.5 x ATR(20, D1) protective stop.
New entries are rejected when the current spread exceeds 2.5 times the median
spread of the preceding 20 completed D1 bars.

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_min_daily_bars` | 20 | Minimum completed D1 history required before evaluation |
| `strategy_atr_period` | 20 | D1 ATR lookback for the initial stop |
| `strategy_atr_sl_mult` | 2.5 | ATR multiplier for the initial stop |
| `strategy_spread_median_days` | 20 | Completed D1 spread observations used for the median |
| `strategy_spread_median_mult` | 2.5 | Maximum current-spread multiple of the D1 median |

## 3. Symbol Universe

The governed portable build universe is:

- Equity indices: `GDAXI.DWX`, `NDX.DWX`, `SP500.DWX`, `UK100.DWX`, `WS30.DWX`.
- Gold and energy: `XAUUSD.DWX`, `XTIUSD.DWX`.
- FX: `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`.

The approved card's `USOIL.DWX` concept is represented by the governed logical
broker alias `XTIUSD.DWX` (`framework/registry/execution_symbol_aliases_v1.json`).
All symbols use their own active `(ea_id, symbol_slot)` magic row.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe references | None |
| Signal cadence | Once per completed D1 bar via `QM_IsNewBar(_Symbol, PERIOD_D1)` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 100 (card estimate; pipeline-measured) |
| Typical hold time | 2-10 D1 bars |
| Regime preference | Trending / directional momentum |
| Position policy | One position per symbol and resolved magic |

## 6. Source Citation

**Source ID:** ede348b4-0fa7-5be1-baa8-09e9089b67b7

Henry Stern, "An Introduction to Digital Signal Processing for Trend Following",
Alpha Architect, 2020-08-13 (updated 2025-03):
https://alphaarchitect.com/an-introduction-to-digital-signal-processing-for-trend-following/

R1 lineage and the R2-R4 PASS decisions are preserved in the OWNER-approved
runtime card at
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_1612_aa-dsp-hplwma10.md`.

## 7. Risk Model

| Environment | Risk mode | Value |
|---|---|---:|
| Backtest | `RISK_FIXED` | $1,000 per trade |
| Live preset | `RISK_PERCENT` | 0.5% |

The source defaults are fail-closed for live use: `RISK_PERCENT=0.0` and
`RISK_FIXED=1000.0`. A separately governed live setfile must set
`RISK_FIXED=0` and `RISK_PERCENT=0.5`; this build creates backtest setfiles only.

## Revision History

| Version | Date | Change | Task |
|---|---|---|---|
| v1 | 2026-08-22 | Initial build from approved card | `690cd9ab-da44-4dd5-8cb2-0212384dc3db` |
| v2 | 2026-08-24 | Review repair: spread guard, D1 exit cadence, oil identity, clean provenance | `ee8153cf-df11-47af-8157-aaf473ce8dbb` |

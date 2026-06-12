# QM5_10332_coi-flow - Strategy Spec

**EA ID:** QM5_10332
**Slug:** coi-flow
**Source:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9 (see `strategy-seeds/sources/fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

On each closed M5 bar, the EA approximates order imbalance with signed tick volume: tick volume is positive when the bar closes above its open and negative when it closes below its open. A bar is actionable when the current symbol's absolute signed flow is above its rolling 80th percentile and enough basket members are available for classification. If fewer than half of the other valid basket members show high flow in the same direction, the EA trades with the flow for one bar; if at least half of the other valid members show high flow in the same direction, it fades the flow for one bar. The stop is 0.50 x ATR(14,M5), entries are skipped when the stop is less than four current spreads, and positions are closed after one M5 bar or at the session boundary.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_basket_symbols` | `SP500.DWX,NDX.DWX,WS30.DWX,GDAXI.DWX` | registered DWX symbols | Basket used for co-occurrence classification. |
| `strategy_flow_lookback` | 100 | >= 20 | Closed-bar history used for signed-flow percentile and z-score. |
| `strategy_flow_percentile` | 80.0 | 0-100 | Percentile threshold for high absolute signed flow. |
| `strategy_min_valid_members` | 3 | 1-4 | Minimum basket members required before classifying isolated/co-moving flow. |
| `strategy_atr_period` | 14 | >= 1 | ATR period for the stop. |
| `strategy_atr_stop_mult` | 0.50 | > 0 | ATR multiplier for stop distance. |
| `strategy_min_stop_spread_mult` | 4.0 | > 0 | Minimum stop distance as a multiple of current spread. |
| `strategy_spread_lookback` | 100 | >= 20 | Closed-bar history used for rolling spread percentile. |
| `strategy_spread_percentile` | 80.0 | 0-100 | Spread percentile above which entries are skipped. |
| `strategy_session_start_hhmm` | 1540 | 0000-2359 | Broker-time session start after skipping the first 10 minutes. |
| `strategy_session_end_hhmm` | 2150 | 0000-2359 | Broker-time session end before the last 10 minutes. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol specified by the card's R3 basket; backtest-only caveat applies at T6.
- `NDX.DWX` - Nasdaq 100 index CFD in the card's R3 basket.
- `WS30.DWX` - Dow 30 index CFD in the card's R3 basket.
- `GDAXI.DWX` - DWX matrix DAX symbol used as the available port for the card's `GER40.DWX` leg.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; use `GDAXI.DWX`.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - non-canonical or unavailable S&P 500 variants.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | one M5 bar |
| Expected drawdown profile | Intraday short-hold flow strategy with ATR-capped single-trade loss. |
| Regime preference | High-volume liquid overlap windows with strong isolated or co-moving signed flow. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Source type:** paper
**Pointer:** https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4363082
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10332_coi-flow.md`

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
| v1 | 2026-06-13 | Initial build from card | 7f751f55-578b-46e4-89fe-5a114e0f0e81 |

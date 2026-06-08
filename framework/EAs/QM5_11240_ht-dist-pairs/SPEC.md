# QM5_11240_ht-dist-pairs - Strategy Spec

**EA ID:** QM5_11240
**Slug:** `ht-dist-pairs`
**Source:** `af021dd0-e07d-5f72-9933-de7a3533934e` (see `strategy-seeds/sources/af021dd0-e07d-5f72-9933-de7a3533934e/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA trades the Hudson Thames distance-pair rule on four fixed DWX pair candidates from the approved card. On each completed D1 bar it normalizes both legs over the last 252 completed D1 closes as `(Close - min(Close)) / (max(Close) - min(Close))`, computes the normalized spread `A - B`, and keeps the lowest-distance pair candidates from that formation window. If the spread is at least `entry_z` training standard deviations above zero it sells A and buys B; if it is at least `entry_z` standard deviations below zero it buys A and sells B. Both legs close together when the spread crosses zero, reaches `stop_z` standard deviations, reaches the D1 time stop, or the framework Friday close gate fires.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_formation_bars` | 252 | 126-378 | Completed D1 bars used for min-max normalization, pair distance, and spread standard deviation. |
| `strategy_entry_z` | 2.0 | 1.5-2.5 | Entry threshold in training spread standard deviations. |
| `strategy_stop_z` | 4.0 | 3.0-5.0 | Emergency close threshold in training spread standard deviations. |
| `strategy_max_hold_bars` | 60 | 20-90 | Maximum D1 bars to hold a spread before time-stop closure. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - they are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - first leg of the EURUSD/GBPUSD FX distance pair from R3.
- `GBPUSD.DWX` - second leg of the EURUSD/GBPUSD FX distance pair from R3.
- `AUDUSD.DWX` - first leg of the AUDUSD/NZDUSD FX distance pair from R3.
- `NZDUSD.DWX` - second leg of the AUDUSD/NZDUSD FX distance pair from R3.
- `XAUUSD.DWX` - first leg of the XAUUSD/XAGUSD metals distance pair from R3.
- `XAGUSD.DWX` - second leg of the XAUUSD/XAGUSD metals distance pair from R3 and present in the DWX matrix.
- `NDX.DWX` - first leg of the NDX/WS30 index distance pair from R3.
- `WS30.DWX` - second leg of the NDX/WS30 index distance pair from R3.

**Explicitly NOT for:**
- Symbols outside the eight registered legs - the approved card defines a fixed portable DWX pair basket, not an open universe scan.
- `SP500.DWX` - mentioned only as a possible additional index leg; it is not in the card's primary P2 pair basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with D1 setfiles |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `24` |
| Typical hold time | Up to 60 D1 bars; exits sooner on normalized spread zero-cross. |
| Expected drawdown profile | Mean-reversion spread drawdowns when correlated legs diverge further before convergence. |
| Regime preference | Mean-revert, correlation-stable spread regimes. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `af021dd0-e07d-5f72-9933-de7a3533934e`
**Source type:** `research notebook / paper`
**Pointer:** Hudson & Thames "Basic Distance Approach", `https://github.com/hudson-and-thames/arbitrage_research/blob/master/Distance%20Approach/basic_distance_approach.ipynb`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11240_ht-dist-pairs.md`

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
| v1 | 2026-06-08 | Initial build from card | 9d97b044-985a-4e0e-9089-2b06b17f943b |

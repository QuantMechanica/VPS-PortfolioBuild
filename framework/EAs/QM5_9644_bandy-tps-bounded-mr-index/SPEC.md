# QM5_9644_bandy-tps-bounded-mr-index — Strategy Spec

**EA ID:** QM5_9644
**Slug:** `bandy-tps-bounded-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016` (see `strategy-seeds/sources/9ef19e06-5ca6-5b35-aa06-b8187aa0e016/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

Daily-close, long-only bounded scale-in mean-reversion on US equity indices —
the R4-compliant recast of Bandy's unbounded TPS layered system. Computes
`z = (close - SMA20) / StdDev20` on each closed D1 bar, gated by a
`close > SMA200` regime filter. A per-magic `units_held` counter (0-3,
persisted via `GlobalVariableSet`/`GlobalVariableGet`, restart-safe) tracks
how many of the 3 equal-sized slots are filled: unit-1 fires at `z<=-2.0`,
unit-2 at `z<=-2.5` (only once unit-1 is filled and within 15 trading days of
it), unit-3 at `z<=-3.0` (same staleness guard). Each unit risks exactly 1/3
of the EA's configured risk budget, sized against a single catastrophic stop
level computed once at unit-1's fill (`entry_unit_1 - 4.0×ATR(14)`) and reused
unchanged for units 2/3 — this is sent as a real broker-side SL on every
unit's order so MT5 enforces it natively without per-tick synchronisation.
Exit ALL units together at the next closed bar after `z>=0` (zero-line
take-profit) or after 10 trading days from unit-1's entry, whichever comes
first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_zscore_lookback` | 20 | fixed | SMA/StdDev lookback for the z-score |
| `strategy_unit1_entry_z` | -2.0 | -1.5 to -2.5 | Unit-1 entry threshold |
| `strategy_unit2_entry_z` | -2.5 | -2.0 to -3.0 | Unit-2 entry threshold |
| `strategy_unit3_entry_z` | -3.0 | -2.5 to -3.5 | Unit-3 entry threshold |
| `strategy_exit_z` | 0.0 | -0.5 to +0.5 | Zero-line take-profit for the full position |
| `strategy_regime_sma_period` | 200 | 100-300 | Long-only regime filter (close > SMA) |
| `strategy_atr_period` | 14 | fixed | ATR period for the catastrophic stop and vol-chaos filter |
| `strategy_catastrophic_atr_mult` | 4.0 | 3.0-5.0 | Catastrophic stop distance in ATR multiples from unit-1's entry |
| `strategy_time_stop_days` | 10 | 7-14 | Max holding period (trading days) from unit-1 entry |
| `strategy_unit_stale_days` | 15 | fixed | Max trading days since unit-1 before unit-2/3 additions are refused |
| `strategy_vol_lookback_bars` | 252 | fixed | Lookback window for the vol-chaos percentile filter |
| `strategy_vol_percentile` | 99.0 | fixed | Skip entries when ATR/close sits at/above this percentile |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 index CFD; Bandy's original TPS instrument class
- `NDX.DWX` — Nasdaq 100; live-tradable index CFD with the same daily-bar MR dynamics
- `WS30.DWX` — Dow 30; live-tradable index CFD, completes the US large-cap basket

**Explicitly NOT for:**
- FX pairs / metals / energies — the card's regime asymmetry rationale (equity drawdowns
  vs rallies) is specific to equity indices; not tested on other asset classes

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `5` |
| Typical hold time | `1-10 trading days` |
| Expected drawdown profile | `~22% (card expected_dd_pct)` |
| Regime preference | `mean-revert (uptrend regime only)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** `book`
**Pointer:** Howard Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9644_bandy-tps-bounded-mr-index.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 total budget per trade, split 1/3 per unit (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent, split 1/3 per unit |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%), split 1/3 per unit |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

**Open questions (per card ambiguity, most-literal reading applied):**
- The card exempts unit-2/3 additions from the news blackout (only unit-1
  must respect it). The framework's news gate is a single pre-entry check
  applied before any Strategy_EntrySignal call and cannot distinguish unit
  index without a corset-violating OnTick rewrite; it is applied uniformly to
  all three units instead. This is strictly more conservative than the card
  (never permits a riskier outcome), so it is treated as an acceptable
  simplification rather than a blocking deviation.
- The vol-chaos filter ("skip new entries if ATR/close in the top 1st
  percentile") is written generically in the card without a unit-1-only
  carve-out (unlike the news filter, which explicitly carves one out). Most
  literal reading: applied to all three units' entries.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-11 | Initial build from card | claude-orchestration-3 router task d9102952 |

# QM5_13020_audnzd-coint-reversion — Strategy Spec

**EA ID:** QM5_13020
**Slug:** `audnzd-coint-reversion`
**Source:** `QM-EDGELAB-FXCOINT-2026-06-09` (see `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`)
**Author of this spec:** Claude
**Last revised:** 2026-07-06

---

## 1. Strategy Logic

Trades a slow-mean/fast-dispersion z-score of the AUDNZD.DWX log price on D1.
Each closed bar computes `log_close = ln(close)`, a slow mean
`SMA(strategy_sma_lookback_d1)` of log_close, and a faster dispersion
`stdev(strategy_stdev_lookback_d1)` of log_close; `z = (log_close - sma_log) /
stdev_log`. A long fires when `z <= -strategy_entry_z`, a short when `z >=
+strategy_entry_z`, one position at a time. Exit is the first of: z crosses
back through `strategy_exit_z` (long closes at `z >= exit_z`, short closes at
`z <= -exit_z`), the ATR(`strategy_atr_period`) x `strategy_atr_sl_mult` hard
stop, or the `strategy_max_hold_days` D1 time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sma_lookback_d1` | 100 | 70-140 | Lookback (D1 bars) for the slow log-price mean. |
| `strategy_stdev_lookback_d1` | 20 | 15-30 | Lookback (D1 bars) for the fast log-price dispersion. |
| `strategy_entry_z` | 2.0 | 1.7-2.3 | Absolute z threshold that triggers a new long/short. |
| `strategy_exit_z` | 0.0 | 0.0-0.4 | Deadband around zero for the mean-reversion exit. |
| `strategy_atr_period` | 14 | 10-20 | ATR period used for the hard stop distance. |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | ATR multiple for the hard stop distance. |
| `strategy_max_hold_days` | 30 | 20-45 | Time stop, in D1 bars since entry. |
| `strategy_max_spread_points` | 80 | 50-120 | Entries skipped when spread exceeds this (points). |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_*, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `AUDNZD.DWX` — the sole surviving cointegrated pair from the internal
  cross-asset FX cointegration screen (AUD/NZD commodity-currency twins);
  card mandates single-symbol only.

**Explicitly NOT for:**
- Any other FX cross — the card is explicitly `single_symbol_only: true`;
  no other pair carries this screen's cointegration evidence.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` (default, `_Symbol`/`PERIOD_D1` chart-native) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (card estimate 10-15) |
| Typical hold time | days to weeks, bounded by 30-bar time stop |
| Expected drawdown profile | expected_dd_pct 15%; ATR hard stop bounds each trade |
| Regime preference | mean-revert (two-sigma log-price stretches) |
| Win rate target (qualitative) | medium — expected_pf 1.12 |

---

## 6. Source Citation

**Source ID:** `QM-EDGELAB-FXCOINT-2026-06-09`
**Source type:** internal research (supplemented by academic journal)
**Pointer:** `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`; Engle &
Granger (1987), Econometrica 55(2), https://www.jstor.org/stable/1913236
**R1–R4 verdict (Q00):** all PASS per
`artifacts/cards_approved/QM5_13020_audnzd-coint-reversion.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | 1,500 NZD per trade (roughly USD 1,000) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

Q02 tester repair note: this AUDNZD strategy is run with `tester_currency=NZD`
and `tester_deposit=150000` in the farm work-item payload. The 2026-07-07 Q02
infra failure was not missing AUDNZD history; MT5 synchronized AUDNZD and began
real-tick D1 testing, then aborted while trying to download the native `NZDUSD`
conversion leg for USD account reporting. Quote-currency tester accounting
matches the existing FX-basket repair pattern and avoids that conversion path.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-06 | Initial build from card | dcb017fd-8b18-441d-bdc0-4059550c4be9 |
| v1.1 | 2026-07-09 | Q02 infra repair | Use NZD tester accounting / 1,500 NZD fixed risk to avoid native NZDUSD conversion-history timeout. |

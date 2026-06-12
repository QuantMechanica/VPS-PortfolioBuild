# Own-Data Studies H3-H5: Intraday Session Structure

**Author:** Claude · **Date:** 2026-06-12 · **Task:** 648ffc09
**Script:** `D:/QM/reports/research/h3_h4_study.py`
**Outputs:** `D:/QM/reports/research/h3_ndx_hourly_structure.csv`, `D:/QM/reports/research/h4_gdaxi_xetra_drift.csv`

---

## Pre-registered hypotheses and thresholds

Pre-registered before data inspection.

| H | Hypothesis | Instrument | Pre-registered direction |
|---|---|---|---|
| H3 | NDX has stable intra-session return structure 2018-2026 | NDX.DWX H1 | Stable slots with consistent DEV/OOS sign and OOS Sharpe > 0.5 |
| H4 | GDAXI drifts between Xetra cash close and US close, conditioned on Xetra session sign | GDAXI.DWX H1 | Trend continuation after UP Xetra |
| H5 | XAU Asia-range contraction predicts London directional expansion | XAUUSD M30/H1 | DATA BLOCKED — see below |

**Tradeable threshold (pre-registered):** OOS net Sharpe > 0.5 AND same sign as DEV.
**DEV period:** bars with date < 2023-01-01
**OOS period:** bars with date >= 2023-01-01

### H1 proxy note

The task specification called for M30 granularity. M30 data is not present in T_Export.
H3 and H4 are run with H1 bars, yielding 2-hour effective slots instead of 30-minute windows.
Results are directionally indicative; M30 would halve the slot width and potentially surface
finer intra-hour structure not visible at H1. All results below are explicitly flagged as H1 proxy.

### Broker time conversion

UTC epoch timestamps in CSV. Broker time = UTC+2 outside US DST, UTC+3 during US DST.
US DST = second Sunday in March to first Sunday in November.
Conversion applied bar-by-bar; dates assigned at broker time.

---

## H3: NDX Hourly Intra-Session Structure (H1 proxy)

**Data:** NDX.DWX_H1.csv · 40,065 bars · 2018-07-02 to 2026-04-24 (UTC)
**DEV bars:** ~24,000 · **OOS bars:** ~16,000

### Per-hour mean return table (key hours)

Selected hours for focus analysis. Full table in `h3_ndx_hourly_structure.csv`.

| Broker hour | DEV n | DEV mean% | DEV t-stat | OOS n | OOS mean% | OOS t-stat | OOS Sharpe | Notes |
|---|---|---|---|---|---|---|---|---|
| 05:00 | 902 | +0.008% | 1.29 | 850 | +0.010% | 2.16 | 1.175 | Pre-market / Asia-close |
| 08:00 | 902 | +0.004% | 0.97 | 849 | +0.004% | 1.17 | 0.638 | Pre-US open |
| 10:00 | 902 | **+0.011%** | **2.94** | 849 | -0.002% | -0.47 | -0.255 | DEV-only signal |
| 19:00 | 902 | +0.009% | 0.53 | 849 | +0.006% | 0.44 | 0.238 | NY lunch proxy |
| 20:00 | 901 | -0.002% | -0.15 | 847 | +0.002% | 0.14 | 0.075 | NY lunch proxy |
| **21:00** | **901** | **-0.010%** | **-0.72** | **848** | **+0.024%** | **2.20** | **1.200** | Power hour proxy |
| 22:00 | 891 | -0.012% | -0.99 | 836 | +0.011% | 1.13 | 0.618 | US close |

### Strategy: long NDX at power hour (broker 21:00) — H1 proxy

Entering at the open of the 21:00 H1 bar, exiting at bar close. One position per bar.

| Metric | DEV (2018–2022) | OOS (2023–2026) |
|---|---|---|
| N bars | 901 | 848 |
| Mean return | -0.0101% | +0.0245% |
| Std dev | 0.4246% | 0.3239% |
| t-stat vs zero | -0.72 | **2.20** |
| Annualized Sharpe | -0.378 | **1.200** |

**Sign reversal DEV → OOS:** DEV mean is negative (-0.010%), OOS mean is positive (+0.024%).
Pre-registered rule: requires same sign in both periods. **Verdict: DEAD.**

### NY lunch proxy (broker 19:00–20:00 combined)

| Split | Sharpe |
|---|---|
| DEV | 0.110 |
| OOS | 0.155 |

Both positive but well below 0.5 threshold. **Verdict: INCONCLUSIVE.**

### H3 verdict table

| Signal | DEV Sharpe | OOS Sharpe | OOS t-stat | Same sign | Verdict |
|---|---|---|---|---|---|
| Power hour (21:00) | -0.378 | 1.200 | 2.20 | NO | **DEAD** |
| NY lunch (19:00-20:00) | 0.110 | 0.155 | ~0.40 | YES | **INCONCLUSIVE** |
| NDX hourly structure (all hours) | No consistent stable hour | — | — | — | **DEAD** |

**H3 action: NO CARD.** The power-hour OOS signal is strong (t=2.20, Sharpe=1.20) but fails
the pre-registered same-sign rule — it represents a genuine regime change (bear→bull shift
post-2023) rather than a stable structural edge. The DEV period (2018–2022) included two
significant bear markets that suppressed the power-hour mean.

---

## H4: GDAXI Xetra-Close Drift (H1 proxy)

**Data:** GDAXI.DWX_H1.csv · 38,015 bars · 2018-07-02 to 2026-04-24 (UTC)
**Trading-day sample:** 1,980 days total (1,146 DEV + 834 OOS)

### Methodology

- Xetra session return: cumulative H1 bar returns from broker 09:00 to Xetra-close bar (inclusive)
  - Xetra-close bar: broker hour 17 when not US DST (GMT+2); broker hour 18 when US DST (GMT+3)
  - CET = broker time; Xetra 17:30 CET ≈ broker 17:00 H1 bar (non-DST), broker 18:00 (DST)
- Drift return: cumulative H1 bar returns from (Xetra-close+1) through broker 21:00 (US-close proxy)
- Conditioning: classify day as UP if Xetra session return >= 0, DOWN if < 0
- Strategy: long GDAXI during drift window on UP Xetra days

### Results

#### DEV (2018–2022), N=1,146 days (593 UP, 553 DOWN)

| Condition | N days | Mean drift% | Std dev% | t-stat | Annualized Sharpe |
|---|---|---|---|---|---|
| All days (unconditional) | 1,146 | +0.003% | 0.493% | 0.18 | 0.086 |
| After UP Xetra | 593 | +0.001% | 0.546% | 0.04 | 0.025 |
| After DOWN Xetra | 553 | +0.006% | 0.436% | 0.22 | 0.146 |

#### OOS (2023–2026), N=834 days (449 UP, 385 DOWN)

| Condition | N days | Mean drift% | Std dev% | t-stat | Annualized Sharpe |
|---|---|---|---|---|---|
| All days (unconditional) | 834 | +0.031% | 0.396% | 2.26 | 1.240 |
| After UP Xetra | 449 | +0.036% | 0.379% | 2.01 | **1.502** |
| After DOWN Xetra | 385 | +0.030% | 0.416% | 1.24 | 1.005 |

### Strategy verdict: long GDAXI after positive Xetra session

| Metric | DEV | OOS |
|---|---|---|
| Mean drift | +0.001% | **+0.036%** |
| t-stat | 0.04 | **2.01** |
| Annualized Sharpe | 0.025 | **1.502** |
| Sign consistent | YES (both positive) | — |
| OOS Sharpe > 0.5 | — | YES |

**Pre-registered rule check:** OOS Sharpe > 0.5 (1.502) AND same sign (both positive) = **TRADEABLE by pre-registered criteria.**

### Critical caveat

The DEV Sharpe is near zero (0.025) while OOS Sharpe is 1.502 — a large DEV/OOS divergence.
The unconditional drift also shows Sharpe=1.24 in OOS vs 0.086 in DEV, suggesting the signal
may reflect the post-2023 bull market in European equities rather than a structural structural Xetra-drift
mechanism. The conditioning on Xetra sign adds only modest lift over unconditional (1.502 vs 1.240),
which further suggests a bull-market regime beta rather than a session-structure edge.

**Assessment:** The pre-registered criteria are satisfied, but the DEV/OOS divergence and the
weakness of the conditioning lift warrant caution. This is a marginal BUILD_CARD verdict:
the hypothesis should be tested via a proper backtest with realistic costs before any live
consideration. If the signal is structural rather than regime-specific, it should also
appear in DEV with at least a positive mean — which it does (0.001%), but barely.

### H4 verdict

| Signal | DEV Sharpe | OOS Sharpe | Same sign | Pre-reg pass | Verdict |
|---|---|---|---|---|---|
| After UP Xetra drift | 0.025 | **1.502** | YES | YES | **BUILD_CARD (cautious)** |
| After DOWN Xetra drift | 0.146 | 1.005 | YES | YES | **INCONCLUSIVE** (conditioning adds minimal lift vs unconditional) |
| Unconditional drift | 0.086 | 1.240 | YES | YES | — (no conditioning; included for reference) |

**H4 action: BUILD_CARD for "long GDAXI after positive Xetra session, drift window to US close."**
Card must include the regime-caveat and the DEV weakness as explicit risk annotation.
Down-Xetra result is not recommended for a card — the conditioning adds no meaningful structure
vs unconditional.

---

## H5: XAUUSD M30 Asia-Range Study — DATA BLOCKED

**Status: BLOCKED**

XAUUSD M30 data is not present in T_Export. The T_Export MQL5/Files directory contains
XAUUSD.DWX_D1.csv (D1 only below which XAU data is absent at sub-H1 granularity
useful for Asia-range studies).

**To unblock:** Run `Export_FX_Bars.mq5` on a non-factory terminal (T_Export terminal)
with symbol `XAUUSD.DWX`, timeframe M30, date range 2017-01-01 to present.
Output to `D:/QM/mt5/T_Export/MQL5/Files/XAUUSD.DWX_M30.csv`.
Then re-run H5 study script (to be written; H5 is not implemented in `h3_h4_study.py`).

**H5 hypothesis (on file):**
XAU Asia-range contraction (small H-L range in broker 01:00–09:00 session) predicts
directional expansion in London session (broker 09:00–14:00). Pre-registered direction:
Q1 (smallest Asia range) → larger London absolute move, directional persistence.

**H5 verdict: BLOCKED — NO CARD POSSIBLE UNTIL DATA AVAILABLE.**

---

## Summary verdict table

| H | Sub-hypothesis | DEV Sharpe | OOS Sharpe | Same sign | Verdict | Action |
|---|---|---|---|---|---|---|
| H3 | NDX power hour (21:00) | -0.378 | 1.200 | NO | **DEAD** | No card |
| H3 | NDX NY lunch (19:00-20:00) | 0.110 | 0.155 | YES | **INCONCLUSIVE** | No card |
| H3 | NDX stable hourly structure | — | — | — | **DEAD** | No card |
| H4 | GDAXI after UP Xetra drift | 0.025 | 1.502 | YES | **BUILD_CARD (cautious)** | Card for GDAXI Xetra-drift |
| H4 | GDAXI after DOWN Xetra drift | 0.146 | 1.005 | YES | **INCONCLUSIVE** | No card (no conditioning lift) |
| H5 | XAU Asia-range vs London expansion | — | — | — | **BLOCKED** | Export M30 data first |

---

## Evidence files

| File | Description |
|---|---|
| `D:/QM/reports/research/h3_h4_study.py` | Study script (pure stdlib Python, task 648ffc09) |
| `D:/QM/reports/research/h3_ndx_hourly_structure.csv` | NDX H1 per-broker-hour DEV/OOS stats with Sharpe |
| `D:/QM/reports/research/h4_gdaxi_xetra_drift.csv` | GDAXI day-level Xetra/drift data, 1,980 days |

## Open items

1. **M30 export** — run `Export_FX_Bars.mq5` on T_Export terminal for XAUUSD.DWX at M30
   to unblock H5. Also consider re-running H3/H4 at M30 for finer slot resolution.
2. **GDAXI card** — write strategy card for H4 UP-Xetra drift; annotate with regime-caveat.
   Target: GDAXI.DWX D1 entry signal at Xetra close, hold to US close.
3. **H3 power-hour regime note** — the post-2023 NDX 21:00 shift (DEV=-0.010%, OOS=+0.024%)
   may warrant a regime-aware version of the power-hour strategy if the bull trend context
   can be operationalized. File as research note, not a card.

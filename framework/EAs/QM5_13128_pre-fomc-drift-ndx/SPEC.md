# QM5_13128_pre-fomc-drift-ndx - Strategy Spec

**EA ID:** QM5_13128
**Slug:** pre-fomc-drift-ndx
**Source:** nyfed-sr512-pre-fomc-drift
**Author of this spec:** Claude
**Last revised:** 2026-07-10

---

## 1. Strategy Logic

Event-driven capture of the **Pre-FOMC Announcement Drift** — the documented tendency of US
equity indices to drift up in the ~24 hours before a scheduled FOMC decision. On the trading day
BEFORE each regular FOMC decision, at broker hour 21:00 (~14:00–15:00 ET), the EA opens ONE market
LONG. On the decision day at broker hour 20:00 (~1 hour before the 14:00 ET statement) it closes the
position — **flat before the announcement by design**. A hard stop sits at 2 × the prior completed
D1 ATR(14) as a disaster guard; it is rarely hit. One position at a time; no TP, scaling, averaging,
trailing, grid, or directional bet on the decision itself. FOMC decision dates are a fixed table
(2018–2025) from the official Federal Reserve calendar.

**News handling (load-bearing design choice):** this EA runs with the framework news filter OFF
(`qm_news_temporal = QM_NEWS_TEMPORAL_OFF`, `qm_news_compliance = QM_NEWS_COMPLIANCE_NONE`). The
framework OnTick news gate returns BEFORE the exit logic, so a normal news blackout around the FOMC
time would block the strategy's own scheduled 20:00 exit. The strategy IS event-flat by construction
(it is out of the market before every statement), which is the news discipline for its one event
class — it holds the pre-announcement drift window intentionally, including intervening releases.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H1` | `PERIOD_H1` | Base bar for the 21:00/20:00 time triggers. |
| `strategy_entry_hour` | `21` | `0`–`23` | Broker hour to open the long the day before an FOMC decision. |
| `strategy_exit_hour` | `20` | `0`–`23` | Broker hour to close on the decision day (before the statement). |
| `strategy_atr_period` | `14` | `>= 1` | Daily ATR period for the disaster stop. |
| `strategy_stop_atr_mult` | `2.0` | `> 0` | Daily ATR multiple for the hard stop. |

FOMC decision dates are a compiled-in table (57 dates, 2018-09 … 2025-12), not a tunable input.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq-100 proxy; the pre-FOMC drift is strongest on the rate-sensitive Nasdaq.
  Live-routable custom symbol.

**Validated but weaker / not primary:**
- `WS30.DWX` - Dow proxy; edge present but the early (DEV) window is negative — less rate-sensitive.
- `SP500.DWX` - original research symbol; **backtest-only, NOT live-routable** (broker routes no
  orders), which is why NDX is the deployment vehicle.

**Explicitly NOT for:** symbols outside `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` (ATR only) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~7 (one per regular FOMC decision) |
| Typical hold time | ~24 hours (overnight, one swap) |
| Expected drawdown profile | very low; scheduled flat before every statement |
| Regime preference | event-driven (independent of trend/MR regime) |
| Win rate target (qualitative) | medium-high (~64% on NDX) |

**Low-frequency note:** at ~7 trades/yr this sits below the standard swing floor; it must be judged
under the pooled-OOS low-frequency track (DL-070 / DL-076 PASS_LOWFREQ), not the per-window minimums.

---

## 6. Source Citation

**Source ID:** `nyfed-sr512-pre-fomc-drift`
**Source type:** `academic_paper + official_calendar`
**Pointer:** Lucca & Moench, "The Pre-FOMC Announcement Drift", Federal Reserve Bank of New York
Staff Report 512 (https://www.newyorkfed.org/research/staff_reports/sr512.html). Decision dates from
the official FOMC calendar (https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm).
**R1-R4 verdict (Q00):** PASS — R1 reputable (Federal Reserve research + official calendar),
R2 mechanically specified (fixed times + fixed date table, no parameter search), R3 economic
mechanism documented (pre-announcement risk-premium / uncertainty resolution), R4 out-of-sample
holds (2024-2025 OOS positive on NDX at real cost).

**Research provenance:** ported from `.private/secret_strategy_lab/pre_fomc_flat` (theory-first,
no parameter search, chronological DEV/Validation/OOS). Model-4 real-tick validation on NDX.DWX at
real index commission ($4.4/trade): DEV +$285, Validation +$319, OOS +$221, full +$825, PF 2.41 —
all three windows positive (evidence to be attached under docs/ops/evidence at pipeline entry).

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (small, orthogonal diversifier) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | Framework port of the secret-lab research survivor (SP500->NDX, +real-tick/real-cost) | Claude |

# OpEx Third-Friday Week — Own-Data Index-Level Probe (Task #33)

**Date:** 2026-07-21 · **Agent:** Claude · **Status:** COMPLETE — verdict DEAD x4
**Gates:** SSRN rank-1 card candidate (Stivers & Sun 2013, JBF 37(11), SSRN 1571786 —
"long index into third-Friday week; exit third-Friday close"), per
`docs/research/SSRN_MINING_2026-07-20.md` sequencing item 1: *"gate on task #33
(own-data .DWX index-level probe) first; the published effect is stock-level."*

## Verdict

| Symbol | Gross FULL (bp) | t | Net FULL (bp)¹ | Gross POST-2021 (bp) | t | Net POST-2021 (bp)¹ | **Verdict (OPEX_A)** |
|---|---|---|---|---|---|---|---|
| NDX | −1.12 | −0.03 | −6.51 | +3.34 | +0.07 | −0.93 | **DEAD** |
| SP500 | −20.06 | −0.71 | −34.75 | −5.77 | −0.16 | −17.87 | **DEAD** |
| GDAXI | −9.43 | −0.39 | −14.08 | −6.14 | −0.19 | −10.27 | **DEAD** |
| WS30 | −20.81 | −0.74 | −22.03 | +0.60 | +0.02 | −0.58 | **DEAD** |

¹ Net = gross − per-symbol DXZ commission − 1.0 bp spread allowance; swap NOT included
(unquantifiable from files, see Costs) — inclusion could only make these more negative.

**The SSRN rank-1 card must NOT be drafted.** The index-level effect on our own data is
not merely absent — it is *inverted*: OpEx weeks underperform ordinary weeks on every
symbol (Welch t vs baseline −1.30 / −1.75 / −1.45 / −1.66 for NDX/SP500/GDAXI/WS30,
FULL window), and the "documented underperformance" fourth-Friday week is the *best*
week type instead (see Findings 2–3). Both pre-registered gate clauses fail:
the effect does not survive costs post-2015 (our whole sample is post-2015) and not
post-2021. No symbol reaches PROCEED or PROCEED-THIN; sample sizes (93–96 events FULL,
51–54 post-2021) are above the DATA_INSUFFICIENT floor, so DEAD is an earned verdict,
not a data gap.

This independently corroborates `docs/research/OPEX_WEEK_INDEX_STUDY_2026-06.md`
(2026-06-12, different spec: weekly log-returns, no costs, NDX missing 2020) — same
conclusion under the card's own entry/exit spec, with complete NDX data and a cost
overlay.

## Data — access path used (cheapest working path)

| Symbol | Series used | Coverage | Bars |
|---|---|---|---|
| SP500 | `D:\QM\mt5\T_Export\MQL5\Files\SP500.DWX_D1.csv` (own .DWX D1 export, 2026-06-09) | 2018-07-02..2026-04-24 | 2014 |
| GDAXI | `D:\QM\mt5\T_Export\MQL5\Files\GDAXI.DWX_D1.csv` | 2018-07-02..2026-04-24 | 1981 |
| WS30 | `D:\QM\mt5\T_Export\MQL5\Files\WS30.DWX_D1.csv` | 2018-07-02..2026-04-24 | 2013 |
| NDX | `D:\QM\reports\state\opex_probe_20260721\NDX_dukas_daily.csv` — built by `build_ndx_daily.py` (same dir) from the on-disk Dukascopy tick store `D:\QM\data\dukascopy\USATECHIDXUSD` (47,340 hour files), the source that fed the July-2026 canonical NDX.DWX rebuild | 2018-07-02..2026-07-13 | 2074 |

- Option 1 of the task brief (existing D1 exports) worked for three of four symbols; no
  Dukascopy candle download was needed (option-4 fallback not triggered).
- **NDX exception:** `NDX.DWX_D1.csv` in T_Export is a **pre-rebuild** export (mtime
  2026-06-09) and is missing **all of 2020** (262 weekdays) — the damaged history that
  triggered the July NDX rebuild. It was NOT used as the primary series. The tick-store
  daily rebuild (bid OHLC, broker NY-close days, price = raw/1000 per the validated
  `D:\QM\data\ndx_rebuild_20260719_evidence\convert_bi5.py` conventions) fills 2020 and
  extends to 2026-07-13. Anchor check: 2020-01-02 open 8749.99 vs M1 first close 8750.16
  in `ndx_rebuild_20260719_evidence\validation.json`.
- **Cross-check** (`ndx_crosscheck.py` / `ndx_crosscheck.csv`): 1753 common dates
  2018-07-02..2026-04-24, close-diff median **7.38 bp**, p90 22.19 bp — the two
  independent sources agree. Max 418.62 bp on 2025-04-02 (tariff-announcement after-hours
  session; day-boundary/feed-coverage artifact, not a scale error).
- D1 bars use the Darwinex NY-close convention: a Friday-dated bar closes at NY 17:00,
  so "third-Friday close" is exactly the close of the third-Friday-dated bar.
- Known NDX-series limitation: the rebuild's downloader skipped UTC Sundays, so broker-
  Monday opens are the first tick at/after UTC Monday 00:00 (≈ 02:00–03:00 broker).
  Affects only the Monday-open entry variant (OPEX_B), not Friday closes.

## Spec (pre-registered in `opex_probe.py` header before running)

- **Calendar:** third Friday = 3rd Friday by date arithmetic (15th–21st); fourth Friday
  = +7 days; OpEx week = Monday..third Friday.
- **Holiday rule:** if the target Friday has no bar, exit at the last bar of the week
  (flagged). Holidays that actually mattered: **Good Friday** 2019-04-19, 2022-04-15,
  2025-04-18 (OpEx exit → Thursday, all four symbols). Fourth-week exits shifted in
  Christmas weeks 2020/2021. One data-gap shift: 2025-12 OpEx exit landed on 12-17 for
  SP500/GDAXI/WS30 because 2025-12-18/19 bars are absent from the T_Export series (no
  such holiday; NDX tick store has both days) — flagged, immaterial. Events with <3 bars
  in the week were dropped: 7 total (`dropped_events.log`), all December weeks (GDAXI 4,
  SP500 1, WS30 1 — GDAXI year-end closures dominate).
- **Legs:** OPEX_A entry = prior-Friday close (card primary); OPEX_B entry = Monday
  open; exit = third-Friday close. FOURTH_A/B identical on the fourth-Friday week.
  BASELINE_A/B = all Mon–Fri weeks whose Friday is neither a third nor fourth Friday.
- **Windows:** FULL; PRE2021 (target Friday ≤ 2021-12-31); POST2021 (≥ 2022-01-01,
  the SPY-replication deterioration window); QUAD (Mar/Jun/Sep/Dec) vs NONQUAD.
- **Stats:** n, mean (bp), one-sample t, hit rate, Welch t vs same-style baseline, mean
  and worst intra-week max-drawdown vs entry (min low / entry − 1), per-year table.

## Findings

**1. The card's primary leg is dead everywhere.** OPEX_A gross means are negative on 3
of 4 symbols FULL (NDX −1.12 / SP500 −20.06 / GDAXI −9.43 / WS30 −20.81 bp) with hit
rates 43–47%, and negative net everywhere after commission + 1 bp spread — before swap,
which for a 7-calendar-night hold can only subtract further. Monday-open entry (OPEX_B)
changes nothing (net FULL −3.00 / −35.00 / −6.74 / −21.40 bp). Mean intra-week drawdown
vs entry is ≈ −180 to −220 bp with worst cases −1400 to −1730 bp (COVID March 2020) —
material risk for zero (negative) reward.

**2. The direction is inverted vs the published stock-level effect.** Baseline weeks
earn +33 to +49 bp (FULL); OpEx weeks lose money in every symbol (all Welch t negative).
The underperformance concentrates in **quad-witching months**: OPEX_A QUAD means are
−74.18 bp (SP500), −85.85 bp (WS30), −54.77 bp (GDAXI), −5.34 bp (NDX), vs roughly flat
NONQUAD (+0.98 to +12.17 bp — still below baseline and below costs).

**3. The fourth-Friday week — documented in the literature as weak — is the strongest
week type on our data**, especially post-2021: FOURTH_A post-2021 means +65.93 (NDX,
t 1.67), +65.77 (SP500, t 2.00), +51.58 (WS30, t 1.65), +34.51 bp (GDAXI, t 1.18);
hit rates 58–67%. This matches the WEEK_AFTER observation of the June study (its only
marginal-TRADEABLE thread) and is again *opposite* to the published pattern. It is NOT
part of the rank-1 card and carries its own caveats (t < 2 on 3 of 4, bull-sample
2023–2026, baseline weeks also positive); any pursuit would be a separate hypothesis
through the normal card path, not a salvage of this one.

**4. Post-2021 is less bad but still dead.** The task's decay check: pre-2021 OPEX_A
means −6.86 / −37.41 / −13.42 / −46.82 bp vs post-2021 +3.34 / −5.77 / −6.14 / +0.60 bp
(NDX/SP500/GDAXI/WS30). The two marginally-positive gross post-2021 legs (NDX, WS30) die
under commission + spread, with swap still unpaid. Per-year (`per_year.csv`): 2022 was
the worst OpEx-long year (hit 16.7% on NDX/SP500/WS30); no year-pattern rescues the leg.

**5. Post-2015 clause.** Own-data history starts 2018-07-02 — no pre-2018 own data
exists on this VPS. The entire 7.8-year sample is post-2015, so the gate clause is
answered on 2018–2026: the effect does not survive costs in the modern era. Pre-2018
replication on external data is moot given the sign is wrong on the tradable window.

## Costs used (every number file-sourced or explicitly labeled an assumption)

- **Commission** (`framework/registry/venue_cost_model.json`, DXZ worst-case RT per
  1 lot, contract size 1): NDX $5.50, WS30 $0.70, GDAXI EUR 5.50, SP500 $5.50 — the
  SP500 figure is the model's **upper bound** (tester group unresolved, $0.55–$5.50);
  even at $0 commission SP500 gross is −20 bp, so the bound cannot change the verdict.
  Per-event means over entry notional: NDX 4.39, SP500 13.69, GDAXI 3.65, WS30 0.21 bp.
- **Spread:** 1.0 bp RT allowance (task-brief figure "~1–2 bp"); net also computed at
  2.0 bp in `summary.csv`. `venue_cost_model.json` marks the spread axis OPEN — this is
  an assumption, not a file-sourced rate.
- **Swap:** NOT quantifiable from any file on this VPS — `venue_cost_model.json`
  `open_axes_not_covered.swap` = OPEN with `swap_note: null` for every symbol, and
  `docs/ops/V5_SYMBOL_COMMISSION_SWAP_BASELINE.md` marks all symbols "Pending MT5
  runtime snapshot". Per Hard Rules no value was invented. Leg A holds ≈7 calendar
  nights (incl. weekend triple-swap), leg B ≈4 — a strictly negative unquantified add-on
  that only deepens the DEAD verdicts.

## Evidence files

| Path | Content |
|---|---|
| `D:\QM\reports\state\opex_probe_20260721\opex_probe.py` | Probe script, pre-registered spec + verdict rule in header |
| `D:\QM\reports\state\opex_probe_20260721\build_ndx_daily.py` | NDX daily rebuild from tick store |
| `D:\QM\reports\state\opex_probe_20260721\NDX_dukas_daily.csv` | NDX daily series (2074 bars) |
| `D:\QM\reports\state\opex_probe_20260721\ndx_crosscheck.py` / `ndx_crosscheck.csv` | Source-agreement check (median 7.38 bp) |
| `D:\QM\reports\state\opex_probe_20260721\summary.csv` | All symbol × leg × window stats + cost columns |
| `D:\QM\reports\state\opex_probe_20260721\verdicts.csv` | DEAD x4 (OPEX_A) |
| `D:\QM\reports\state\opex_probe_20260721\per_year.csv` | Per-year OPEX_A / FOURTH_A breakdown |
| `D:\QM\reports\state\opex_probe_20260721\events_{NDX,SP500,GDAXI,WS30}.csv` | Every event: dates, prices, returns, drawdown, flags |
| `D:\QM\reports\state\opex_probe_20260721\baseline_weeks_{SYM}.csv` | Baseline week returns |
| `D:\QM\reports\state\opex_probe_20260721\dropped_events.log` | 7 dropped December weeks |

## Recommended next step

Mark SSRN rank-1 (Stivers-Sun OpEx) **CLOSED — DO NOT DRAFT** in the Cohort-4 drip and
promote rank 2 (Etula Dash-for-Cash TOM variant) to the head of the drafting queue. The
fourth-Friday-week strength is already on record via the June study's WEEK_AFTER thread;
if it is ever pursued, it needs a fresh hypothesis card with DL-083 marginal-contribution
scrutiny (calendar-family correlation with 20004/TOM), not a rebadge of this one.

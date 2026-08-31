# WTI EIA Negative-News Five-Minute Drift — Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and one-slot magic allocation, one branch-only non-live build, strict
Q01 validation, and one paced Q02 enqueue only while the governed whole-host
CPU ceiling remains clear. This decision does not authorize a manual tester
run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requires one new, structural,
low-frequency commodity exposure outside the certified XAU/SP500/NDX/XNG
book, reputable-source criteria, a `RISK_FIXED` backtest preset, committed
non-duplicate work, and one Q02 enqueue. It excludes live and portfolio-gate
work.

## Candidate Identity

- proposed slug: `wti-eia-negdrift-m1`
- proposed strategy ID: `ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026_S01`
- proposed source ID: `ARMSTRONG-EIA-WTI-NEGDRIFT-M1-2026`
- host / slot 0: exact `XTIUSD.DWX`, M1
- decision clock: first executable tick of the 10:31 New York M1 bar on a
  standard Wednesday
- signal: the completed 10:30-10:31 New York M1 bar closes strictly below its
  open; this is a price-reaction proxy for negative WPSR news
- participation: short only; positive or flat first-minute reaction consumes
  the date flat
- lifecycle: close at the first tick at or after 10:35 New York, with a
  ten-minute stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Complete-Read Boundary

The bounded source material reviewed completely for this decision is:

1. Armstrong, Will J.; Cardella, Laura; and Sabah, Nasim (2021),
   "Information shocks, disagreement, and drift," *Journal of Financial
   Economics* 140(3), 916-940, DOI
   `10.1016/j.jfineco.2021.02.002`. The complete accessible publisher landing
   record, abstract, introduction, result synopsis, and section synopsis were
   reviewed at
   `https://www.sciencedirect.com/science/article/pii/S0304405X21000350`.
   The publisher page identifies the weekly EIA WPSR crude-oil-futures event,
   says positive information is reflected within one-half second, and reports
   that negative information continues drifting in the news direction for
   five minutes. It attributes the asymmetry to disagreement and buying
   pressure that impedes price discovery after negative news.
2. The complete public SSRN metadata and abstract for the 65-page predecessor,
   SSRN 3314221, reviewed at
   `https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3314221`. It confirms
   authorship, setting, negative-only five-minute drift, mechanism, and the
   short-sale-constraint-free crude-oil futures market.
3. The complete current official EIA "Weekly Petroleum Status Report
   Schedule" page, reviewed at
   `https://www.eia.gov/petroleum/supply/weekly/schedule.php`. It states that
   the standard release is Wednesday after 10:30 a.m. Eastern and identifies
   holiday weeks whose release day/time differs.
4. `strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md`, 80 lines,
   SHA-256
   `0F7232F876636F27B23BC5A1828176B5906C368C2D4B3BBD3769E686D18A1566`.
   It preserves the approved internal event identity, standard-clock, native
   data, and no-external-runtime-feed boundary.

The journal full text and SSRN PDF were not available through the retrieval
route. This approval therefore uses only the complete bounded material above
and does not import inaccessible tables, coefficients, subsamples, costs, or
robustness claims.

The paper supports the observed negative-news directional drift, five-minute
window, asymmetry, and crude-oil futures setting. It does not test the exact
Darwinex CFD, a first-M1-bar sign as a news classifier, entry at 10:31, the
remaining four-minute hold, fixed-dollar sizing, an ATR stop, spread cap,
standard-Wednesday holiday proxy, or the present portfolio. Those are
explicit QM translation choices.

## Locked Mechanic

At the first executable tick of the `XTIUSD.DWX` M1 bar labeled 10:31 New York
on a standard Wednesday:

1. Repair malformed owned exposure, then persist the New York `yyyymmdd`
   attempt before history, signal, news, spread, quote, ATR, sizing, or order
   submission. Never retry that date.
2. Require the immediately preceding completed M1 bar to be same-date and
   labeled exactly 10:30 New York, with a current 10:31 label and a 60-second
   broker-time separation. Reject missing, displaced, invalid, or nonfinite
   OHLC.
3. Define the price-reaction proxy exactly:

   ```text
   negative_proxy = release_close < release_open
   signal = SELL when negative_proxy is true
            FLAT otherwise
   ```

   Equality is flat. No magnitude threshold, inventory value, consensus,
   surprise, API, calendar file, futures curve, volume, open interest, or
   trained classifier is allowed.
4. Enter one market short at current bid only during the first 30 seconds of
   the 10:31 New York bar. Apply exactly `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Attach one frozen
   `3.0 * ATR(20,M1)` broker hard stop, no target, and reject crossed or
   negative-spread quotes plus a genuinely positive spread above 1,500
   points.
5. Close at the first tick at or after 10:35 New York on the entry date. A
   New York date change and ten elapsed minutes are fail-safe repairs only.
   Close duplicate, wrong-symbol, invalid-side, wrong-magic, or stopless owned
   exposure immediately.
6. Lock both current news axes and legacy news mode OFF. Framework Friday
   close remains enabled but is not the planned lifecycle.

This is a weekly decision rule despite its M1 host. It has at most one
consumed attempt and one position per standard Wednesday.

## Reputable-Source Criteria

- R1 `PASS_WITH_PRICE_PROXY_AND_ACCESS_BOUNDARY`: a named-author,
  DOI-bearing, peer-reviewed JFE paper supplies the negative-only five-minute
  crude-futures drift. The complete accessible publisher/abstract material
  was reviewed; the full article was not retrieved. First-minute CFD sign is
  a disclosed QM proxy, not the authors' news-surprise variable.
- R2 `PASS`: exact New York weekday/time, completed bar, strict sign, one-shot
  attempt, short direction, fixed risk, frozen stop, spread cap, and exit are
  mechanical and locked.
- R3 `PASS_WITH_CFD_MICROSTRUCTURE_HOLIDAY_AND_TIME_MAPPING_RISK`: the governed
  history registry records `XTIUSD.DWX` M1 coverage for 2017-2025, and native
  MT5 state supplies every runtime input. Futures/CFD basis, one-minute
  aggregation, DST, spreads, gaps, and holiday-shift false labels remain
  binding.
- R4 `PASS`: timestamps, completed OHLC, strict comparisons, ATR risk control,
  quotes, positions, deals, and persistent terminal state only; no trained
  output, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_eia_negdrift_m1_preallocation_dedup_20260831.json`,
SHA-256
`0421E9B96BF80F46439170824993450BB335BAE6297DE933CEFADF416090133C`,
is clean across 4,741 registry rows, 1,379 cards, and 45 Strategy Wiki nodes.

Manual event-family review finds no existing negative-only first-minute
10:31-10:35 continuation rule:

- `QM5_1121_unger-crude-inventory-release` is a pre-release M5 pending-order
  breakout.
- `QM5_10319_eia-oil-momo` reads a completed M30 release-window sign, enters
  hours later, trades both directions, and closes after 30 minutes.
- `QM5_12579_eia-wti-aftershock`, `QM5_12590_eia-wti-wpsr-fade`, and
  `QM5_12988_xti-eia-inventory-momentum` use D1 event bars or multiweek state.
- `QM5_20133_wti-wpsr-pb` and `QM5_20134_wti-wpsr-fail` wait for two completed
  M30 bars and decide at 11:30 using pullback/failure geometry.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_STANDARD_WEDNESDAY_NEGATIVE_FIRST_MINUTE_REACTION_SHORT_DRIFT`.

## Kill And Safety Boundary

Expected cadence is approximately 15-30 completed positions per full year,
derived only from the weekly maximum and a roughly half-sign proxy prior; it
is not a performance result. Q02 retires on zero positions, fewer than five
in any full scored year, nonpositive governed economics, wrong clock/bar,
long entry, positive/flat proxy entry, repeat entry, missing stop, wrong exit,
nondeterminism, invalid risk mode, or insufficient M1 history. Failure may
not be rescued by changing direction, window, classifier, stop, or lifecycle.

The WTI event carrier targets exposure outside the certified
XAU/SP500/NDX/XNG set, but it does not prove low correlation. Only unchanged
Q09 may measure realized portfolio overlap.

This approval excludes a manual backtest; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or
T_Live manifests; portfolio-gate changes; portfolio admission; decorrelation
claims; and correlation waivers. Q02 may be enqueued once only after strict
Q01 and only if the governed whole-host CPU check remains below the ceiling.

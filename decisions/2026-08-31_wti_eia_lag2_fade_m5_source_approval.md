# WTI EIA Five-Minute Lag-2 Reaction Fade — Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and one-slot magic allocation, one branch-only non-live build, strict
Q01 validation, and one paced Q02 enqueue only while the governed whole-host
CPU ceiling remains clear. This decision does not authorize a manual tester
run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requires one new structural,
low-frequency commodity exposure outside the certified XAU/SP500/NDX/XNG
book, reputable-source criteria, a `RISK_FIXED` backtest preset, committed
non-duplicate work, and one Q02 enqueue. It excludes live and portfolio-gate
work.

## Candidate Identity

- proposed slug: `wti-eia-lag2-fade-m5`
- proposed strategy ID: `YE-KARALI-EIA-WTI-LAG2-FADE-M5-2026_S01`
- proposed source ID: `YE-KARALI-EIA-WTI-LAG2-FADE-M5-2026`
- host / slot 0: exact `XTIUSD.DWX`, M5
- decision clock: first executable tick of the 10:35 New York M5 bar on a
  standard Wednesday
- signal: fade the strict sign of the completed 10:30-10:35 New York M5
  release-reaction bar
- participation: short after a positive reaction, long after a negative
  reaction, and flat after equality
- lifecycle: close at the first tick at or after 10:45 New York, with a
  twenty-minute stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Complete-Read Boundary

The bounded source material reviewed completely for this decision is:

1. Ye, Shiyu, and Karali, Berna (2016), "The informational content of
   inventory announcements: Intraday evidence from crude oil futures
   market," *Energy Economics* 59, 349-364, DOI
   `10.1016/j.eneco.2016.08.011`. The complete accessible publisher landing
   record, abstract, introduction, method/result snippets, return-model
   snippet, and conclusion snippet were reviewed at
   `https://www.sciencedirect.com/science/article/pii/S0140988316302110`.
   The accessible record identifies five-minute returns, reports negative
   first- and second-lag return coefficients, describes immediate return and
   positive volatility responses to inventory shocks, and says EIA effects
   last longer than API effects.
2. Ye and Karali (2015), the complete two-page AAEA/WAEA conference poster
   for the same study, retrieved from AgEcon Search at
   `https://ageconsearch.umn.edu/record/205595/files/AAEA_Ye_Karali-2015.pdf`.
   The downloaded public PDF has SHA-256
   `C4112A7AB46E8CF6EB792409504E5DF164C8F4F667DEF22142C54FBBA3E047F3`.
   It identifies the EIA as the main market mover, the normal 10:30 Eastern
   clock, intraday return jumps around releases, and inverse return response
   to unexpected inventory changes.
3. The complete current official EIA "Weekly Petroleum Status Report
   Schedule" page, reviewed at
   `https://www.eia.gov/petroleum/supply/weekly/schedule.php`. It states that
   the standard release is Wednesday after 10:30 a.m. Eastern and identifies
   holiday weeks whose release day/time differs.
4. `strategy-seeds/sources/EIA-WTI-WPSR-INTRADAY-2026/source.md`, reviewed
   completely. It preserves the governed WPSR event identity, standard-clock
   convention, native-data boundary, and standard-Wednesday holiday proxy.

The paywalled journal PDF was not retrieved. This approval therefore uses
only the complete bounded material above and does not import inaccessible
tables, subsamples, coefficients beyond the publisher-visible return-model
snippet, transaction-cost results, or robustness claims.

The paper supports five-minute return modeling, negative short-lag serial
correlation, and a recurring EIA crude-futures information event. It does not
test this exact Darwinex CFD, define a completed M5 CFD bar as an inventory
surprise, prescribe entry at 10:35, prove that the two reported negative lags
are monetizable after spreads, prescribe a ten-minute hold, fixed-dollar
sizing, an ATR stop, or the present portfolio. Those are explicit QM
translation choices.

## Locked Mechanic

At the first executable tick of the `XTIUSD.DWX` M5 bar labeled 10:35 New
York on a standard Wednesday:

1. Repair malformed owned exposure, then persist the New York `yyyymmdd`
   attempt before history, signal, news, spread, quote, ATR, sizing, or order
   submission. Never retry that date.
2. Require the immediately preceding completed M5 bar to be same-date and
   labeled exactly 10:30 New York, with a current 10:35 label and a 300-second
   broker-time separation. Reject missing, displaced, invalid, or nonfinite
   OHLC.
3. Define the price-reaction fade exactly:

   ```text
   signal = SELL when release_close > release_open
            BUY  when release_close < release_open
            FLAT otherwise
   ```

   Equality is flat. No magnitude threshold, inventory value, consensus,
   surprise, API input, product-inventory decomposition, calendar file,
   futures curve, volume, open interest, or trained classifier is allowed.
4. Enter one market position only during the first 30 seconds of the 10:35
   New York bar. Apply exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`. Attach one frozen `3.0 * ATR(20,M5)` broker hard
   stop, no target, and reject crossed or negative-spread quotes plus a
   genuinely positive spread above 1,500 points.
5. Close at the first tick at or after 10:45 New York on the entry date. A
   New York date change and twenty elapsed minutes are fail-safe repairs
   only. Close duplicate, wrong-symbol, wrong-side, wrong-magic, or stopless
   owned exposure immediately.
6. Lock both current news axes and legacy news mode OFF. Framework Friday
   close remains enabled but is not the planned lifecycle.

This is a weekly decision rule despite its M5 host. It has at most one
consumed attempt and one position per standard Wednesday.

## Reputable-Source Criteria

- R1 `PASS_WITH_TRANSLATION_AND_ACCESS_BOUNDARY`: a named-author,
  DOI-bearing, peer-reviewed *Energy Economics* paper supplies the five-minute
  return model and negative first/second return lags. The complete accessible
  publisher material and complete authors' conference poster were reviewed;
  the paywalled journal PDF was not retrieved. The M5 CFD sign fade is a
  disclosed QM test, not the authors' inventory-surprise trade.
- R2 `PASS`: exact New York weekday/time, completed bar, strict opposite
  sign, one-shot attempt, fixed risk, frozen stop, spread cap, and timed exit
  are mechanical and locked.
- R3 `PASS_WITH_CFD_MICROSTRUCTURE_HOLIDAY_AND_TIME_MAPPING_RISK`: the
  governed history registry records `XTIUSD.DWX` M5 coverage for 2017-2025 on
  T1-T10, and native MT5 state supplies every runtime input. Futures/CFD
  basis, aggregation, DST, spreads, gaps, and holiday-shift false labels
  remain binding.
- R4 `PASS`: timestamps, completed OHLC, strict comparisons, ATR risk
  control, quotes, positions, deals, and persistent terminal state only; no
  trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_eia_lag2_fade_m5_preallocation_dedup_20260831.json`,
SHA-256
`856BD94846ADB0A82E31D6FD899F69DE285AA410511E2AF006FB7C764278BF44`,
found no exact identity across 4,742 registry rows, 1,380 cards, and 45
Strategy Wiki nodes. Its generic `fade` token produced fuzzy name-only hits,
which require manual resolution rather than automatic acceptance.

Manual event-family review finds no existing standard-Wednesday 10:35-10:45
opposite-sign M5 reaction rule:

- `QM5_1121_unger-crude-inventory-release` places an M5 pre-release pending
  straddle and can trigger inside the release window.
- `QM5_10319_eia-oil-momo` follows the completed 10:30-11:00 M30 sign only in
  the final regular-session window; it does not fade at 10:35.
- `QM5_12590_eia-wti-wpsr-fade` fades a stretched completed D1 event bar on a
  later daily decision.
- `QM5_20134_wti-wpsr-fail` waits for a separate 11:00-11:30 M30 deep reclaim
  before fading at 11:30.
- `QM5_41242_wti-eia-negdrift-m1` is negative-only, follows rather than fades
  the first M1 response, and exits at 10:35 before this candidate can enter.
- The fuzzy `wti-mon-fade`, `wti-tue-fade`, `wti-nov-fade`, `wti-dec-fade`,
  and `xng-thu-fade` names use different calendar, carrier, bar state, entry,
  and lifecycle mechanics.

Verdict:
`SEMANTICALLY_DISTINCT_WTI_STANDARD_WEDNESDAY_COMPLETED_M5_REACTION_LAG2_FADE`.

## Kill And Safety Boundary

Expected cadence is approximately 35-48 completed positions per full year,
derived only from the weekly maximum and a low equality/missing-bar prior; it
is not a performance result. Q02 retires on zero positions, fewer than five
in any full scored year, nonpositive governed economics, wrong clock/bar,
same-side entry, repeat entry, missing stop, wrong exit, nondeterminism,
invalid risk mode, or insufficient M5 history. Failure may not be rescued by
changing direction, adding a magnitude threshold, widening the window,
changing the stop, or extending the lifecycle.

The WTI event carrier targets exposure outside the certified
XAU/SP500/NDX/XNG set, but it does not prove low correlation. Only unchanged
Q09 may measure realized portfolio overlap.

This approval excludes a manual backtest; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or
T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after strict Q01 and only if the governed whole-host CPU check remains below
the ceiling.

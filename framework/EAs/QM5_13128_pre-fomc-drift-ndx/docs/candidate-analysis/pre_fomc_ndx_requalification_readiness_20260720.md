# QM5_13128 NDX requalification readiness audit — 2026-07-20

## Decision

`BLOCKED_NOT_RELEASED`. This is a setup/lineage adjudication, not a strategy
failure and not tester authority. No MT5 tester, optimization, market-data
simulation, source repair, parameter change, gate change, promotion or deploy
was performed by this audit.

The exact machine-readable decision is
`pre_fomc_ndx_requalification_blocked_contract_20260720.json`, SHA-256
`dcdabba12eab90bea7c1b93e5442fe926b1345b8ecbe47802cabad3723a3ff43`.

## What is valid

The economic hypothesis has a primary source: the New York Fed documents U.S.
equity excess returns in the twenty-four hours before scheduled FOMC
announcements ([Staff Report 512](https://www.newyorkfed.org/research/staff_reports/sr512.html)).
More recent New York Fed evidence reports that the post-2011 effect through June
2018 was concentrated on press-conference days
([Liberty Street Economics](https://libertystreeteconomics.newyorkfed.org/2018/11/the-pre-fomc-announcement-drift-more-recent-evidence/)).

The 65 date values currently compiled into the MQ5 are correct regular-meeting
second-day dates for the selected 2018 sample and 2019-2026. In particular, the
eight 2026 values are January 28, March 18, April 29, June 17, July 29,
September 16, October 28 and December 9. They match the
[Federal Reserve FOMC calendars](https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm).
The Board's schedule release also confirms that statements are issued at 2:00
p.m. ET on the second meeting day
([Federal Reserve release](https://www.federalreserve.gov/newsevents/pressreleases/monetary20240809a.htm)).

Darwinex documents a New-York-close MetaTrader clock, UTC+3 during US daylight
saving time and UTC+2 otherwise
([Darwinex Zero documentation](https://www.darwinexzero.com/docs/de/time-in-darwinex-metatrader-terminals)).
On that convention, broker 21:00 is 14:00 ET and broker 20:00 is 13:00 ET. The
intended entry and pre-statement exit therefore have a coherent theoretical
mapping. This does **not** replace the missing empirical NDX.DWX timestamp/DST
validation.

## Why requalification cannot start

1. The approved Card is frozen at 57 events through 2025. The current MQ5 and
   SPEC contain 65 events through 2026. Correct calendar values do not authorize
   an unapproved Card expansion.
2. The canonical repository EX5 and live EX5 both hash to
   `364867a9fe8d58478ade5526aad19deb377a35b313cfdac29763bb2eb82d273b`.
   That binary was rebuilt before the calendar/coverage source changes. A later
   compile snapshot matches the current MQ5 and compiled cleanly, but its EX5
   hash `60818ee1ad6c728a23fee908733b9f5f3fb3d4e5958a67f7dac5f54ed518fec8`
   is non-canonical and unqualified.
3. The backtest set is still `build_hash=pending` and
   `card_defaults_source=not_found`. It specifies fixed USD 1,000 risk; the
   as-live preset instead specifies 1% risk. Their economics are not
   interchangeable.
4. The execution registry already blocks promotion for Card/calendar conflict,
   unqualified Friday-close override and unrequalified binary.
5. The symbol matrix records `FAIL_tail_mid_bars` for NDX.DWX. The referenced
   Wave-0 DST report is absent. The history-range registry begins NDX H1/D1 in
   2021 while existing tests request data back to 2018.
6. Data gap B overlaps the 2023-12-13 FOMC opportunity. The frozen truth HCC and
   the later, larger NDX HCC have different hashes. The larger file is only a
   repair candidate; it cannot be substituted without provenance, continuity
   checks and two independent reproductions.
7. Commission is known ($2.75 per side per NDX lot on DXZ Index 3), but current
   spread parity, swap and adverse slippage remain open. The schema-v1 receipt
   used a degraded forex commission fallback for NDX.

## Historical evidence disposition

The original SP500.DWX research was a theory-first Model-1 survivor, but it is
not NDX Model-4 or current-binary qualification. The NDX evidence is encouraging
only descriptively: the schema-v1 as-live run reproduced 56 Q08 signals; Q08 is
`FAIL_SOFT` with low sample, invalid PBO and 11/12 seasonal coverage; the old Q09
reported `PASS_PORTFOLIO`, 56 trades and maximum correlation about 0.196 to its
then-current book. Every one of those outcomes has been opened, Q08 includes
opened parameter-neighborhood runs, and the portfolio context is stale.

A recursive inventory found 117 matching `tester.ini` files: all 117 are
Model 4; four end in 2020 and 113 end in 2025. None ends in 2026. Therefore
2018-2025 is not a new holdout, and elapsed January-June 2026 meetings are not
pristine OOS. The four meetings still in the future at the freeze boundary
(July 29, September 16, October 28, December 9) are prospectively fenced, but
four observations cannot qualify standalone merit.

At the observed 1% live-risk identity, the diagnostic 2017-2025 receipt made
roughly 4.3% total before full cost certification. This sleeve cannot credibly
be represented as an engine that by itself passes a 10% FTMO objective; its only
plausible role is a low-frequency orthogonal diversifier after full synchronized
portfolio qualification.

## Release path

The frozen contract lists ten conjunctive gates, in order: approved Card;
semantic synchronization; canonical binary identity; full NDX DST validation;
continuous hash-bound data; two identical serial reproductions; complete cost
axes; frozen low-frequency familywise statistics; synchronized current-book
FTMO portfolio replay; and normal release authority. No gate may be loosened,
and the missing 2023-12-13 opportunity may not be deleted after seeing outcomes.

## Outcome-blind verification

The validator hashes files and checks only structural content. It does not parse
trade metrics or expose any tester execution surface.

```powershell
python framework\EAs\QM5_13128_pre-fomc-drift-ndx\tools\candidate_analysis\audit_pre_fomc_ndx_requalification.py --check
python -m pytest -q framework\EAs\QM5_13128_pre-fomc-drift-ndx\tests\candidate_analysis\test_audit_pre_fomc_ndx_requalification.py
```

Observed results before commit:

- validator: `PASS_BLOCKED_STATE_REPRODUCED`, 22/22 source bindings, 65 calendar
  dates, four future events, `tester_started=false`;
- tests: `10 passed in 1.28s`;
- validator SHA-256:
  `543cace3b4666ced230cdd6b205f19c3aa09a43fb54acefdda46c504cd26ad1d`;
- test SHA-256:
  `48eaa1dadac2d16e3f2033aa1be7dceda0e78c7e6a254ee2f02a2e0fa2837cc3`.

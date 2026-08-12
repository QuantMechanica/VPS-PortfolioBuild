# FTMO Execution Progress - 2026-07-09

## Objective

Move the factory toward EAs that can survive and pass an FTMO 2-Step Challenge
without weakening the OWNER-ratified DXZ gates or touching live AutoTrading.

## Actions completed

### Factory frontier

- Applied the existing reversible FTMO intraday priority to 1,006 pending Q02
  work items: M1, M5, M15, M30, and explicit scalper/rapidfire/ORB sleeves.
- Fixed the prioritizer so `updated_at` remains UTC ISO instead of Unix epoch.
  Normalized 996 timestamps written by the first run; priorities and verdicts
  were unchanged.
- `QM5_13036` NDX/GDAXI M15 is now in the priority track.

### New strategy and EA supply

- The approved factory already built and compiled `QM5_13067` through
  `QM5_13099`. Most are new energy, copper, natural-gas, calendar, relative-
  spread, and commodity-regime strategies.
- The majority are D1 and below the FTMO target-density objective. They remain
  useful orthogonal DXZ research but are not relabeled as FTMO candidates.
- Routed a new depth-first Research task against the active CEO-approved
  Miffre-Rallis commodity-momentum paper. The task requires complete-source
  extraction, exact citations, at least 25 expected trades/year for the FTMO
  track, bounded risk, and DRAFT cards only.
- Research task: `a36bc970-4aac-4751-a8f5-0e0e4b5a227e`, assigned to Gemini.

### FTMO rule and simulation hardening

- Corrected the closed-daily simulator so idle calendar days do not satisfy
  the four trading-day minimum and the target must still be held on the fourth
  actual trading day.
- Corrected the intraday-MAE simulator to group entry and close timestamps by
  `Europe/Prague` CE(S)T days and count actual trade-open days.
- Added a fail-closed FTMO qualification inventory. `CHALLENGE_READY` requires:
  clean build and active magic, hard PASS in Q04-Q08 and Q10, all evidence paths
  present, at least 50 trades, and a fresh stream containing `entry_time` and
  `mae_acct` for every trade.
- The OWNER-ratified Q08 soft-fail portfolio-rescue path remains intact, but its
  candidates can never become FTMO challenge-ready through that label alone.

Artifacts:

- `artifacts/ftmo_qualification_full_2026-07-09.json`
- `artifacts/ftmo_qualification_leads_2026-07-09.json`
- `docs/ops/evidence/pre_sunday_prep_2026-07-09.md`

Current strict inventory: 104 advanced EA/symbol candidates, 0
`CHALLENGE_READY`, 3 `RESEARCH_LEAD`, and 101 `NOT_QUALIFIED`. Before the
QM5_12969 requeue there were four leads; it is now correctly represented as a
pending Q08 retest rather than retaining its archived soft-fail status.

### Q08 neighborhood blocker

The neighborhood support runner had two systemic defects:

1. The aggregator allowed eight parameters but killed the runner after 30
   minutes, although up to 17 MT5 runs can be required.
2. Numeric perturbation treated time fields as ordinary numbers, producing
   invalid values such as `02:00 -> 01:80`.

Fixes:

- Excluded time/hour/minute/HHMM parameters from numeric perturbation.
- Defaulted automatic neighborhood coverage to two real numeric parameters.
- Derived the outer timeout from the number of baseline/perturbation runs.
- Passed the exact baseline setfile and bound explicitly from `farmctl`.

`QM5_12969 / USDJPY.DWX` was requeued through the canonical Q08 work-item path:
work item `74a089c5-194d-466f-ba0f-0536fdf32641`. The previous evidence root was
archived by `farmctl`; the retest is pending worker capacity.

### Trial and live safety evidence

- FTMO Free Trial equity remains 94,015.80, or -5.9842% from the 100,000 start.
- Pulse verdict is now `WARN`, not the previous misleading `OK`.
- Latest account-equity snapshot was about 885 minutes old at the check.
- Kill-switch rollout proof: `KS_DAY_ANCHOR_SET` 0/12 and `KS_BOOK_TAG_SET` 0/12.
- Logged broker-request lower bound for the broker day: 217, including 206
  modifications.
- Corrected MAE run has only 4/12 fresh sleeves. The partial 60-day Phase-1
  result is 18.9% pass and is explicitly non-authoritative until all 12 are
  refreshed.
- Routed the eight-sleeve MAE/report refresh as task
  `eda8c9c9-6de0-4ca5-8a40-f6fb054a62ba`, assigned to Codex. It forbids live
  writes and fabricated Q07 lineage.

## Current gate

**Paid FTMO Challenge remains NO-GO.**

The next admissible transition requires all of the following:

1. QM5_12969 Q08 retest completes with real neighborhood evidence.
2. A hard Q08 PASS cascades into Q10 PASS; a soft fail remains research only.
3. All proposed book sleeves have fresh CE(S)T intraday-MAE streams.
4. The rebuilt binaries emit day-anchor and book-tag proof for every magic.
5. A fresh Free Trial passes without loss-budget warning, stale equity
   snapshots, request-rate warning, or live-monitor gaps.

No live terminal, AutoTrading state, position, or deployed preset was changed.

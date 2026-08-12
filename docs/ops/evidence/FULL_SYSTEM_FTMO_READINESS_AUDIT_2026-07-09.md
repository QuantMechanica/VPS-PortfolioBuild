# Full System and FTMO Readiness Audit - 2026-07-09

## Decision

**Paid FTMO Challenge: NO-GO.**

The factory is running and both observed terminals are up, but the current
evidence chain does not certify any EA or portfolio for a paid challenge. The
main blockers are pipeline-contract drift, false-positive Q02 gate semantics,
a Q08-soft-fail to Q12 bypass, and an FTMO model that cannot yet reproduce the
official intraday equity and CE(S)T daily-loss rules. The active FTMO account is
a Free Trial, not a paid Challenge, and is down 5.9842% from its 100,000 start.

No terminal, AutoTrading setting, open position, work item, queue row, or live
setfile was changed during this audit.

## Scope and evidence

Snapshot window: 2026-07-09, approximately 20:00-20:30 UTC.

- Repository contract and code: `CLAUDE.md`, `tools/strategy_farm/phase_ids.py`,
  `tools/strategy_farm/farmctl.py`, `tools/strategy_farm/portfolio/`, and the
  phase runners under `framework/scripts/`.
- Factory truth: `D:/QM/strategy_farm/state/farm_state.sqlite`, `farmctl status`,
  `farmctl health`, worker-process inspection, report and evidence paths.
- DXZ live truth: T_Live terminal journals, EA JSONL logs, presets, and
  `D:/QM/reports/state/live_book_pulse.json`.
- FTMO truth: FTMO Free Trial terminal journal, EA JSONL logs, current deploy
  decisions, kill-switch source and rollout notes, and
  `D:/QM/reports/state/ftmo_trial_pulse.json`.
- Official rule baseline: FTMO Trading Objectives, 2-Step Challenge, permitted
  strategies, and Forbidden Trading Practices pages, checked on 2026-07-09.

Account numbers and order tickets are intentionally omitted from this report.

## Executive state

| Area | State | Audit verdict |
|---|---:|---|
| Factory workers | 7 expected workers healthy; no duplicate worker processes | RUNNING |
| Work queue | about 4,811 pending and 7 active | RUNNING WITH DEBT |
| EA inventory | 2,370 EAs; 95,172 work items | LARGE, NOT CERTIFIED |
| Q08 | zero `PASS` verdicts in the current database | BLOCKED |
| Portfolio | 24 `PASS_PORTFOLIO`; 22 Q12-ready rows / 19 unique EAs | LABEL NOT TRUSTWORTHY |
| DXZ T_Live | 15/15 charts and presets match; equity 101,807.20 | PROFITABLE, MONITOR ALARM |
| FTMO Free Trial | terminal up; 12/12 magics; equity 94,015.80 | MATERIAL DRAWDOWN |
| Paid FTMO readiness | no end-to-end compliant evidence chain | NO-GO |

## Critical findings

### P0 - The pipeline has no single authoritative phase contract

Three incompatible phase definitions coexist:

1. `CLAUDE.md` describes a current Q00-Q14 evidence path.
2. `tools/strategy_farm/phase_ids.py` describes Q00-Q13 with different meanings.
3. `docs/ops/PIPELINE_PHASE_ID_MAP.md` and `PIPELINE_PHASE_SPEC.md` describe an
   older Q00-Q14 sequence.

The actual runner map in `farmctl.py` is different again: Q02 baseline, Q03
sweep, Q04 walk-forward, Q05/Q06 stress, Q07 multi-seed, Q08 Davey, an
unimplemented/defaulted Q09 news step, Q09_PORTFOLIO, and Q10 confirmation.
Phase labels therefore cannot be treated as proof without inspecting the exact
runner and evidence payload.

### P0 - Q02 `PASS` does not mean the financial baseline gate passed

The current Q02 verdict derivation checks execution, real-tick mode, run count,
and a low effective trade minimum. It does not enforce the advertised profit
factor, net-profit, and drawdown thresholds. The subsequent Q02-to-Q03 promoter
only requires positive net profit.

Recent Q02 `PASS` examples include 15-23 trade runs with profit factors below
1.0. Across current Q02 passes, 1,504 rows have fewer than 50 trades and 674 are
in the 5-24 trade bucket. A harness-complete result is being represented and
consumed as a strategy-gate pass.

Required correction: persist separate `RUN_OK` and `GATE_PASS` concepts, enforce
the declared financial thresholds in one authoritative gate, and re-evaluate
all downstream admissions produced by the current semantics.

### P0 - Current Q12-ready candidates bypass required evidence

`farmctl.py` explicitly skips/defaults the independent Q09 news phase. Q08
`FAIL_SOFT` rows can be promoted directly into Q09_PORTFOLIO, and portfolio
passes are then admitted directly as `Q12_REVIEW_READY`. They do not require a
Q08 `PASS`, independent news evidence, or the Q10 full-history confirmation.

The database contained zero Q08 passes at audit time, yet 22 portfolio rows were
Q12-ready. These are research leads, not deployable certifications.

### P0 - FTMO pass probabilities are not rule-complete

`prop_challenge_sim.py` uses closed daily PnL. It cannot see intraday floating
loss, commissions/swaps during the day, or the official CE(S)T midnight-balance
calculation. Its default 60-day horizon is an analysis horizon, while the
current FTMO 2-Step has unlimited time. Absolute pass percentages from this
model must not authorize a paid challenge.

Two deterministic false-pass bugs were corrected during this audit:

- idle calendar days no longer count as FTMO minimum trading days;
- a target reached early must still be met when the minimum trading-day
  requirement is satisfied.

Remaining requirement: use order-open trading-day markers and intraday equity/
MAE paths aligned to 00:00 CE(S)T. Closed-daily simulation can remain only as a
fast lower-fidelity screen.

### P0 - The active FTMO Free Trial lacks the current kill-switch contract

The deployed Round25 binaries predate the current day-anchor, persistent halt,
and book-scoped halt rollout. Logs do not show the new day-anchor/book-tag
initialization, and the external 8% drawdown-floor flag is not armed. The
broker-day reset differs from FTMO CE(S)T, so the old daily anchor can reset one
hour early during the present offset combination.

This is unacceptable for a paid account even if the strategy edge were valid.

## Factory and backtest line

### Throughput and outcomes

| Phase | Representative state |
|---|---|
| Q02 | 18,813 done, 44,709 failed, about 4,806 pending |
| Q03 | 11,418 done, 510 failed |
| Q04 | 13,116 done, 86 failed |
| Q05 | 579 done, 5 failed |
| Q06 | 190 done, 1 failed |
| Q07 | 155 done, 3 failed |
| Q08 | 219 done, 37 failed; no PASS verdict |
| Q09_PORTFOLIO | 66 done: 24 pass, 30 fail, 12 need-more-data |

The raw volume is high, but the attrition figures combine genuine strategy
failure, infrastructure failure, invalid artifacts, and conflicting gate
semantics. They are not a clean funnel conversion report.

### Data-quality and operations findings

- Q02 has about 819 excess exact pending duplicates across 160 logical groups,
  approximately 17% of the pending Q02 queue.
- The scheduled repair task has been disabled since 2026-06-01. A deduplication
  repair exists, but it is therefore not maintaining the queue.
- Health reports only recent infrastructure failures and can report the
  graveyard as clear while historical `INFRA_FAIL` volume remains very large.
- Extreme profit factors are often driven by one or two trades. Current
  quarantine coverage does not make all such database metrics decision-safe.
- Many metric rows lack at least one core PF/trades/drawdown field, especially
  in Q04 and Q08.
- Three Q02 work items carry future timestamps dated 2027-01-01.
- Disk pressure is operationally material: D: fell below 40 GB during the day,
  was purged, and then consumed space rapidly again.

Required operational work: re-enable or replace scheduled repair under an
approved runbook, deduplicate pending Q02 atomically, add future-timestamp and
duplicate-queue health checks, and report lifetime as well as recent infra debt.

## Live accounts

### DXZ T_Live

- Terminal process is running.
- The corrected parser verifies all 15 deployed presets against all 15 loaded
  charts: 15 OK, zero missing, zero extra, zero timeframe mismatches.
- Latest observed equity is 101,807.20 from a 100,000 reference (+1.8072%).
- Latest terminal sync reported two open positions.
- The pulse is `ALARM` because the journal was about 300 minutes stale while
  positions were open. Sixteen disconnect events were observed in the retained
  journal window.
- All current sleeves log `KS_BASELINE_ABSENT`; this requires interpretation
  against the pending kill-switch rollout before it can be accepted as normal.

Immediate operator action is investigation of connectivity/journal freshness.
This audit did not restart the terminal or toggle AutoTrading.

### FTMO Free Trial Round25

- This is a 14-day Free Trial, not a paid Challenge.
- Terminal process is running and all 12 expected magics are present.
- Latest observed equity is 94,015.80: -5.9842% from the initial 100,000.
- The worst retained snapshot was approximately -6.094%.
- The previous monitor incorrectly reported `OK` just below its 6% warning
  threshold. It now reports a warning from 5% total drawdown and reserves
  `ALARM` for an actual FTMO limit breach.
- The 2026-07-09 broker-day logs contain a lower bound of 217 framework trade
  requests: 206 modifications, 7 opens, and 4 closes. This is below FTMO's
  2,000-request forbidden-practice threshold but is concentrated in one sleeve
  and must be rate-limited before paid deployment.
- The Round25 package uses risk scale 9.0 and can place roughly 9% of initial
  capital at simultaneous full-stop risk. That is incompatible with the
  observed drawdown and a survival-first unlimited-time challenge design.
- Per-EA `day_pnl` snapshots cannot attribute account PnL to individual EAs;
  each snapshot observes the account-wide value at a different tick time.

## Official FTMO baseline

For the current 2-Step evaluation, the audited target contract is:

- Challenge profit target 10%; Verification target 5%.
- Maximum daily loss 5% of initial capital. The calculation includes floating
  PnL, commissions, and swaps and uses the CE(S)T midnight balance rule.
- Maximum loss 10% of initial capital.
- Minimum four trading days per phase and unlimited evaluation time.
- EAs are allowed when the trading is legitimate and replicable.
- More than 2,000 server requests per day is listed as forbidden hyperactivity.

Authoritative sources:

- https://ftmo.com/en/trading-objectives/
- https://ftmo.com/en/2-step-challenge/
- https://ftmo.com/faq/which-instruments-can-i-trade-and-what-strategies-am-i-allowed-to-use/
- https://ftmo.com/en/forbidden-trading-practices/

The 2-Step program is the appropriate target. The 1-Step program's tighter and
trailing constraints are not the current design target.

## EA disposition

No EA is approved for a paid FTMO Challenge. The following are re-certification
leads only:

| EA / sleeve | Evidence | Disposition |
|---|---|---|
| QM5_12969 / USDJPY M30 | Q04-Q07: about 300 trades, PF 1.49, DD 2.33%; Q08 soft failures are limited, but neighborhood evidence is missing | PRIMARY RE-CERTIFICATION LEAD |
| QM5_11179 / XAUUSD M5 | Q05/Q06: about 738 trades, PF 1.22, DD 2.56% | COMPLETE Q07/Q08 AFTER INFRA FAILURE |
| QM5_13013 / NDX M15 | PF about 1.36 on only 69 trades; seasonal, chop, regime, and neighborhood weaknesses | BACKUP / MORE DATA |
| QM5_10715 / USDJPY M15 | 1,466 trades, but PF about 1.11 and PF falls to about 0.735 after removing the top 5% of trades | REJECT UNLESS EDGE IS IMPROVED |
| QM5_9929 / SP500 M30 | Q08 hard fail | REJECT |

QM5_12969 is the best current lead because it is simple, same-day, source-based,
and comparatively stable through Q07. It still needs neighborhood evidence,
the missing news and full-history checks, FTMO-symbol cost validation, CE(S)T
intraday equity replay, and a fresh Free Trial. Its Tokyo-fix timing also needs
an explicit news-policy decision for the eventual funded-account type.

## Required path to a challenge-ready EA book

1. Keep paid FTMO deployment frozen. Treat all current Q12-ready rows as
   uncertified leads.
2. Approve one phase contract and make code, database status names, dashboards,
   and docs derive from it.
3. Split execution validity from financial gate verdicts at Q02, then invalidate
   or re-grade downstream rows admitted under the old rule.
4. Remove exact pending duplicates and add automated invariants for duplicates,
   future timestamps, missing metrics, and evidence completeness.
5. Require a hard robustness pass, independent news test, full-history
   confirmation, and portfolio admission. No soft-fail bypass may produce an
   owner-review-ready state.
6. Re-certify QM5_12969 first, then QM5_11179 and QM5_13013 only if their missing
   evidence passes. Use the actual FTMO symbol specification and cost model.
7. Replace closed-daily authorization with CE(S)T-aligned intraday equity/MAE
   replay and real trading-day markers. A finite horizon may be reported as a
   service objective, never as an FTMO rule.
8. Build a low-correlation book around survival: initial design range 0.25-0.50%
   risk per independent idea, 1.5-2.0% internal daily stop, 6-7% internal total
   stop, and explicit correlated-exposure caps. Final numbers require the new
   evidence; they are not approvals.
9. Deploy the current persistent, CE(S)T-anchored, book-scoped kill switch and
   prove restart persistence, day reset, simultaneous-sleeve halt, and recovery
   procedure with AutoTrading under OWNER control.
10. Pass a fresh 14-day Free Trial with no rule-limit warning, no monitor gap
    while exposed, server requests below the warning budget, and reconciled
    broker-report attribution before requesting paid-Challenge approval.

## Changes made by this audit

- Fixed `live_book_pulse.py` preset parsing for deployment suffixes; live dry
  verification is now 15/15 exact matches.
- Fixed two FTMO simulator false-pass conditions and added the conservative
  trading-day count to phase results.
- Corrected FTMO pulse warning/alarm semantics and added a logged server-request
  lower-bound metric.
- Added regression tests. Targeted result: 30 passed.

These changes improve evidence quality. They do not make the current portfolio
challenge-ready and do not guarantee that any EA will pass an FTMO Challenge.

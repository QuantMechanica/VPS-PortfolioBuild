# GBPUSD Weekend Tail Fade - Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded structural FX Strategy Card,
deterministic EA-ID and one-slot magic allocation, one branch-only non-live
build, strict Q01 validation, and one paced Q02 enqueue only while the
governed whole-host CPU ceiling remains clear. This decision does not
authorize a manual tester run.

Authority: the current explicit OWNER paced-fleet mission on branch
`agents/board-advisor`. The mission prioritizes forex and market-neutral
diversity after the approved build backlog and diverse Q02-Q03 infrastructure
queue are exhausted. It requires reputable-source criteria, low frequency, a
`RISK_FIXED` backtest preset, committed non-duplicate work, and one Q02
handoff. It forbids live, AutoTrading, portfolio-gate, `T_Live`, and deploy-
manifest mutations.

## Candidate identity

- proposed slug: `gbpusd-weekend-tail-fade`
- proposed strategy ID: `AI-CODEX-GBP-WGAP-TAIL-20260831_S01`
- source ID: `AI-CODEX-GBP-WGAP-TAIL-20260831`
- host / slot 0: exact `GBPUSD.DWX`, D1
- clock: first executable tick of a broker-Monday D1 bar immediately after a
  completed broker-Friday D1 bar
- signal: current log weekend gap strictly outside the sixth-smallest or
  sixth-largest order statistic of exactly 52 prior completed weekend gaps
- lifecycle: one consumed weekly attempt, contrarian side, fixed risk, frozen
  ATR stop, framework Friday close, and seven-day stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Single governed source and evidence

The single R1 lineage is the AI-originated governed packet
`strategy-seeds/sources/AI-CODEX-GBP-WGAP-TAIL-20260831/source.md`.
Its supporting peer-reviewed record is Dao, McGroarty, and Urquhart (2016),
*Journal of Multinational Financial Management* 37-38, 158-167, DOI
`10.1016/j.mulfin.2016.11.001`. The complete 22-page postprint was read from
Nottingham Trent University's repository and content-bound at SHA-256
`46AD758FA8341903A4B03203152F8AE05D21B344356467BB3F0B62A1976E8642`.

The paper supplies GBP/USD membership, the Friday-close/Monday-open gap, an
empirical-tail signal family, contrarian direction, and a Friday-close
horizon. It uses five years and 5% tails in its out-of-sample strategy. The
fixed 52-week and 10% tail translation is a pre-result QM choice made because
registered `.DWX` history starts in 2017 and the source-exact five-year
warm-up would starve the 2018-2022 Q02 window. Retrieval evidence is
`strategy-seeds/sources/AI-CODEX-GBP-WGAP-TAIL-20260831/retrieval_route_20260831.json`.

## Locked mechanic

At the first executable D1 tick of each genuine broker Monday:

1. Persist the normalized broker-week key before all fallible checks. Never
   retry a consumed week.
2. Require the preceding completed bar to be broker Friday. Compute
   `g_now=log(MondayOpen/FridayClose)` from positive finite prices.
3. Reconstruct exactly 52 earlier Friday-close/Monday-open log gaps from a
   bounded D1 buffer. Reject missing, nonchronological, non-Friday/Monday, or
   nonpositive observations. Exclude the current gap.
4. Sort ascending. Use index 5 as the lower tail and index 46 as the upper
   tail. Buy strictly below the lower threshold and sell strictly above the
   upper threshold; ties stay flat.
5. Open at most one exact-GBPUSD slot-0 position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5*ATR(20,D1)` broker hard stop, no target, and a 50-point entry spread
   ceiling.
6. Close through the framework Friday 21:00 broker boundary. Flatten any
   survivor after seven calendar days or before a later week can enter.
7. Both news axes remain off for the source-lineage baseline. News cannot
   block an exit.

The expected activity prior is approximately 8-11 positions per full post-
warm-up year. It is a rank-density expectation, not a market result.

## Reputable-source criteria

- R1 `PASS_WITH_AI_SYNTHESIS_BOUNDARY`: one durable AI source and a complete
  peer-reviewed institutional postprint with explicit GBPUSD membership.
- R2 `PASS`: clock, gap identity, exact history membership, sorting, indexes,
  strict comparison, side, consumed attempt, risk, stop, spread, and exits are
  deterministic and locked.
- R3 `PASS_WITH_BROKER_DAY_PROXY_RISK`: registered native GBPUSD D1 history
  covers 2017-2026; broker-D1 versus source-fix timing, holidays, DST, gaps,
  financing, and CFD/spot basis remain falsification risks.
- R4 `PASS`: deterministic native time/OHLC arithmetic and execution state
  only; no ML, trained output, banned signal indicator, external runtime feed,
  grid, martingale, scale-in, or pyramid.

## Non-duplicate decision

The corrected-root receipt
`artifacts/qm5_gbpusd_weekend_tail_fade_preallocation_dedup_20260831.json`
scanned 4,751 registry rows, 1,389 cards, and 45 Strategy Wiki nodes and
returned `CLEAN` with no exact or fuzzy match.

Manual review distinguishes the nearest gap families: `QM5_10013` uses a
fixed ATR gap threshold, a fill target, and a 24-hour/Tuesday exit;
`QM5_12494` scans every M1 broker-day boundary and holds five bars;
`QM5_11458` enters from Friday breakout structure before Monday; and
`QM5_10946` enters late Friday in continuation direction. None compares the
current GBPUSD weekend gap with a trailing 52-gap empirical distribution and
holds a contrarian trade through Friday.

Verdict:
`DISTINCT_GBPUSD_WEEKLY_CURRENT_GAP_VERSUS_TRAILING_52_WEEK_EMPIRICAL_TAIL_CONTRARIAN_FRIDAY_EXIT`.

## Kill and safety boundary

Q02 retires the unchanged baseline on zero positions, fewer than five
positions in any full post-warm-up year, nonpositive governed economics,
future leakage, wrong Friday/Monday membership, wrong order statistics or
tail indexes, threshold-tie entry, missing stop, invalid risk mode, malformed
lifecycle, or nondeterminism. There is no after-result parameter rescue.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or live
manifests; portfolio-gate changes; portfolio admission; decorrelation claims;
and correlation waivers.

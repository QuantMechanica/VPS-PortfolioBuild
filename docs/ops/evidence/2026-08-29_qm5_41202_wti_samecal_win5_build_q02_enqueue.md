# QM5_41202 WTI same-calendar Winsor sleeve — build and Q02 enqueue

Date: 2026-08-29

Branch: `agents/board-advisor`

Outcome: **COMPILE_OK; exactly one XTIUSD.DWX D1 Q02 row enqueued**

## Edge and portfolio role

`QM5_41202_wti-samecal-win5` is a direct-WTI, monthly structural sleeve. At
the first normalized D1 boundary of a month it retrieves the exact completed
same-calendar-month WTI log return from each of years Y-1 through Y-5. It
sorts those five observations, replaces the minimum with the second value and
the maximum with the fourth value, and trades the strict sign of the retained
five-term mean `(2*s1 + s2 + 2*s3) / 5` until the next month boundary.

This adds crude-oil calendar exposure outside the certified XAU, SP500, NDX,
and XNG carriers. It does not assert realized decorrelation; only Q09 may make
that decision.

The repository-wide dedup receipt resolved the expected WTI same-calendar
neighbors as mechanically distinct. Two locked disagreement fixtures separate
this estimator from raw mean, trimmed mean, median, hit rate, signed rank, and
the five-observation central Hodges-Lehmann variant. The durable verdict is
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_EXACT_FIVE_YEAR_SAME_CALENDAR_ONE_TAIL_WINSORIZED_MEAN_SIGN_MONTHLY_RENEWAL`.

## Governance and build

The source packet, source approval, G0 decision, and approved Strategy Card
are committed. The canonical and runtime approved-card copies are byte
identical at SHA-256 `16f426ac...380d6`. EA ID 41202 and magic 412020000 were
allocated through the deterministic registries.

The governed compile row
`8f004130-b8a8-498b-ba38-e157722dca78` was released as a one-item,
source-fresh wave. A resident worker claimed the quiescent T7 slot without
launching `terminal64`, compiled the EA with zero errors and zero warnings,
and completed `COMPILE_OK` with strict build-check PASS. The bound identities
are:

- MQ5 SHA-256: `585b2279...5718c`;
- EX5 SHA-256: `77a1e214...ab70`;
- Q02 setfile SHA-256: `c08ba124...73bc`;
- external governed compile receipt SHA-256: `908630e5...1636`.

The backtest setfile retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. It locks the five-year sample, one-tail Winsorization,
`1e-12` sign band, 3000 D1 history bars, ATR(20) times 3.5 hard stop, 35-day
stale exit, and 1500-point spread ceiling.

## Capacity and Q02 handoff

Immediately before the Q02 transition, five one-second whole-host CPU samples
were 74.5527%, 73.2147%, 71.7834%, 72.5714%, and 76.5650%. Average CPU was
73.7374% and maximum CPU was 76.5650%, both below the governed 97% hard stop.

Recording build task `17407e28-3d17-4794-8494-072396ce971c` inserted exactly
one Q02 v4 work item:

- work item `ef66984a-2402-4fe4-89c7-2f3394891312`;
- `XTIUSD.DWX / D1`;
- priority track, cohort size one;
- custom-history archive admission ACTIVE;
- read back as pending, unclaimed, attempt zero, with no skipped target.

No dispatch tick or tester was launched manually. Resident workers own later
execution.

## Verification and safety

- Reference suite: 11 tests PASS.
- SPEC validation: PASS.
- Strategy Card schema and G0 lints: PASS.
- Build-skill registry/magic/directory guard: PASS.
- MQ5 and setfile guardrails: PASS.
- Governed compile and strict build check: PASS.
- EX5 provenance guard: PASS for QM5_41202 against compile row `8f004130`.
  The whole-index command returned nonzero only because unrelated EX5 paths
  were already staged without receipts; those paths were not changed or
  included in this mission commit.

No portfolio gate, portfolio-admission state, T_Live file, deploy manifest,
AutoTrading state, or live terminal was changed. No certification or
correlation claim is made. The machine-readable receipt is
`artifacts/qm5_41202_build_q02_enqueue_20260829.json`.

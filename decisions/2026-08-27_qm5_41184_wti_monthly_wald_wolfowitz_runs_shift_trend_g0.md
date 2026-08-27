# QM5_41184 WTI Monthly Wald-Wolfowitz Label-Runs Shift Trend — G0 Decision

Date: 2026-08-27

Decision: `APPROVED` at G0 for one branch-only non-live V5 build, strict Q01
validation, independent review, and at most one paced Q02 enqueue under the
source and safety boundary in
`decisions/2026-08-27_wti_monthly_wald_wolfowitz_runs_shift_trend_source_approval.md`.

Authority: the current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor` and committed source approval `fb7ef4580`.

## Approved Identity

- EA ID: `41184`
- slug: `wti-mww-runs-shift-tr`
- strategy ID: `AI-CODEX-WTI-M2RUNS-20260827_S01`
- source ID: `AI-CODEX-WTI-M2RUNS-20260827`
- host/traded symbol: exact `XTIUSD.DWX`, D1, slot 0
- intended magic: `411840000`
- card of record:
  `strategy-seeds/cards/approved/QM5_41184_wti-mww-runs-shift-tr_card.md`

The ID was reserved atomically through `farmctl reserve-ea-ids` after the
source approval and canonical dedup receipt existed. The active registry row
matches the exact slug and strategy identity.

## G0 Gate Findings

### R1 — `PASS_WITH_PUBLIC_METHOD_ACCESS_LIMITATION`

Exactly one canonical source ID identifies the governed AI-originated packet
`strategy-seeds/sources/AI-CODEX-WTI-M2RUNS-20260827/source.md`, SHA-256
`AB4B8ADE3D3E4B4CA1B7AE6D9ADE98DD69AD30BC5D5CEDEC0EC6F9D073795FB6`.
Canonical R1 permits this source class. The Wald-Wolfowitz peer-reviewed
bibliography is metadata-only because the generic reader policy-deferred the
DOI; the complete-read MOP packet supports monthly WTI continuation and WTI
membership only. The exact trade is disclosed synthesis, not extracted
source alpha.

### R2 — `PASS`

The contract fixes one genuine-month decision, exactly ten consecutive
completed month-end closes, fixed old/new blocks of five, strict no ties, one
pooled ascending membership order, exact label-run count, inclusive `R<=6`,
exact block medians, symmetric side, consumed attempt, fixed-dollar risk,
frozen ATR hard stop, spread cap, next-month exit, stale exit, and exposure
repair. There is no p-value, critical table, fallback, optimization, or
result-conditioned rescue.

### R3 — `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`

Registered `XTIUSD.DWX` D1 history, broker time, native symbol metadata,
quotes, ATR, positions, deals, and terminal globals supply every runtime
input. Continuous-CFD roll, basis, financing, label, gap, and history risks
remain explicit.

### R4 — `PASS`

The signal uses stable sorting, comparisons, integer counts, and exact
five-value medians. Runtime has no trained output, prohibited signal
dependency, external feed, grid, martingale, scale-in, pyramid, or
discretionary state.

## Locked Formula And Density

For positive, finite, pairwise-distinct completed-month prices `C[0..9]`:

```text
O = C[0..4]
N = C[5..9]

sort O union N ascending, carrying fixed O/N labels
R = 1 + adjacent label transitions

BUY  iff R <= 6 and median(N) > median(O)
SELL iff R <= 6 and median(N) < median(O)
FLAT otherwise
```

Exact enumeration of `choose(10,5)=252` label assignments produces the run
distribution `2,8,32,48,72,48,32,8,2` for runs two through ten. The inclusive
boundary qualifies 162 assignments, split by label reflection into 81 BUY
and 81 SELL states. This gives a pre-market density prior of 7.7143 decisions
per twelve months, not statistical significance or WTI evidence.

The initial table transcription and `R<=5` boundary were corrected before
compilation, Q01, Q02, or any market-result observation. The one-time
pre-build correction is governed by
`decisions/2026-08-27_qm5_41184_prebuild_density_correction.md`.

## Non-Duplicate Adjudication

The pre-allocation checker returned `CLEAN` across 4,683 registry identities,
1,334 cards, and 45 current-vault Wiki nodes. Receipt:
`artifacts/qm5_wti_mww_runs_shift_tr_preallocation_dedup_20260827.json`,
SHA-256
`88D3A10D84ECB5C876FA9916F24234DA802EDEB8AFA1A8D0805B2EC387EC27B1`.

Manual resolution separates the candidate from:

- `QM5_41182`: chronological median-dichotomy runs;
- `QM5_41183`: maximum signed ECDF count gap;
- `QM5_41176`: sum of every cross-block win;
- `QM5_41172`: variable chronological Pettitt change point; and
- `QM5_12567`: two-day long-only XNG cumulative-RSI pullback.

This rule is invariant to chronology within each fixed block, but not to
adjacency of fixed block labels in pooled price order. None of those EAs has
that state function plus exact five-value block-median direction.

Verdict:
`CLEAN_WTI_MONTHLY_FIXED_FIVE_BY_FIVE_POOLED_LABEL_RUNS_LE6_MEDIAN_DIRECTED_DISTRIBUTION_SHIFT_CONTINUATION`.

## Build Authorization And Boundary

Development may create exactly:

- `framework/EAs/QM5_41184_wti-mww-runs-shift-tr/`;
- one exact `XTIUSD.DWX` D1 `RISK_FIXED` backtest preset;
- one active slot-zero magic row and regenerated resolver mapping; and
- source-aligned pure reference tests, strict compile evidence, independent
  review evidence, and one paced Q02 queue receipt.

The build must use `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, both news axes OFF/NONE, legacy news OFF, Friday close
OFF, a frozen `3.5*ATR(20,D1)` hard stop, and no target. It must consume the
month before every fallible entry gate and close at the next month or
forty-day stale boundary.

Forbidden: manual tester runs; live/demo/shadow/stress/optimization presets;
`T_Live`; AutoTrading; deploy/live manifests; portfolio-gate edits;
portfolio admission; correlation waivers; external runtime data; terminal
control; a second queue row; and claims of profitability, certification, or
decorrelation before governed evidence.

## Kill Conditions

Retire on zero trades, fewer than five completed positions in any full
post-warm-up Q02 year, nonpositive governed economics, any downstream gate
failure, or any endpoint, split, tie, sort, run-count, median, boundary, side,
attempt, risk, stop, lifecycle, repair, or determinism defect. A failure may
not be rescued by changing the sample, boundary, direction, carrier, risk,
hold, or by adding another filter.

Direct WTI exposure adds a crude-oil driver absent from the stated
XAU/SP500/NDX/XNG book, but realized independence is unproven. Unchanged Q09
alone owns portfolio overlap.

# QM5_10347 GBPUSD Q02 infrastructure requalification

Date: 2026-08-13

Branch: `agents/board-advisor`

EA: `QM5_10347_et-donchian210`

Scope: one collision-free, low-frequency forex fallback and append-only Q02
handoff

## Outcome

The guarded current-binary seed created exactly one GBPUSD Q02 successor:

- work item: `12337f0b-734d-4655-9639-f323a300b8fa`;
- symbol / period: `GBPUSD.DWX` / D1;
- initial state: `pending`, attempt 0, unclaimed, with no verdict;
- predecessor preserved: `04e31fb4-c19f-4f08-a81e-b99115e76995`
  (`INFRA_FAIL`); and
- exact open GBPUSD Q02 identities after enqueue: one.

No dispatch or local tester run followed. The paced farm owns claim and
execution.

## Non-duplicate selection

The deterministic relationship audit at `a80493291` accounts for every
relationship in the frozen sign-aware 66-pair cointegration scan. Creating a
new Card, EA, registry allocation, magic row, basket manifest, or setfile from
that scan would therefore duplicate an existing mechanization.

The two requested anchor repairs are not applicable:

- `QM5_12532_AUDNZD_COINTEGRATION_D1` has Q02 PASS and Q04 PASS followed by
  Q05 FAIL;
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1` has Q02 PASS followed by Q04
  FAIL; and
- neither anchor has a current Q02 ONINIT or NO_HISTORY blocker.

The two exact relationships that remained unresolved in the scan audit are
already represented by one current pending logical Q02 row each. Rank 58,
GBPUSD/USDJPY in `QM5_1257`, was priority-tracked in commit `2de3ed729`; rank
65, USDCHF/AUDUSD in `QM5_1156`, was priority-tracked in commit `517701c5f`.
Neither row was duplicated or requeued here.

The mission's existing-forex-card fallback therefore applies. The latest
GBPUSD Q02 row for `QM5_10347` was a real-MT5, terminal pre-execution-binding
run on T3 over 2015-2024. Its stored infrastructure reason is
`NO_REAL_TICKS;INCOMPLETE_RUNS`. Before the new seed there was no pending or
active GBPUSD Q02 row. The same EA's repaired private-history path reached a
real economic `ZERO_TRADES` verdict on EURUSD on 2026-08-11, so this GBPUSD
successor is a bounded execution-path requalification, not an alpha claim.

## Approved structural contract

- The farm-approved Card and EA-local Card are byte-identical, SHA-256
  `3329b9593fff95e5c242ae4172847f122a6c99bfdb61c97b4bd06ac54bffe898`.
- Card metadata is G0 `APPROVED`, with R1-R4 `PASS`.
- Source: Chuck Krug, "Richard D. Donchian System," Elite Trader,
  2009-08-09,
  `https://www.elitetrader.com/et/threads/richard-d-donchian-system.172693/`.
- Mechanics remain the fixed, completed-bar D1 210-day Donchian
  stop-and-reverse system, estimated at four trades per year per symbol.
- No strategy source, parameter, filter, ML behavior, grid, martingale,
  pyramiding, or averaging-down behavior changed in this handoff.
- The existing GBPUSD setfile keeps `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, and registered magic slot 1
  (`10347,GBPUSD.DWX,103470001`).

This is an existing approved legacy Card, not a newly extracted Card. The
current card-schema helper reports the legacy headings (`Mechanik` and
`Initial Risk Profile`) as missing the newer literal `Hypothesis`, `Rules`,
and `Risk` section names. No lint PASS is claimed, and the Card was not edited
or re-approved to manufacture one. The guarded enqueue relied on its durable
farm approval and authenticated existing build.

## Artifact binding

- MQ5 SHA-256:
  `4664dc94f4a5f466c1836bb3cdcb64d2c8642271eaf472c938f83c790fbf7044`.
- EX5 SHA-256:
  `3f99f9a8eec8c22d539633f4358d11b19c271e460c6c53379089439b8a9ae105`.
- GBPUSD setfile SHA-256:
  `10494c9bc2eb55700df229df1927b4f3817ccef15a080bdd6bed1d1baf19c90b`.
- The current binary was strictly rebuilt immediately before this handoff in
  commit `4efee43d3`: 0 compile errors, 0 warnings, and strict build-check PASS.
  This handoff did not rebuild or alter it.
- `farmctl seed-fresh-q02` authenticated the current binary and setfile,
  verified the terminal pre-binding predecessor, preserved the historical
  row, and sealed the hashes above into the successor payload.

## Paced capacity

Immediately before enqueue, at `2026-08-13T00:48:55Z`:

- governed T1-T10 terminals running: 0;
- configured paced launch maximum: 1;
- active Q02 work items: 0;
- three-sample CPU average / maximum: 5.1% / 8.2%; and
- the only `terminal64.exe` process was the unrelated FTMO terminal, which
  was excluded and untouched.

The CPU ceiling was not reached. The append-only seed completed at
`2026-08-13T00:49:16Z`. Readback found exactly one open GBPUSD identity and
the immutable predecessor still `done/INFRA_FAIL`. A second slot scan at
`2026-08-13T00:49:34Z` still found zero governed MT5 terminals.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution, T_Live manifest,
T_Live terminal, AutoTrading state, deploy manifest, live setfile, strategy
mechanic, tester process, or terminal reservation was changed.

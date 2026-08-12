# DXZ-Q8 expansion and repair work order — 2026-07-16

Status: **IN REVIEW / BUILD BLOCKED ON CARD-V2 APPROVALS / ZERO ACTIVE RISK / NO LIVE MUTATION**

Machine-readable work order:
`docs/ops/evidence/dxz_q8_expansion_workorder_20260716.json`

Fail-closed Gate-Matrix:

- `docs/ops/DXZ_Q8_FAIL_CLOSED_GATE_MATRIX_2026-07-16.md`
- `docs/ops/evidence/dxz_q8_fail_closed_gate_matrix_20260716.json`

## Decision

`DXZ-Q6` remains the frozen comparison benchmark. It is not renamed into a
finished return book. The next target is an eight-sleeve qualification candidate,
but the two extra seats are admitted only after their strategy identity is
repaired and freshly qualified:

| Proposed seat | Current evidence | Repair decision | Current state |
|---|---|---|---|
| `12567:XNGUSD.DWX:D1` | economically promising legacy stream | qualify source/Card baseline `entry=35`; quarantine optimized `entry=30` as prospective challenger | `BLOCKED_CARD_V2_RUNTIME_REQUAL` |
| `1556:XAUUSD.DWX:D1` | 53 legacy trades, PF about 1.9 | discard those trades as proof of monthly MOM12; qualify only the predeclared no-weekend policy repair | `BLOCKED_CARD_V2_ABLATION_REQUAL` |

Nothing in this work order changes T_Live, a deployed preset/binary, a chart,
AutoTrading, an order or active risk.

## Why the old Q8 proxy cannot be promoted

The earlier diagnostic Q8 used the as-live `12567/XNG entry=30` stream and the
as-live `1556/XAU` stream. Both are now semantically consumed:

- XNG `30` was selected after a multi-parameter Q12 sweep over the already seen
  2017–2025 history. Approving it after the fact would not create an independent
  test.
- All 53 observed 1556/XAU closes were Friday closes. The monthly entry latch then
  prevented re-entry until the following month. The result measures a repeated
  first-week-of-month exposure, not the Card's continuous 12-month momentum
  long/cash rule.

The previous return/DD comparison remains historical triage only. Q8 performance
must be recomputed from the repaired, frozen variants.

The existing backtests are therefore sufficient for selector triage, defect
diagnosis and ablation planning, but not for Q8 qualification. Both proposed
extensions currently have zero valid two-run Target Pair-Gates, no fresh Gold
chain `Q00` through `Q11`, and no fresh `Q12 = PASS_PORTFOLIO`.

## Backtest inventory and drawdown evidence

The frozen Q6 diagnostic set contains 1,335 closed trades across six sleeves:

| EA | Trades | Diagnostic PF |
|---:|---:|---:|
| 10476 | 299 | 1.260 |
| 10513 | 104 | 1.958 |
| 10706 | 367 | 1.329 |
| 11708 | 178 | 1.320 |
| 12969 | 331 | 1.545 |
| 13128 | 56 | 2.260 |

That is enough to compare sleeves and design falsification tests, but it is not
a synchronized portfolio backtest. It has no common intraday MTM grid, common
margin path or complete floating-PnL/gap reconstruction.

For `12567:XNGUSD.DWX:D1:C_XNG_BASE35_POLICY` there are **zero exact target
tests**. The old base-35/fixed-Friday full-history run has only 58 trades,
PF 1.31 and exit-only DD 2.25%; its three reported OOS folds contain only
3, 3 and 6 trades. Entry 30 has 49 as-live trades and PF 1.715, but was selected
after observing the same history and remains quarantined.

For `1556:XAUUSD.DWX:D1:C_POLICY_REPAIR` there are also **zero exact target
tests**. The 53-trade legacy stream has PF 1.883 (29 trades/PF 1.902 in W1 and
24/PF 1.848 in W2), but all closes use the defective Friday/latch semantics and
therefore cannot estimate the repaired policy.

Cost coverage is not qualification-grade either: commission evidence is full
for 19 of 21 reviewed sleeves, while current-spread parity, swap parity and
slippage certification are absent for the proposed repaired extensions; the
XNG history source reports only about 91% quality.

There is consequently no defensible numeric Q8 drawdown expectation yet. The
Q6 exit-only scaling diagnostic reports about 6.87% DD at 2% total commanded
risk and 10.30% at 3%, but both figures omit floating loss, synchronized margin
and gaps. They are planning proxies, not forecasts. This in-review work order
proposes additional Q8 portfolio gates of synchronized intraday MTM DD <= 9.5%
and stressed worst day <= 4.0%; they are not thresholds from
`PIPELINE_PHASE_SPEC.md`. The result must come from fresh equal-risk Q6/Q8 Q12
evidence, and all canonical Q12 requirements still apply.

## Work package A — sleeve-specific contracts

Q8 promotion identity is exactly `(ea_id, symbol, timeframe, variant_id)`.
All four values are mandatory across Card, contract, manifest, receipts and gate
artifacts. An EA-only row, sibling symbol/timeframe or default-variant fallback
cannot promote. This is mandatory for EA 12567 because XAU and XNG share
source/binary identity but have different parameters, evidence and blockers.

Acceptance:

1. schema and linter reject duplicate four-part promotion keys, not merely
   duplicate EA IDs;
2. adjudicator resolves the exact manifest identity and never falls through to a
   sibling symbol, timeframe or variant;
3. truth-chain and receipts retain all four identity values;
4. legacy EA-only compatibility rows can never satisfy this Q8 promotion gate;
5. regression tests prove that clearing XNG cannot clear XAU or another variant.

## Work package B — isolated repaired-binary requalification

`AS_LIVE_REQUAL` is intentionally pinned to the exact read-only T_Live artifact.
It cannot qualify a newly compiled repair. The required second mode is
`TARGET_BINARY_REQUAL`:

- requires a SHA-bound EX5/set override manifest and a sealed reference;
- stages the artifacts only into a new isolated Base-derived sandbox outside
  T_Live and T1–T10;
- hashes source artifacts and manifest before and after execution;
- is a real requalification mode, not a discovery mode;
- may produce qualification evidence only when every existing identity, cost,
  execution-contract and reproducibility gate passes;
- never copies a candidate into T_Live and never changes deployed state.

Implemented fail-closed tooling now enforces:

- explicit `(ea_id, symbol, timeframe, variant_id)` on every Target manifest
  sleeve; no omitted/default variant is accepted;
- a hash-bound Card contract, Target EX5/set override, sealed reference and five
  cost axes, each bound to the same explicit four-part Target identity;
- `REPRODUCIBILITY_PENDING` for every single Target run, never `QUALIFIED`;
- an immutable summary sidecar and two distinct, serial, isolated Target runs;
- an exact positive `magic_number` from the hash-bound Target manifest, checked
  again against every runtime-log header/payload and every Q08 close row;
- transactional sandbox-only capture of one fresh, stable tester log, with
  append-contaminated pre-state restoration and fail-closed late-writer,
  duplicate-key, identity and ambiguity checks;
- physical Pair-Gate verification of the captured log, parsed telemetry,
  transaction marker and canonical Q08 stream under the exact receipt run
  directory, including hashes and cross-bindings rather than receipt strings
  alone;
- an unchanged Runner SHA-256 chain within each run, receipt-to-summary binding
  and exact runner equality between the two designated runs;
- exact FULL-manifest coverage: every actual manifest sleeve must have one
  canonical receipt at its declared ordinal, with strictly typed counts and no
  omitted or extra identity;
- strict re-opening of the actual Target manifest and verification of the
  designated ordinal, unique four-part sleeve identity and expected Magic;
- semantic reconstruction of every claimed complete Pair axis from the four
  physically opened artifacts; receipt descriptors whose counts or hashes do
  not equal those reconstructed sequences fail closed;
- independent strict re-parsing of the physical runtime log and exact
  re-derivation of telemetry, Magic, entry/exit joins and enriched Q08 rows;
  re-hashing a modified telemetry sidecar cannot replace the raw event stream;
- single-run rejection of any Q08/runtime binding other than the exact current
  `INCOMPLETE` contract with both bijections complete and only the known
  `ENTRY_FILL_PRICE_NOT_EMITTED` gap;
- pair equality for trades, signals, entries, exits, lots, outcome signs, exact
  PnL, daily MTM, `mtm` (the executable key for intraday MTM) and margin;
- downstream Pair binding in adjudication and truth-chain evidence.

The current Q08 runtime stream fully supplies trades, basic signal identity,
lots, outcome signs and exact PnL. The tester log now adds entry side and
requested price, exit events/reasons and partial daily equity observations.
It does **not** prove the actual entry fill price: `ENTRY_ACCEPTED.price` is the
request price. Exit identity closes only when every Q08 closing row has one
unique log join and the manifest-authoritative Magic matches; broker-side or
partial closes otherwise remain incomplete. Daily MTM stays incomplete because
initial and final boundary snapshots are absent, while intraday MTM and
used/free/stressed margin are not emitted at all. The Pair-Gate therefore
remains correctly blocked rather than weakening any axis. Q00/Q01 prerequisites
and the pre-result attempt ledger also remain independent upstream gates; a
Pair artifact cannot replace them.

Focused verification currently stands at **333 passed, 0 failed, 0 skipped** across
identity/lint, Target runner, cost contracts, Pair-Gate, adjudicator,
truth-chain and portfolio-admission regressions. No qualification backtest or
live mutation was performed by this tooling repair.

## Work package C — 12567/XNG

Predeclared variants and rules are in:

- `docs/ops/proposed_issues/2026-07-16_q8_12567_xng_card_v2_approval.md`
- `docs/ops/evidence/dxz_12567_xng_ablation_contract_20260716.json`

The immediate candidate is `C_XNG_BASE35_POLICY`. The optimized threshold-30
variant remains a shadow/prospective challenger even if its historical metrics
are higher.

Development may patch source/presets only after Card-v2, no-weekend session
buffer and framework-helper approvals are hash-bound. The final build must use
explicit current inputs, no inert `qm_filter_*` keys, exact magic slot 2 and a
fresh build/Card/set hash closure.

## Work package D — 1556/XAU

Predeclared variants and rules are in:

- `docs/ops/proposed_issues/2026-07-16_q8_1556_xau_card_v2_approval.md`
- `docs/ops/evidence/dxz_1556_xau_ablation_contract_20260716.json`

The sole promotion candidate is the policy repair:

1. reconstruct the exact completed-month MOM12 state rather than substituting a
   252-D1-bar proxy;
2. flatten by the effective no-weekend cutoff;
3. permit re-entry on the first allowed post-weekend D1 decision when the frozen
   monthly state remains positive;
4. reset and log the ATR stop on each re-entry;
5. include the resulting weekly turnover and costs in the Card and evidence.

The standalone EA and its Master-EA strategy module currently share the defect.
Development may not change the framework module under the standalone build
scope. OWNER must authorize either a synchronized module repair, subject to
Quality-Tech validation, or explicit module exclusion while standalone
qualification proceeds.

## Fixed qualification sequence

1. Keep selector PF 1.10 / 20 trades strictly historical; it allocates research
   effort and cannot satisfy a canonical phase.
2. Pass the non-promotional Early Screen for approvals, exact four-part identity,
   build closure, data segments, calendars, costs and pre-result trial ledger.
3. Earn `Q00 = PASS` on the approved Card-v2 and exact target contract; then
   implement outside T_Live and earn `Q01 = PASS` on the strict target build.
4. Run two designated independent `TARGET_BINARY_REQUAL` sweeps and require the
   fail-closed Pair-Gate on all artifact, trade, MTM, margin and receipt hashes.
5. Continue the same frozen target through `Q02`–`Q11`, so that every canonical
   phase `Q00` through `Q11` has exact Gold `PASS`; no
   `FAIL_SOFT`, `INVALID`, `EDGE_SOFT`, `KEEP_CANDIDATE`, proxy or partial rescue.
6. Certify exactly five cost axes: commission, historical spread provenance and
   coverage, current spread parity, swap, and adverse slippage/gap stress.
7. Require null-intolerant zero weekend exposure, post-cutoff entries, pending
   orders and unresolved market-close retries.
8. Run `Q12` on synchronized intraday MTM and margin and compare frozen Q6 with Q8
   at equal total commanded risk. As additional proposed Q8 portfolio gates—not
   `PIPELINE_PHASE_SPEC.md` thresholds—require DD <= 9.5%, stressed worst day
   <= 4.0% and the 1.0% individual cap; all canonical Q12 requirements also apply.
9. Report empirical drawdown depth/duration/recovery distributions. No bootstrap
   count or threshold is created in this work order.
10. Begin a new prospective shadow period only after the final freeze.
11. Deployment and risk allocation remain a separate OWNER-signed operation.

Any Card, source, include, binary, set, variant, session calendar, cost model or
risk change resets the relevant qualification version.

## Follow-on reserve order

The next bounded work packages are:

1. `10939 GBPUSD H4` only as an alternative to 10706, not an eighth/ninth
   independent seat, because their locked-window correlation exceeds 0.30.
2. `10403 XAUUSD D1` after its Friday-versus-channel-exit ablation.
3. `12778 AUDUSD/EURJPY D1` after basket-horizon, forced-exit and account-currency
   repair.

No reserve is promoted merely to reach a desired strategy count.

## Approval boundary

This work can close tooling and prepare exact decision artifacts now. EA source,
framework-module and qualification-set changes remain blocked until the proposed
Card-v2 execution choices have the required OWNER approval plus Research,
Quality-Business and Quality-Tech reviews. A generic request to improve the book does not
stand in for those explicit semantic signatures.

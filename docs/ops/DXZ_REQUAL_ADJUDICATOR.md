# DXZ23 Requalification Adjudicator

`tools/strategy_farm/dxz_requal_adjudicator.py` turns one completed as-live
requalification summary into a deterministic sleeve decision and a new bound
candidate manifest. It is an evidence/adjudication step only:

- it does not start MT5;
- it does not write to `T_Live`, `T1`-`T10`, or a portable tester;
- it does not copy EX5 or SET files;
- it never declares a candidate deployable;
- it never carries the DRAFT book's historical KPIs into the candidate.

## Schema-v2 qualification contract (2026-07-16)

Only runner schema v2 can qualify a sleeve or book. A qualifying summary must
declare `qualification_mode=AS_LIVE_REQUAL`, bind its requested and effective
window contract, and pass independent non-empty identity and outcome checks
against the selected frozen reference stream. It must also prove native tester
history quality (`100% real ticks` plus non-zero Bars, Ticks and Symbols), bind
certified cost evidence, and show stable start/end hashes for the runner,
source tree, EX5, preset, cost model and any permitted override manifest.

Discovery runs and schema-v1 summaries remain diagnostic evidence only. A
technically successful receipt whose costs are `COST_UNCERTIFIED` is never
eligible for a bound candidate.

### Five-axis cost evidence is semantic, not self-attested

A manifest-level `PASS`, prose assertion, methodology string, arbitrary JSON
file or matching file hash is not cost certification. Each of the five axes
must bind an immutable structured JSON artifact of type
`DXZ_EXECUTION_COST_AXIS_EVIDENCE`, schema 1, with its own canonical
`artifact_payload_sha256` and adjacent `.sha256` sidecar. The artifact binds the
source-manifest SHA, exact EA/`.DWX` symbol/timeframe identities, exact
requested/effective evaluation window and a UTC validity interval. The allowed
evidence types are fixed in runner code, one per axis:

- `DXZ_COMMISSION_TRADE_REPLAY_V1`;
- `MT5_REAL_TICK_SPREAD_REPLAY_V1`;
- `DXZ_CURRENT_BROKER_SPREAD_PARITY_V1`;
- `DXZ_CURRENT_BROKER_SWAP_PARITY_V1`;
- `DXZ_ADVERSE_SLIPPAGE_STRESS_V1`.

The runner validates results and scenarios, not their claimed conclusion.
Current-spread evidence requires at least 100 samples per covered sleeve at
quantile 0.95 or above; swap requires at least five observation days, both
LONG and SHORT and triple rollover; slippage requires at least 30 samples plus
both adverse-quantile and gap stress. Applied values may not be below observed
adverse values, and zero/negative measurements fail. Current spread and swap
artifacts may be valid for no more than seven days. Commission must cost every
trade without unknown/degraded symbols; historical spread must bind every
native real-tick report. These minima are fixed in code and cannot be relaxed
by choosing a convenient threshold inside the evidence file.

`GLOBAL` is accepted only when every axis artifact enumerates the complete
covered EA/symbol/timeframe set. Otherwise evidence must be `PER_SLEEVE`.
Runner receipts bind the validated semantic payload; the summary binds each
axis artifact and sidecar at sweep start and end. The adjudicator reloads and
revalidates the original manifest and all artifacts instead of trusting copied
summary fields. Missing, expired, cross-axis, cross-sleeve, wrong-window or
changed evidence leaves a technically clean run `COST_UNCERTIFIED`.

### Preset risk application gate

Before MT5 starts, every source sleeve must provide `set_file_expectation` and
the runner compares every expected value with the exact read-only live preset.
The DXZ v2 contract treats `RISK_PERCENT` as the absolute sleeve risk, requires
it to equal manifest `risk_percent`, requires `RISK_FIXED=0`, and fixes
`PORTFOLIO_WEIGHT=1`. A normalized weight below one would apply risk twice and
is a technical preflight failure. The source, staged and post-run preset
values and hashes are retained in the receipt and checked again here.

## Inputs

The three required evidence roots are:

1. the exact original DXZ23 manifest;
2. a `summary.json` emitted by `dxz_as_live_requal.py`;
3. `framework/registry/dxz23_execution_contracts.json`.

The summary must bind the SHA-256 of the exact original manifest. Both the
summary and every successful receipt must pass their embedded canonical-JSON
hash check. A renamed or copied file is acceptable; modified JSON is not.

## Classification

| Result | Meaning | Candidate manifest |
|---|---|---|
| `KEEP` | Receipt is `PASS`, all identity/stream gates are bound, and contract promotion is `ELIGIBLE` | Included only from a `FULL/PASS` summary |
| `KEEP_CANDIDATE` | Receipt passes, and all open reasons are machine-only and closed for exact as-live binary retention | Evidence-promoted; included only from `FULL/PASS` |
| `REPAIR` | Receipt passes, but at least one requalification reason remains unresolved | Excluded |
| `BLOCK` | Receipt is missing/failing/tampered/incomplete, or contract is missing/invalid/`BLOCKED` | Excluded |

`KEEP` and `KEEP_CANDIDATE` require all of the following, not merely a
successful MT5 exit:

- exact EA id, `.DWX` symbol, EA label, timeframe and manifest trade count;
- live/staged EX5 hash equality;
- live/staged preset hash equality;
- tester INI, native report and report-derived stream hashes;
- captured Q08 stream hash and successful compare-and-swap restoration;
- sealed reference-stream hash and exact close-time sequence match;
- the canonical EUR 100,000 tester account and the schema-v2 requested/effective
  window contract, including any explicit reference-history truncation;
- a structurally clean execution contract, existing Card and source, and no
  expired fixed-calendar dependency.

Any summary-level integrity failure blocks the entire book. Runner status and
scope are validated using the runner's own state machine:

- `FULL + PASS`: every selected/source sleeve has a PASS receipt and a bound
  candidate may be assembled;
- `FULL + INCOMPLETE`: cryptographically valid PASS receipts remain individually
  adjudicable, while preflight-blocked receipts are `BLOCK`; no book candidate
  is emitted;
- `PARTIAL + PASS_PARTIAL`: selected smoke/retry receipts may be individually
  validated, but the summary never qualifies the book;
- `FAIL`: no book candidate is possible.

A consistent `INCOMPLETE` summary is not treated as corrupt and therefore does
not globally invalidate its good receipts. A consistent partial retry summary
is also permitted, but every source sleeve not present is explicitly classified
`BLOCK / RECEIPT_MISSING`. Both cases produce `NO_BOOK_CANDIDATE`, with valid
individual decisions listed under `validated_sleeves_not_admitted`.

## Non-circular evidence promotion

The registry is the policy baseline, not mutable run state. A completed run
therefore does not edit `promotion.status` merely to make itself pass. Instead,
the adjudication artifact can overlay `KEEP_CANDIDATE` when every open reason is
on a small machine-resolvable allowlist and the receipt closes it.

Currently the only allowlisted reason is
`remediated_binary_not_requalified`. A perfect receipt closes this reason only
for the exact live EX5 identified by that receipt. This produces one of two
explicit scopes:

- `AS_LIVE_AND_CURRENT_REPO_BINARY`: the repo EX5 has the same hash and is not
  older than the controlled source tree;
- `AS_LIVE_BINARY_RETENTION_ONLY`: the tested live binary may remain in the
  candidate, but the current repo build still requires its own requalification.

As-live retention requires:

- the complete receipt already passes every normal evidence gate;
- the contract and current source pass their structural/runtime lint;
- the Card and source exist and are content-hash bound;
- the exact live EX5, preset, report and streams remain receipt-bound.

Repo rebuild readiness is then evaluated independently. Repo EX5 hash mismatch,
missing controlled includes, or an EX5 older than its source tree appear under
`repo_rebuild_blockers`; they restrict the candidate to as-live retention and
cannot authorize copying or deploying the repo binary. The exact controlled
source-tree aggregate and file hashes are retained in the resolution record.

This cannot resolve semantic or governance reasons. In particular, Friday
override qualification, Card-v2 interpretation, undefined source exits,
incomplete/conflicting Cards, calendar-extension coverage, basket Q08 issues,
and native-vs-Friday-exit ablations remain `REPAIR` or `BLOCK`. A contract with
promotion `BLOCKED` is never evidence-promoted.

This separation avoids a deployment circle: the existing live binary can be
adjudicated without first replacing it, while any different remediated binary
must still pass an isolated target-binary requalification before deployment.

`adjudication.json` reports both sleeve counts and distinct-EA counts. As of
2026-07-16, after the corrected 11132 explicit-alias requalification gate and
the six-PASS semantic governance review, 11 distinct EAs correspond to 13 `REQUAL_REQUIRED` sleeves
because EAs 11421 and 12567 each have two symbols. Nine distinct blocked EAs
correspond to ten `BLOCKED` sleeves because EA 11165 has two symbols. Thus `13
REQUAL_REQUIRED / 10 BLOCKED` sleeves and `11 requal / 9 blocked` EAs describe
the same 23-sleeve/20-EA source registry at different aggregation levels.
Receipt adjudication can subsequently split the 13 requalification sleeves
into `KEEP_CANDIDATE` and `REPAIR`; it cannot promote the ten blocked sleeves.

## Invocation

Run this only after `dxz_as_live_requal.py --execute` has produced a summary:

```powershell
python tools\strategy_farm\dxz_requal_adjudicator.py `
  --manifest D:\QM\reports\portfolio\portfolio_manifest_sunday_23sleeve_DRAFT_20260711.json `
  --summary D:\QM\reports\portfolio\dxz23_as_live_requal\<RUN_ID>\summary.json `
  --contracts C:\QM\repo\framework\registry\dxz23_execution_contracts.json `
  --as-of 2026-07-15 `
  --output-dir D:\QM\reports\portfolio\dxz23_requal_adjudication_<UTC>
```

The output directory must be new. Existing artifacts are never overwritten.
An output path below any `T_Live` or `T1`-`T10` path is rejected.

## Bundle contents

- `adjudication.json`: book verdict, `KEEP/KEEP_CANDIDATE/REPAIR/BLOCK`
  decision and literal reason codes for every source sleeve;
- `candidate_bound_manifest.json`: only a `FULL/PASS` summary can contribute
  `KEEP` and `KEEP_CANDIDATE` sleeves. Schema v2 exposes a canonical
  `artifact_bindings` object per sleeve with `qualified_ex5_path`,
  `qualified_set_path`, `qualified_stream_path`, `live_preset_path`, their
  SHA-256 values, Card/MQ5 bindings, receipt/report evidence, and `trades`;
- `input_manifest.json`, `input_summary.json`,
  `input_execution_contracts.json`: exact JSON snapshots used by the decision;
- `SHA256SUMS`: hashes of all five JSON artifacts.

Candidate status is one of `BOUND_CANDIDATE_COMPLETE`,
`BOUND_CANDIDATE_PARTIAL`, `NO_BOUND_SLEEVES`, or `NO_BOOK_CANDIDATE`. Even a
complete candidate has
`deployment_eligible=false`, `deployment_action=NONE`, and
`portfolio_recompute_required=true`. It becomes a portfolio input only after
fresh cost/risk recomputation and a separate OWNER decision.

The candidate also binds the exact runner summary under
`source_requalification` (artifact hash, embedded payload hash, `FULL/PASS`
state) and the sibling `adjudication.json` under `source_adjudication` (artifact
hash, embedded payload hash, `PASS` verdict). The one-way binding deliberately
avoids a circular hash: adjudication is finalized first, then the candidate
binds its exact serialized bytes. `candidate_manifest_sha256` covers the final
candidate payload.

The retained `weight` and `risk_percent` values are the original manifest's
planned allocation, not a claim that the live preset's numeric formatting has
already been approved. The old `set_file_expectation` object is intentionally
discarded because it was not cryptographically tied to the tested preset. The
exact tested live preset is represented by its path and SHA-256 binding.

Exit codes are:

- `0`: every source sleeve is `KEEP` or evidence-bound `KEEP_CANDIDATE`;
- `1`: no hard block, but at least one sleeve requires repair;
- `2`: at least one sleeve or a global input is blocked.

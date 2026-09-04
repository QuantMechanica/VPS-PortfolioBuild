# Q08 stream bundle PASS-class independent review

RESULT: **PASS-with-findings**. Router task `348af875-69f2-4aa9-998b-bd1836bbe4cd`.
Reviewed commit `3e7f5752c2dc865daba1194ecfd96a2117063303` against canonical
checkout `b7935a005e447be6b13bfcf191a554cfa47525ec` on 2026-09-04.
Reviewer: Codex, GPT-6 Astra. This is a code review verdict, not a pipeline verdict.

The change implements OWNER-DEC-BUNDLE-Q08-PASSCLASS-20260904 correctly: it admits
exactly PASS and FAIL_SOFT at Q08, retaining current-binary and content-hash binding.
No acceptance-blocking regression from the reviewed commit was found. The proposal
below is unapplied; production source, verdicts, queues and book manifests were not
changed by this review. Evidence is committed on `agents/board-advisor`, as required
by the scheduled-cycle instruction, which overrides the payload's generic
`agents/codex` rule for evidence artifacts.

## Findings

1. **Low; pre-existing: timestamp text ordering can select an older seal.**
   `tools/strategy_farm/assemble_stream_bundle.py:160` and `:203` order Q14
   identities and Q08 seals by timestamp text. An older row at
   `2026-09-04T11:30:00+02:00` sorts ahead of a newer row at
   `2026-09-04T10:00:00Z`. Four synthetic cases reproduce the Q08 defect, covering
   both PASS/FAIL_SOFT orderings and both insertion orders. The loader accepts the
   selected older stream, so content validation cannot detect the ordering mistake.
   Current farm exposure is bounded: the read-only census at approximately 19:53Z
   found all 357 done Q08 PASS-class rows stored with `+00:00`; no live affected
   pair is asserted. The proposed diff orders by `julianday(updated_at)` first and
   adds deterministic tie-breaks. The same text-order expression in Q14 is included.

2. **Low; test coverage: the new test does not assert loader verification, and
   mixed verdict ordering is untested.**
   `tools/strategy_farm/tests/test_assemble_stream_bundle.py:306` creates one
   FAIL_SOFT row and one FAIL_HARD row for different pairs. It proves admission and
   exclusion, but cannot catch an ordering regression within a pair; at `:340`
   it also omits an assertion on the requested loader verification. The attached
   probe verifies eight loader acceptances and four ordinary UTC ordering cases.
   The proposed diff adds the missing assertion and eight ordering regression cases.

3. **Low; stale refusal text.**
   `tools/strategy_farm/assemble_stream_bundle.py:306` still describes a required
   `done/PASS` row even though FAIL_SOFT is accepted. The proposed diff states the
   actual PASS-class. This affects diagnostics only.

## Contract and downstream audit

| Surface | Evidence | Conclusion |
| --- | --- | --- |
| OWNER scope | `decisions/2026-09-02_owner_receipts_ceo_asks.md:15` | Explicitly authorizes PASS plus FAIL_SOFT at Q08. |
| Census | `tools/strategy_farm/rebaseline_census.py:182` | FAIL_SOFT is the sole additional gate-scoped Q08 pass token. Global PASS_ECON also includes tokens for other gates; that is not an authorization to admit those tokens here. |
| Q08 producer | `framework/scripts/q08_davey/aggregate.py:1530` | The producer documents PASS/FAIL_SOFT/FAIL_HARD plus infrastructure/invalid outcomes. Read-only done-row counts: PASS 95, FAIL_SOFT 262, FAIL_HARD 158, INFRA_FAIL 205, INVALID 9, PENDING_RUNNER 1, RETIRE 6, SUPERSEDED_DUPLICATE 1. |
| Seal selection | `tools/strategy_farm/assemble_stream_bundle.py:192` | SQL restricts status and verdict; source binary hash and content hash remain mandatory. FAIL_HARD cannot bind. |
| Loader verification | `tools/strategy_farm/assemble_stream_bundle.py:369` | Calls the builders' `load_daily`; eight probe cases verify actual loader acceptance. |
| Shared loaders | `tools/strategy_farm/portfolio/book_builder_common.py:255`; `tools/strategy_farm/portfolio/portfolio_common.py:266` | Consume stream bytes and keys, enforce present/nonempty sleeves, and derive daily PnL. They do not require a Q08 verdict equal to PASS. |
| Book builders | `tools/strategy_farm/portfolio/build_book_dxz.py:124`; `tools/strategy_farm/portfolio/build_book_ftmo.py:510` | Use the shared daily-stream loader. No Q08 PASS-only assumption found in these consumers. |
| Manifest validation | `tools/strategy_farm/portfolio/book_builder_common.py:420`; `tools/strategy_farm/config/dual_book_manifest.v1.schema.json:81` | Validate sleeve identity, risk, hashes and stream evidence; no Q08 PASS-only predicate. Book admission remains separately governed. |

Search of tracked Python tools/scripts found no direct consumer of the new bundle
manifest schema that filters Q08 verdicts. The legacy weekend generator references
a differently dated frozen bundle manifest and does not inspect its Q08 verdict.
No book-build or deployment operation was executed.

## Reproduction and proposed correction

- `python -m pytest tools/strategy_farm/tests/test_assemble_stream_bundle.py -q`:
  **10 passed**.
- `python C:/QM/repo/docs/ops/evidence/2026-09-04_review_bundle_q08_passclass_probe.py`:
  **4 UTC controls passed, 4 mixed-offset defects reproduced, 8 loader checks passed**.
  Exit zero verifies the documented reproduction, not correctness of mixed-offset selection.
- `git -C C:/QM/repo apply --check -- docs/ops/evidence/2026-09-04_review_bundle_q08_passclass_proposed.diff`:
  passed; patch was not applied.

Durable companions: `2026-09-04_review_bundle_q08_passclass_probe.py`,
`2026-09-04_review_bundle_q08_passclass_probe.json`, and
`2026-09-04_review_bundle_q08_passclass_proposed.diff` in this directory.
The diff is the minimal proposed production/test correction, retained for review.

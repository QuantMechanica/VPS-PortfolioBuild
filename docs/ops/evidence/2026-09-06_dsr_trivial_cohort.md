# Explicit single-configuration DSR cohort — 2026-09-06

Task f4505fb9-ab9f-4827-aa0b-9af8e209012b. REVIEW. Implementation and 42 focused tests PASS; real-card acceptance remains unavailable. No stored verdict changed, no thresholds changed, no pipeline run or successor enqueued.

Code lives on agents/codex-dsr-trivial-cohort-20260906. When the existing complete search-ledger lookup reports unavailable, the producer can now validate an explicit declaration in the approved card. It requires exactly one `qm-dsr-single-configuration` fenced JSON block, the supplied declaration schema, an APPROVED card, complete=true, no_optimization_search=true, research_trial_count=0, exact EA/symbol/timeframe, the SPEC SHA256, and a complete string-valued map of locked set parameters. All source-declared input keys must appear in the lock. Set differences, duplicate assignments/JSON keys, optimizer metadata, partial or conflicting build identities, and changed source/binary/set/spec bytes fail closed. Existing malformed/incomplete ledgers are not bypassed.

The resulting separate single-configuration cohort schema binds the approved card, SPEC, source, compiled binary, and set file by absolute path and SHA256. It declares one candidate configuration, complete search history, zero research trials, and an explicitly empty loser list. The evaluator revalidates the entire binding and declaration. The existing n=1 formula already returns zero expected-max-Sharpe correction; the new route exposes that formula through the governed context. It returns PASS/FAIL at the unchanged strict p < 0.05 threshold. Only a validated single-configuration context can return INSUFFICIENT for insufficient/degenerate data; missing authority remains INVALID. Existing multi-trial behavior and aggregate LOW_SAMPLE classification are retained.

The declaration is deliberate, machine-readable search authority, not an inference from default parameters or an absent ledger. It is not retroactively inserted into any real card by this change. Producer trust continues to depend on controlled approved-card and build-ledger writers; SHA binding is integrity evidence, not a cryptographic OWNER signature.

## Read-only replay

replay_candidate.py read the three latest completed INVALID Q08 artifacts, verified their sealed summary/report hashes, parsed the native report trades, checked reported trade counts, and calculated the existing n=1 statistic as an explicitly unsealed hypothetical. All source reports and DB verdicts are unchanged. Exact inputs and results are in replay.json.

| EA | Governed result now | Hypothetical n=1 statistic | Historical/current build |
|---|---|---|---|
| QM5_11167 XAUUSD | INVALID: explicit search declaration absent | p=0.0007074454; would PASS | source/binary/set match |
| QM5_11015 EURUSD | INVALID: explicit search declaration absent | p=0.0624792000; would FAIL | current repaired set differs |
| QM5_11196 XAUUSD | INVALID: explicit search declaration absent | p=0.0041039506; would PASS | source/binary/set match |

These hypothetical outcomes are not sealed contexts, pipeline verdicts, or acceptance of the strategies. The 11015 successor 34d0e1ba was still pending at replay time; no result was invented for it. Its completed predecessor 60f98a58 supplied the historical replay, which cannot stand in for the repaired set. The cards for 11167 and 11015 explicitly describe sweep candidates, so fixed defaults alone would understate potential search history. No claim that this change creates a 25th survivor is warranted.

## Verification

42 tests passed across the producer, evaluator, and existing DSR suites. Fixtures prove deterministic sealing, unchanged analytical n=1 computation, PASS/FAIL/INSUFFICIENT, and refusals for silent/unapproved cards, altered files, parameter drift, omitted source inputs, SPEC/build mismatch, documented additional research, candidate mismatch, duplicate keys, incomplete history, and wrong counts. These synthetic fixtures are software tests, not native strategy acceptance evidence.

## Vorlage — research history authority

OWNER/research review is needed before any real card can declare a complete single-configuration history. Confirm whether the listed sweep candidates were actually evaluated, and document the complete number and identity of all evaluated candidate configurations. This implementation accepts only an explicit zero additional research count. A card declaring additional research refuses with DOCUMENTED_RESEARCH_TRIAL_LEDGER_REQUIRED and must supply a complete loser-inclusive ledger; it never collapses 1 + research trials to 1. Extending the declaration to additional trials requires their reproducible return series and a reviewed counting rule, because trial count alone cannot establish cohort dispersion. This is a remaining limitation of the requested broader path, not an automatic approval request or a threshold change.

Review also needs to confirm adoption of the explicit declaration format for future cards and authorize any historical search attestation. This task has produced the concrete implementation and refusal evidence without manufacturing that authority.

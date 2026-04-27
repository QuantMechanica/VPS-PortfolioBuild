# QUA-91 WS30 Verifier Handoff (2026-04-27)

Issue: `QUA-91` (DEVOPS-004 child)  
Scope: investigate verifier failure for `WS30.DWX` only.

## Decision

- **WS30-specific status: CLEAR**
- `WS30.DWX` aligns with source `WS30` tail in-window (`custom_minus_source_tail_ms=-322` in probe)
- `FAIL_tail_bars` was decomposed into:
  - false `bars` fail from one-shot full-span `copy_rates_range` (`Invalid params`)
  - expectation-basis tail mismatch (sidecar vs source)

## Recommended issue transition

- Set `QUA-91` to **done/completed** (symbol-level investigation complete).

## Remaining blocker (outside QUA-91 scope)

- **Owner:** DWX verifier/runtime maintainer
- **Action:** deploy global verifier logic update:
  - chunked M1 reads
  - maxbars-aware bar expectation
  - canonical tail basis policy (`sidecar` vs `source`)

## Evidence pointers

- Investigation log: `lessons-learned/2026-04-27_qua91_ws30_verifier_failure_investigation.md`
- Candidate verifier: `infra/scripts/verify_import_candidate.py`
- Candidate log summarizer: `infra/scripts/summarize_verify_candidate_log.py`
- Full-batch candidate run log: `infra/smoke/verify_import_candidate_run_2026-04-27_091415_all_symbols.log`
- Structured handoff JSON: `docs/ops/QUA-91_WS30_VERIFIER_HANDOFF_2026-04-27.json`

# OWNER decision execution — OWNER-DEC-A2-OPT-MANDATORY

Date: 2026-08-28
Task: `agent_task ca2f0317-de8b-5f24-b622-92439de27d9b` (QM-TODO-20260824-521)
Decision: `OWNER-DEC-A2-OPT-MANDATORY` = YES, receipt `fdc84028-eca4-4e2e-a14e-afde84c37ca1`,
decided 2026-08-27T11:48:57Z.
Question: "Soll jedes Buchkandidaten-Paar Q12 bis Q14 durchlaufen, auch wenn keine
Verbesserung gefunden wird?"
Selected effect: "Der verpflichtende lineare Optimierungsabschnitt bleibt aktiv;
KEEP_INCUMBENT darf terminal bestehen."
Mode: `DOCUMENT_AND_VERIFY` — no gate/runtime logic changes; verification only.

## What this ratifies

Sub-decision A2 in `decisions/2026-08-23_owner_gate_manifest_v4_linear.md`, already executed
under the Stehende Vollmacht Auffangregel on 2026-08-23: every book candidate pair must
traverse Q12 (Pattern Filter Selection) through Q14 (Best-Settings Head-to-Head) as a
mandatory linear segment, and a `KEEP_INCUMBENT` outcome (no improvement found) is a valid
terminal PASS, not a failure or a skip.

## Verified implementation (no drift found)

`tools/strategy_farm/config/gate_manifest.v4.json` (active manifest,
`schema_version: qm.gate-manifest/v4`, confirmed loaded as `DEFAULT_MANIFEST` in
`tools/strategy_farm/gate_manifest.py:48`):

- Q11 → `next: "Q12"`, Q12 → `next: "Q13"`, Q13 → `next: "Q14"`, Q14 → `next: null`. The
  chain is strictly linear with no skip edge from Q11 or Q13 around Q12/Q13 into Q14 or
  beyond — mandatory traversal is structural, not a convention.
- Q12 (`Pattern Filter Selection`) carries an explicit note: "Mandatory linear step. Zero
  filters selected / no eligible filter is a valid pass-through outcome; not an
  `EXPLICIT_Q14_ADMISSION` gate anymore." — confirms the segment cannot be bypassed even
  when it selects nothing.
- Q14 (`Best-Settings Head-to-Head`) carries `"terminal_optimization_gate": true` and
  `"valid_outcomes": ["CHALLENGER_PROMOTED", "KEEP_INCUMBENT"]`, with `next: null` (terminal
  per-EA edge — Q15 book-construction entry is reachable only via the separate fail-closed
  book trigger, per Q15's `"entry_policy": "BOOK_TRIGGER_ONLY"`, not via a `next` edge from
  Q14).
- `tools/strategy_farm/gate_manifest.py` load-time validation (lines 774-776) hard-asserts
  `q14.terminal_optimization_gate is True` and
  `q14.valid_outcomes == ["CHALLENGER_PROMOTED", "KEEP_INCUMBENT"]` — a manifest that dropped
  or altered `KEEP_INCUMBENT` as a valid outcome would fail to load. This makes the A2
  guarantee a load-time invariant, not just a documented convention.
- `book_build_guard.py`'s `terminal_requalification_gate` (Q14) is resolved by evidence-role
  match (`SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT...`), so the book-build qualified-pair
  count (A1) only counts pairs that reached this exact terminal gate — i.e., pairs that
  completed the mandatory Q12-Q14 segment, whether the outcome was `CHALLENGER_PROMOTED` or
  `KEEP_INCUMBENT`. Both outcomes count as qualified; neither is excluded or double-counted.

This is an exact match to the ratified recommendation: the Q12-Q14 segment is mandatory and
structurally linear, and `KEEP_INCUMBENT` is a valid, terminal, counted PASS.

## Acceptance check

- No strategy mechanics or gate thresholds changed — pure verification.
- `KEEP_INCUMBENT` remains visible in the manifest's `valid_outcomes` and is not filtered out
  of the qualified-pair count in `book_build_guard.py` — it is not counted as an "optimized
  winner" either; it is simply a terminal-gate pass like `CHALLENGER_PROMOTED`.
- A durable evidence artifact (this file) records the verified contract.

## Conclusion

A2 is already correctly implemented; nothing to change. The router task moves to REVIEW for
independent orchestrator close-out per `review_required: INDEPENDENT_ORCHESTRATOR_CLOSEOUT`.

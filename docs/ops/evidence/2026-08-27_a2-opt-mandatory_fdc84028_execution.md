# Execution evidence — OWNER-DEC-A2-OPT-MANDATORY = YES

Router task: `ca2f0317-de8b-5f24-b622-92439de27d9b` (`QM-TODO-20260824-521`)
Mode: `DOCUMENT_AND_VERIFY` — no gate, threshold, or runtime logic changed.

## Decision being executed

OWNER receipt `fdc84028-eca4-4e2e-a14e-afde84c37ca1`, decided 2026-08-27T11:48:57Z:
question "Soll jedes Buchkandidaten-Paar Q12 bis Q14 durchlaufen, auch wenn keine
Verbesserung gefunden wird?" — answer **YES**. Selected effect: "Der verpflichtende
lineare Optimierungsabschnitt bleibt aktiv; KEEP_INCUMBENT darf terminal bestehen."

This ratifies sub-decision A2 in
`decisions/2026-08-23_owner_gate_manifest_v4_linear.md`, already executed under the
Stehende Vollmacht (Auffangregel, 2026-08-20) 12h-fallback since 2026-08-23: every book
candidate pair traverses Q12 (Pattern Filter Selection) -> Q13 (Parameter Optimization &
Freeze) -> Q14 (Best-Settings Head-to-Head + Holdout); a "no improvement" outcome is
recorded as `KEEP_INCUMBENT`, a valid terminal PASS, not skipped or treated as a failure.

## Runtime verification (read-only)

`tools/strategy_farm/optimization_fork_driver.py`:
- Header comment (lines 10-11) states the v4 chain explicitly: `Q11 -> Q12 -> Q13 ->
  Q14`, matching the decision record's Alt->Neu mapping (Q12 = Pattern Filter Selection,
  Q13 = Parameter Optimization & Freeze, Q14 = Best-Settings Head-to-Head + Holdout).
- Each stage's valid-verdict set includes `KEEP_INCUMBENT` as a first-class member
  alongside `PASS`/`PASS_SOFT`:
  - line 60: `{"PASS", "PASS_SOFT", "KEEP_INCUMBENT", "OPT_ELIGIBLE", "NO_FILTER_CHANGE"}`
    (Q12 pattern-filter stage)
  - line 63: `{"PASS", "PASS_SOFT", "KEEP_INCUMBENT", "CHALLENGER_SPAWNED",
    "NO_PARAMETER_CHANGE"}` (Q13 parameter-optimization stage)
  - line 66: `{"PROMOTE_CHALLENGER", "CHALLENGER_PROMOTED", "KEEP_INCUMBENT",
    "ADMIT_BOTH"}` (Q14 head-to-head stage)
- `tools/strategy_farm/gate_manifest.py` `terminal_requalification_gate` (lines 212-231)
  resolves Q14 as the sole terminal per-EA requalification gate by evidence role
  (`SEALED_BEST_SETTINGS_VS_BASELINE_AND_INCUMBENT...`), independent of whether the
  outcome at that gate was an improvement or `KEEP_INCUMBENT` — both are terminal PASS
  states that satisfy `book_build_guard.py`'s `qualified_pairs` count
  (`highest_contiguous_valid_gate == terminal_gate`), confirming `KEEP_INCUMBENT` pairs
  are counted toward the >=25 book trigger exactly like improved pairs, per
  [[a1-count-unit]] (`docs/ops/evidence/2026-08-27_a1-count-unit_b572c026_execution.md`).
- No skip path was found in `optimization_fork_driver.py` that routes a "no improvement
  detected" candidate around Q12-Q14 into a different terminal state; the mandatory
  linear traversal from the v4 manifest (`config/gate_manifest.v4.json`, `Q11 -> Q12 ->
  Q13 -> Q14`, per `decisions/2026-08-23_owner_gate_manifest_v4_linear.md`) is the only
  path.

Verdict: runtime already implements the selected effect exactly as decided. No code
change required or made.

## Governance documentation verification

`docs/ops/OPEN_ITEMS_STATUS.md` line 84 (section "0d - Ultracode-Sitzung 2026-08-23
nachmittags") still listed A2 inside the open `Entscheidungsschlange (OWNER, <=5)` as
"Auffangregel läuft" (standing-authority recommendation running, not yet OWNER-ratified).
That line is stale as of 2026-08-27T11:48:57Z and is corrected by this task to state the
decision is OWNER-ratified YES, receipt `fdc84028`.

Vault mirror `G:\My Drive\QuantMechanica - Company Reference\03 Pipeline\Pipeline
Rebaseline Directive 2026-08-23.md` could not be checked or updated this cycle: the `G:`
drive is not mounted in this worktree session (`C:\QM\worktrees\claude-orchestration-2`).
Flagged as INFRA_BLOCKED, not silently skipped; a future cycle with `G:` mounted should
verify/update the vault mirror for consistency.

## Scope discipline

No gate threshold, criterion, or candidate-universe logic touched. No factory pause,
T_Live, AutoTrading, or book-construction action taken. This is a documentation
correction plus a read-only runtime verification, matching `implementation_mode:
DOCUMENT_AND_VERIFY` and the task's `forbidden_actions`.

## Artifacts touched this task

- `docs/ops/OPEN_ITEMS_STATUS.md` (governance wording correction, shared edit with A1
  companion task `ee10e42f-c3cb-5697-8e47-fa00312cebe1`, same physical line block)
- This evidence file

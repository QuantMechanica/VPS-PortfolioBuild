# Adversarial review — slice `b3_docs_rule_audit`

**Reviewer:** Claude (adversarial reviewer, board-advisor) · **Date:** 2026-09-15
**Patch:** `scratchpad/patches_bc/b3_docs_rule_audit.patch` (read in full, 1115 lines)
**Verdict:** ACCEPT_WITH_FIXES (one blocking apply defect; content sound, no RED crossed)

Documentation-only slice. All 8 diff targets are `.md` files. No code, JSON contract, gate
manifest, verdict, farm-DB write, T_Live/AutoTrading toggle, purchase action, or credential is
touched. RED boundaries are clean (see §1).

---

## 1. RED boundaries — CLEAN

- **No gate threshold / criterion change.** The audit and CBE doc *recommend* changes
  (drop `qualified_candidates_ge_25`, family/symbol `status → ADVISORY`, relax the ROT_SEALED
  0.50 correlation cap) but every such change is explicitly attributed to another slice/phase
  (b1, contract, Phase B/C/E/F) and **none is made here** — verified: the patch modifies zero
  `.py`/`.json` files. `git apply --check` shows only `.md` targets.
- **Qualification not weakened.** Docs repeatedly affirm Q02–Q14 predicates still fail closed,
  OWNER book-order artifact retained, `CLUSTER_CORRELATION_UNVERIFIED` fail-closed retained.
- **Live/money authority preserved.** CLAUDE.md annex + CBE §9 + Q17 rewrites keep AutoTrading,
  paid purchase, deployment, gate thresholds and book construction OWNER-only (ROT). No
  automation path to purchase or live toggle introduced.
- **No token/credential exposure**; no farm DB write; **no history deleted** — old text kept in a
  `<details>` SUPERSEDED block (PIPELINE_V5) and quoted in dated SUPERSEDED notes (BOOK_CEREMONY),
  annexes are additive.

**red_boundary_crossed: false.**

## 2. Directive fidelity — STRONG (all required deliverables present)

- **RULE_EFFECTIVENESS_AUDIT_2026-09.md** covers all 14 rule families the task enumerated
  (fixed-25, Q17 min-lot, Q17 14-day, family caps, symbol caps, fixed correlation, HR16, R1–R4,
  FTMO purchase thresholds, FTMO density, redundant gates/serial deps, AI quota, resource
  thresholds incl. 80 GB guard / RAM 44/24/12 / purge 60 / worker CPU pause). Each carries
  original purpose + cited decision, §20 class A/B/C/D, current benefit, current cost with the
  audit's numbers, safety impact, recommendation, rollback, and DISPOSITION. **The mandated
  RAM-class live cost (6/10 terminals idle ~2.95 h, census 0/h vs 732 claimable) is present in
  §13b.** ✓
- **CONTINUOUS_BOOK_EVOLUTION.md** contains every required element: two living books; venue
  fitness layers (§57); weekly rhythm (§61); outcomes (§6); materiality/anti-churn (§59) with the
  computable spec correctly deferred to Phase E as PENDING; Q17 evidence-based
  introduction/probation (§10) with the full decision-inputs list; live/money authority (§64); the
  Sunday 2026-09-20 ceremony under the new model; and the weekly recomposition contract skeleton
  (inputs frozen at Friday cut, outputs, artifacts at `D:/QM/reports/book_evolution/<ISO-week>/`,
  reserved Phase-H task names). ✓
- **Q17 rewrites** landed in both PIPELINE_V5_SUB_GATE_SPEC.md (P10/Q17 header + purpose rewritten,
  original wrapped in a balanced `<details>` SUPERSEDED block, V5-vs-V2.1 table row and impact
  item 13 marked SUPERSEDED) and BOOK_CEREMONY_RUNBOOK step-13 (~line 162) with a dated SUPERSEDED
  note quoting the old "14-day min, min-lot" text. ✓
- **Annexes**: OPERATING_RULES (drain doctrine + HR16 superseded, controlled-parallelism §24
  conditions, determinism-first retained), COMPANY_AUDIT (Q00–Q17, 25-trigger + drain superseded,
  purge LowWater 60), CLAUDE.md dated `OWNER-DEC-CBE-20260915` bullet under Ratified Rules with the
  rest untouched. ✓  (But see the apply defect in §3.)
- **No invented arbitrary permanent cap / no silent no-op.** The audit explicitly forbids
  replacing static caps with a new arbitrary set (F4/F5/F6, CBE §6) and, crucially for directive
  §70, documents that the discrete family/symbol caps are *already* an unenforced no-op (drift D1)
  while the SP-C3 percent-of-budget caps remain active — it demands a real dependence panel
  (Phase E) rather than leaving a warning that silently does nothing. Faithful.
- **Evidence-path defect fixed.** Every `research_env.py` citation in the two new canonical docs
  uses the full path `tools/strategy_farm/research/research_env.py` (grep-verified: zero bare
  citations).

## 3. Correctness — one BLOCKING apply defect + factual anchors verified

### BLOCKING — patch does not apply to the canonical repo (2 of 8 files)

`git apply --check --verbose` on `C:\QM\repo` (branch `agents/board-advisor`) reports:

```
Checking patch CLAUDE.md...                     Hunk #1 succeeded at 383 (offset 53 lines).
Checking patch docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md...   OK
Checking patch docs/ops/COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md...
  error: patch failed: docs/ops/COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md:74
  error: ...: patch does not apply
Checking patch docs/ops/CONTINUOUS_BOOK_EVOLUTION.md...   OK (new)
Checking patch docs/ops/OPERATING_RULES_2026-07-03.md...
  error: patch failed: docs/ops/OPERATING_RULES_2026-07-03.md:149
  error: ...: patch does not apply
Checking patch docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md...   OK
Checking patch docs/ops/RULE_EFFECTIVENESS_AUDIT_2026-09.md...   OK (new)
Checking patch .../design/b3_docs_rule_audit_report.md...   OK (new)
```

Root cause: the implementer's worktree base predates current `main` for these two files. The
"append-only" annex hunks were generated against the OLD shorter versions and their trailing
context expects old-EOF:
- **COMPANY_AUDIT** is now 144 lines (was 76). The anchor "…Codex should handle default
  code/ops/build work." is at line 117, followed by an existing drift-correction table (lines
  119–144). The hunk `@@ -74,3 +74,35 @@` fails because its trailing EOF context no longer holds.
- **OPERATING_RULES** is now 192 lines (was ~151). The anchor "…AUDIT_REPORT.md §1." is at line
  151, followed by more content through rule 27 (line 192). Hunk `@@ -149,3 +149,42 @@` fails the
  same way.

Impact: a straight `git apply` drops **two required task deliverables** — the OPERATING_RULES
drain/HR16 supersession amendment and the COMPANY_AUDIT 25-trigger/drain annex. The implementer's
`not_done` claim that the annexes are "line-drift-robust" is **incorrect for `git apply`**: the
patch fails outright rather than fuzzing to EOF.

Fix (mechanical, no redesign): re-anchor/regenerate these two hunks against the current files,
appending at the true end-of-file. The other 6 targets (incl. the two large new docs and all Q17
rewrites) apply cleanly.

### Factual anchors — VERIFIED

- `tools/strategy_farm/research/research_env.py` exists; `RESEARCH_DISK_MIN_FREE_GB = 80.0`
  (line 51) — matches audit §13a.
- `book_build_guard.py:31 MIN_QUALIFIED_PAIRS = 25`; refusal at :239–241 (audit says :238-242 —
  trivial off-by-one, MINOR).
- `gate_manifest.v4.json` `book_trigger` at line 370, `qualified_candidates_ge_25` at line 375 —
  matches audit §1.
- English throughout; all supersession markers dated 2026-09-15 / OWNER-DEC-CBE-20260915.
- Windows paths use forward slashes consistently; no path defects.

## 4. Tests (§70) — appropriately N/A

Documentation-only slice changes no contract, so §70 (regression tests for changed *contracts*)
does not bite. The report's substitute verification is reasonable: no pytest file depends on the
touched docs, research_env.py citations use the full path, SUPERSEDED `<details>` block balanced.
Summary line "n/a — documentation-only slice, no test files affected" is honest and correct. No
test defect.

## 5. Cross-slice dependency risk — MAJOR (ordering)

The new canonical docs and every annex cite **`decisions/2026-09-15_owner_continuous_book_evolution.md`
as the governing authority (OWNER-DEC-CBE-20260915)** — but that decision record is **MISSING**
from the repo and is not created by this slice. Likewise `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md`,
`docs/ops/FTMO_CHALLENGE_READINESS.md`, and `docs/research/AUTONOMOUS_EDGE_DISCOVERY.md` are
referenced as existing canonical artifacts but are absent (directive §69 assigns them to other
slices/phases F/G). `decisions/2026-09-13_owner_book_order_dxz.md` and
`..._2026-09-14_owner_book_order_ftmo.md` DO exist (CBE §10 reference correct).

b3 must not be applied ahead of the slice that mints the decision record; otherwise every CBE
annex and the CLAUDE.md Ratified-Rules bullet point at a nonexistent authority file. Not a defect
of b3's content (it correctly uses the canonical §69 paths), but a hard apply-ordering constraint.

## 6. Minor notes

- **COMPANY_AUDIT annex is partly redundant** with the file's existing in-body drift table, which
  already states LowWater 60 (row 2) and Q00–Q17 (row 6). When re-appending, reconcile so the
  same correction is not stated twice. The task's "~line 135" 25-trigger/drain anchor does not
  exist in the current 144-line file either, so the annex approach is the right call — just place
  it at true EOF.
- book_build_guard refusal line-range off by one (§13a of audit is exact; §1 refusal cite
  :238-242 vs actual :239-241).

---

## Findings summary

- **BLOCKING (1):** patch fails `git apply` on COMPANY_AUDIT_LIVE_SOURCES_2026-05-30.md and
  OPERATING_RULES_2026-07-03.md; two required annex deliverables would be dropped. Re-anchor the
  two append hunks to current EOF before apply.
- **MAJOR (1):** docs cite `decisions/2026-09-15_owner_continuous_book_evolution.md` (+ 3 §69
  docs) that do not yet exist; enforce apply ordering / ensure those slices land.
- **MINOR (2):** COMPANY_AUDIT annex duplicates existing drift-table corrections; one off-by-one
  line cite.

Content quality is high, directive-faithful, and no RED boundary is crossed. The blocking item is
purely mechanical (stale patch base), not a design flaw.

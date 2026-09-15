# Adversarial review — slice `b4_vault_rewrites`

**Reviewer:** adversarial review lane · **Date:** 2026-09-15
**Slice:** `b4_vault_rewrites` (in-place Company Reference Vault edits, `patch_path = NONE`)
**Report reviewed:** `docs/ops/evidence/2026-09-15_continuous_book_evolution/design/b4_vault_rewrites_report.md`
**Verdict:** ACCEPT_WITH_FIXES · **RED boundary crossed:** NO

Spot-checked (read in full on `G:`): Q15, Q17, Hard Rules, Current Objective, AI Spend &
Quota Governance, Stehende Vollmacht, _HOME, START_HERE, and the three created pages
(Mission Control, Kimi Research Provider, FTMO Campaign). Cross-checked against
`audit/vault_doc_drift.md` (drift table) and `PHASE_A_TRUTH_SNAPSHOT.md` §9. Ran the vault
lint independently.

---

## (1) RED boundaries — NONE crossed

- **No gate threshold / criterion change in code.** This slice touches only vault markdown.
  The Q15 book-trigger, portfolio caps and Q17 min-lot are *documentation mirrors* of code
  contracts; the code-side supersession is a different slice. No `gate_manifest*.json`,
  `book_build_guard`, or builder was modified.
- **Qualification not weakened.** Every book-trigger rewrite explicitly preserves fail-closed
  qualification: Q15 annex states "This does NOT lower qualification — unqualified/weak
  strategies still fail closed" and the OWNER-order requirement is retained verbatim.
- **T_Live / AutoTrading / purchase authority preserved and reinforced.** Q17 annex:
  "Actual live activation / AutoTrading remains OWNER-only (unchanged, §64)." Stehende
  Vollmacht §64 annex keeps ROT: paid FTMO Challenge purchase, additional accounts, live
  AutoTrading, irreversible live actions, subscription purchase — all OWNER-only.
- **No evidence rewrite.** History is struck (`~~ ~~`) not deleted; dated historical notes
  (2026-08-23 book-trigger note, Gate Manifest v4 Diff, old Current-Objective block) are
  annotated append-only.
- **No token/credential exposure, no farm-DB write.** Verified — account IDs still point at
  `.private/VPS_SERVER_RECORD`; no secrets introduced.
- **No new arbitrary permanent cap invented** (the §8 trap). Q15 caps were converted to
  *guardrails/diagnostics* that "may be crossed only with an explicit, evidence-based
  portfolio-risk justification" — exactly what §8 requires; Kimi local caps are framed as
  "fallback guardrails, not contract limits" (§33). No silent no-op warning was introduced
  (these are docs, not code paths).

## (2) Directive fidelity — strong

- Every row of the `vault_doc_drift.md` drift table is addressed. The two rows correctly
  left alone — Heartbeat (`heartbeat_snapshot.py`) and the 23 Morning Briefings
  (`morning_brief.py`) — are generator-driven and belong to Phase D; the report says so and
  the drift audit agrees. This is the correct call, not a skipped item.
- Task "pages at minimum" list all present: _HOME, START_HERE, Current Objective (headline
  now CONTINUOUS BOOK EVOLUTION), Hard Rules (HR16 annex added; HR14 + 2026-09-15 Kimi annex
  left intact — verified), Company Structure, AI Agent Routing, Research Methodology,
  Determinism, Pipeline pages (Q15/Q16/Q17/Overview), FTMO board, Lessons Learned,
  AI Spend/Quota (Kimi §29–§34 section added), Stehende Vollmacht (§64), Current Operating
  State, Claude.md (Nordstern block only, generator top left alone), Risk Conventions,
  Operational Disciplines, 10_Pipeline_Leerlauf.
- Three missing canonical pages created with correct Obsidian frontmatter and wiki-links:
  Mission Control (marked "Phase D in progress 2026-09-15" per instruction), Kimi Research
  Provider (summarizes the three `docs/ops/KIMI_*` specs with repo paths), FTMO Campaign.

## (3) Correctness

- All spot-checked pages are UTF-8, no BOM, no mojibake / replacement chars. Obsidian
  frontmatter and `[[wiki-links]]` intact on created pages.
- **MAJOR (cross-slice dependency):** every supersession annex references
  `C:/QM/repo/decisions/2026-09-15_owner_continuous_book_evolution.md`, which **does not yet
  exist** (`ls` → No such file). The decisions-file slice must land or the entire
  supersession trail points at a missing record. Not this slice's fault (the report flags
  it), but it must be closed at programme level before the vault trail is coherent.
- **MINOR:** `START_HERE.md` rules 1/7/8 write the annex as inline `[!note] Superseded …`
  without the leading `>` blockquote prefix on its own line, so those three will render as
  plain text, not Obsidian callout boxes (contrast the correctly-formatted `> [!note]` in
  _HOME:57 and Q15). Content is present/dated/greppable; only the callout rendering differs
  from the specified annex block format.
- **MINOR:** `Q17 Live Burn-In DXZ.md` — the core rule (Duration, min-lot, the two Hard-Rules
  rows) is prominently superseded with a top annex, but residual "14 days" wording remains
  un-struck in secondary sections: Kill-Switch ("during the 14 days"), During-Burn-In Cadence
  ("Final PASS/FAIL … after ≥14 days", "Day 14+"), and the "After Q13 PASS (14 days
  complete…)" heading. These downstream references drift from the now-evidence-based stage.
- **MINOR (cosmetic):** `Hard Rules.md` now carries mixed CRLF/CR line terminators; renders
  fine in Obsidian.

## (4) Tests

- §70 lists *code-contract* regression tests (Q15 guard, Q17, Mission-Control logic, Kimi
  fallback, etc.) — those belong to the code slices, not to this doc-only slice; N/A here.
- The appropriate check for a vault slice is the vault lint. Ran it independently:
  `Company Reference lint: FAIL`. **Verified** that every failure is in a file this slice did
  NOT touch (`08 Current State/2026-09-08 *`, `2026-09-09_candidates_pattern_balke.md`,
  `12 ToDo/AI ToDos/Codex.md`, `OWNER.md` incl. its `GER40.DWX` mention, four `Archive/*`).
  None of the 23 edited or 3 created pages appear. The slice introduced **no new lint
  failures** — the report's test claim is accurate. Pipeline pages carry `Q11_DXZ`/Q-legend
  text and did not trip the "old gate token" rule (which matches P0–P10), confirming the
  report's reasoning.

## (5) Docs

- Dated supersession markers present throughout (`Superseded 2026-09-15 — OWNER-DEC-CBE-20260915
  (§n)`), each pointing at the decision record.
- No history deleted: superseded current-guidance sentences struck with `~~ ~~`; historical
  and dated blocks annotated, not rewritten. Consistent with §3/§65/§71.
- Language matches each page (German pages stay German; created reference pages English/German
  as appropriate).

---

## Blocking (must fix before apply)
None. The vault edits are already applied in place and are sound; there is no apply gate for
vault content, and no RED boundary is touched.

## Major (fix in follow-up slice)
1. The decision record `decisions/2026-09-15_owner_continuous_book_evolution.md` referenced by
   every annex does not exist yet — the decisions-file slice must create it so the supersession
   trail resolves. Programme-level dependency.

## Minor (note)
1. `START_HERE.md` rules 1/7/8 annexes are inline `[!note]` without the `>` blockquote prefix —
   won't render as callout boxes; reformat to `> [!note]` on its own line for consistency.
2. `Q17 Live Burn-In DXZ.md` residual un-struck "14 days" references in Kill-Switch / Cadence /
   "After Q13 PASS" heading — align with the evidence-based stage.
3. `Hard Rules.md` mixed CRLF/CR line terminators (cosmetic).

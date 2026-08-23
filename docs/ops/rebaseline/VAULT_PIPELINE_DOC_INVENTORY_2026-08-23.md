# Vault Pipeline Documentation Inventory — Pipeline Rebaseline

**Date:** 2026-08-23
**Author:** Claude (Orchestrator), branch `agents/board-advisor`
**Scope:** Migration inventory of vault pipeline documentation for the OWNER Pipeline
Rebaseline Directive 2026-08-23 (3 macro phases, strictly linear gate numbering).
**Authority context:** `G:/My Drive/QuantMechanica - Company Reference/03 Pipeline/Pipeline
Rebaseline Directive 2026-08-23.md` (READ FIRST — the directive itself).
**Constraint:** This is an inventory only. No vault edits were made. Thresholds/criteria are
ROT (unchanged). Final gate IDs require an OWNER Vorlage (directive §7.6).

---

## 0 · Executive summary

- The runtime contract is `tools/strategy_farm/config/gate_manifest.v3.json` (ACTIVE today).
  The vault documents v2 topology as the "kanonische Ist-Topologie" in two prominent places
  (`Pipeline Overview.md`, `Pipeline Operations Workflow.md`) — a **documented drift** the
  migration must resolve: v3 is live, but the human mirror still cites `gate_manifest.v2.json`.
- Two non-linearities the directive names explicitly are present in today's docs:
  (a) **Q10A appears before Q09** in the v3 target order (`Gate Manifest v3 Diff.md`), and
  (b) **Q16 returns to Q11** (a backwards jump) across `Pipeline Overview.md`,
  `Pipeline Operations Workflow.md`, `Q11`, `Q14`, `Q15`, `Q16` pages.
- The rebaseline is already announced at the top of the two hub pages and inside the `Q11`
  and `Q14` phase pages (a "während der Rebaseline nur die historische ID" note). Those notes
  are the pattern to propagate; they are NOT the renumbering itself.
- **Linter failure (`00 Governance/lint_company_reference.py`) on
  `12 ToDo/13_Schienenplan_2026-08-22.md` is a FALSE POSITIVE**: the offending tokens are
  priority labels `P0`/`P1`/`P2` (Prio-0/1/2), NOT old gate tokens. **Fix = edit** (rename the
  priority notation), NOT archival — the page is current planning content. Detail in §4.
- **Archive convention:** move a superseded page to `_ARCHIV/<same numbered subfolder>/`
  (e.g. `_ARCHIV/03 Pipeline/`). The linter skips `_ARCHIV` for active-term checks
  (`markdown_files(active_only=True)` filters `_ARCHIV` out), so archived pages may keep old
  P*/Qxx tokens. `_ARCHIV/03 Pipeline/` exists but is currently empty.

---

## 1 · `03 Pipeline/` — page-by-page inventory

Status legend: **current mirror** = actively-maintained human mirror of the live contract ·
**historical** = kept on purpose as frozen reference · **superseded** = content overtaken,
migration must rewrite or archive.

### 1.1 Hub / contract pages

| Page | Gate IDs referenced | Status | Must change under linear renumbering | Archive? |
|---|---|---|---|---|
| `Pipeline Overview.md` | Q00–Q16 (full table), storage `P*` mentioned generically | **current mirror**, but cites `gate_manifest.v2.json` as canonical while v3 is live → drift | PRIMARY rewrite target. Replace the Q10→Q14→Q15→Q16→Q11 "separater Zweig" topology with the 3-phase linear order; add Q10A (Baseline Full Run); flip Q09/Q10A ordering per v3; re-point "Kanonische Quellen" from v2 to v3 (then to the ratified new contract). Already carries 3 stacked banner notes (Q05 rename done, v3 in activation, rebaseline directive). | No — rewrite in place |
| `Pipeline Operations Workflow.md` | Q00–Q16 | **current mirror** with **stale gate name**: line labels Q05 as "Stress Medium" ("Q05 Stress Medium → Q06 Stress Harsh" and table row "Q05 \| Full-History / Stress Medium") — contradicts the ratified Q05 = "Gross Full-History Robustness" (2026-08-21). Also cites `gate_manifest.v2.json`. | Fix Q05 name drift; re-point canonical source v2→v3; rewrite Q14→Q16→Q11 "optionaler Zweig, zurück zu Q11" into linear phase-2 sequence. Carries a rebaseline follow-up banner already. | No — rewrite in place |
| `Gate Manifest v3 Diff.md` | Q00–Q16 + **Q10A** (new evidence role), Q11_DXZ/Q11_FTMO storage lanes | **current mirror** of the v3 activation (the authoritative diff doc) | This is where the two non-linearities are codified (Q10A-before-Q09; Q16→Q11). Under linear numbering it becomes the "v2→v3" leg of a 3-leg mapping (v2→v3→v4-linear); keep as historical diff once the linear contract ratifies, add the v3→linear column. | Eventually historical (freeze after linear contract), not now |
| `Pipeline Rebaseline Directive 2026-08-23.md` | conceptual (Q02, Q10A implied) | **current mirror** (the directive) | No renumbering; it is the source authority. Keep. | No |

### 1.2 Phase detail pages Q00–Q16

All are the human mirror of one gate each. Gate ID = filename. Every page needs the same
mechanical migration touch: (a) new linear gate ID once OWNER ratifies, (b) `gate_contract_version`
framing so the old ID keeps its old meaning, (c) cross-links updated to new IDs.

| Page | Gate | Status | Renumbering / migration note | Archive? |
|---|---|---|---|---|
| `Q00 Research Intake.md` | Q00 | current mirror | Phase 1 head. Stable content; ID likely stays Q00. | No |
| `Q01 Build & Spec.md` | Q01 | current mirror | Phase 1. Likely stable. | No |
| `Q02 Baseline Screening.md` | Q02 | current mirror | Phase 1 hard economic filter (directive §1 reaffirms terminal FAIL). Content stable; renumber-only. | No |
| `Q03 Parameter Sweep.md` | Q03 | current mirror | Phase 1. renumber-only. | No |
| `Q04 Walk-Forward + Commission.md` | Q04 | current mirror | Phase 1. renumber-only. | No |
| `Q05 Gross Full-History Robustness.md` | Q05 | current mirror | Title already carries `(formerly "Stress MEDIUM")` — canonical name is fixed here; the drift lives in the Operations Workflow page, not here. renumber-only. | No |
| `Q06 Stress HARSH.md` | Q06 | current mirror | Phase 1. PASS_SOFT path live. renumber-only. | No |
| `Q07 Multi-Seed.md` | Q07 | current mirror | Phase 1. renumber-only. | No |
| `Q08 Davey Statistical Validation.md` | Q08 (11 sub-gates) | current mirror | Phase 1 close; Q08 full-history baseline becomes the hash-bound Q10A evidence source (v3). renumber-only + note the Q10A reuse rule. | No |
| `Q09 News Impact Mode.md` | Q09 (+ Q10 dependency) | current mirror; contains an explicitly `superseded 2026-08-04` sub-item (Mode-3 auto-apply) as documented history-inside-page | Phase 2 head. v3 adds "+ FTMO Recommendation". Under linear order Q09 comes AFTER Q10A/Baseline Full Run — the page must state the new position and the CONFIG_LOCKED→Q10 hand-off with new IDs. | No |
| `Q10 Full-History Confirmation.md` | Q10 | current mirror | Phase 2. v3 = "Incumbent Full-History Confirmation", dependency **only** Q09 `CONFIG_LOCKED` (E1). renumber + dependency-text update. | No |
| `Q11 Portfolio Construction.md` | Q11 (inputs Q10 or Q16) | current mirror; **already carries the rebaseline banner** ("Die Bezeichnung Q11 ist während der Rebaseline nur die historische v3-ID") | Phase 3 head. This is the target of the Q16→Q11 backwards jump — under linear numbering Q11 becomes the highest number after the optimization branch. The 25-candidate / OWNER-order book trigger (directive §6) must be written in here (currently in Operations Workflow + directive). | No |
| `Q12 Operational Readiness.md` | Q12 | current mirror | Phase 3. renumber-only. | No |
| `Q13 Live Burn-In DXZ.md` | Q13 | current mirror | Phase 3 terminal. renumber-only. | No |
| `Q14 Optimization Admission.md` | Q14 | current mirror; **already carries rebaseline banner**; v3 renames to "Pattern Filter Selection" (≤3/direction, DL-089) | Phase 2 optimization branch. Name change (Admission→Pattern Filter) + renumber; branch must fold into the linear phase-2 sequence, not a fork returning to Q11. | No |
| `Q15 Challenger Build and Freeze.md` | Q15 (Challenger runs Q02→Q10) | current mirror; v3 renames to "Parameter Optimization & Freeze" | Phase 2. Name change + renumber. | No |
| `Q16 Head-to-Head Requalification.md` | Q16 (→ back to Q11) | current mirror; v3 renames to "Best-Settings Head-to-Head", binds Q10A_BASELINE + Q10_INCUMBENT | Phase 2 close. The "Ergebnis kehrt zu Q11 zurück" text is the backwards jump to eliminate — under linear numbering Q16's successor is simply the next (higher) Phase-3 number. | No |

**None of the Q00–Q16 pages should be archived.** They are the living mirror; the migration
rewrites them in place with new IDs + `gate_contract_version` framing (directive §3: old IDs
never silently re-read with new semantics).

---

## 2 · `08 Current State/` — inventory

These are state/mission pages, not gate-definition pages. They reference gate *ranges* and so
need renumber-sweeps but carry no gate contract.

| Page | Gate IDs referenced | Status | Must change | Archive? |
|---|---|---|---|---|
| `Current Operating State.md` | Q02–Q10, Q14→Q16→Q11, "Q00–Q13-Pipeline", "CLAUDE.md-Pipeline-Korrektur Q00–Q13" | current mirror | Range-reference sweep to new linear IDs after ratification; already reflects the rebaseline framing (Q02 hard filter, INFRA/INVALID separation, Q02..Q10→Q14→Q15→Q16→Q11). | No |
| `Heartbeat.md` | funnel counters (Q10-PASS, Q14, Q09_NEWS, Q06 PASS_SOFT) | current mirror (auto-rendered surface) | Counter labels re-map to new IDs; driven by `heartbeat_snapshot.py`, so the code label source must change too, not just the page. | No |
| `Mission Baseline.md` | mixed "Q00–Q13" and "Q00-Q16" and Q02–Q10, Q11–Q13 | current mirror; **internal inconsistency** (both Q00–Q13 and Q00–Q16 appear) | Reconcile the Q00–Q13 vs Q00–Q16 range and renumber to the linear contract. | No |
| `Current Objective.md` | (goal-level, checked: no gate tokens of concern) | current mirror | Minimal; sweep only if it names ranges. | No |
| `Strategischer Fahrplan FTMO Payout und DXZ Allocation 2026-08-22.md` | book-level (Q11/Q13 context) | current mirror | Book-trigger language must align to directive §6 (25 candidates + OWNER order); renumber Q refs. | No |
| `FTMO Hindernisse-Analyse 2026-08-16 (Import).md` | imported analysis | **historical** (dated import) | No renumber needed; leave as dated import. Candidate for `_ARCHIV/08 Current State/` if it clutters, but not required by migration. | Optional |

---

## 3 · `00 Governance/lint_company_reference.py` — forbidden tokens

The linter enforces token hygiene on **active** pages only
(`markdown_files(active_only=True)` skips any path containing `_ARCHIV` and skips `.obsidian`).

Forbidden-term checks (`check_forbidden_active_terms`):

1. **Old gate tokens** — regex
   `(?<![A-Za-z0-9])P(?:0|1|2|3(?:\.5)?|4|5[bc]?|6|7|8|9b?|10)(?![A-Za-z0-9])`.
   Matches standalone `P0 P1 P2 P3 P3.5 P4 P5 P5b P5c P6 P7 P8 P9 P9b P10`. This is the
   legacy `P*` gate naming that operator surfaces must never show (Qxx-only rule). **This is
   the check that fails on the Schienenplan — see §4.**
2. **Retired agent-system** — `paperclip|papeclip` (case-insensitive).
3. **Retired org-roles** — `Token Controller|Controlling Agent|Doc-KM|Documentation-KM|Board
   Advisor|CoS|CTO|DevOps` (standalone). Exempted only for the frozen `LEGACY_ROLE_DEBT` set
   (8 pages); new pages must not join it (empty list is the Masterplan-T4 acceptance target).

Other checks: broken wikilinks, strategy frontmatter completeness, legacy/invalid symbol
mentions (allow-listed to 3 files), and AI-ToDo routing tags (`@Claude/@Codex/@Antigravity/@OWNER`).

**Migration-relevant implication:** the linear renumbering must NOT reintroduce any `P*`
token on an active page. Storage keeps legacy `P*` keys (directive §3 / CLAUDE.md), but those
live in code/DB, never in vault operator surfaces. When old gate pages are rewritten, keep
Qxx-only; if any page must preserve a literal old `P*` example, it has to be archived under
`_ARCHIV/` (where the check is skipped) rather than kept active.

---

## 4 · The Schienenplan linter failure — token + disposition

**Page:** `12 ToDo/13_Schienenplan_2026-08-22.md`
**Linter output:** `old gate token in active page: 12 ToDo/13_Schienenplan_2026-08-22.md`

**Offending tokens (all occurrences):** the priority labels `P0`, `P1`, `P2` used as
Priorität-0/1/2 markers — NOT gate references. Confirmed matches (line : token):

- L73 `P0`,`P1`,`P1`,`P2` (Reihenfolge-Logik prose)
- L77 `P0`, L78 `P1`, L79 `P1`, L80 `P1`,`P2`, L81 `P2` (track priority table)
- L139 `P0` (`### Track A … (P0)`)
- **L188 `P1`** (`### Track B — News-Determinismus (P1)`) — this is the "line ~180" occurrence
- L259 `P1`, L329 `P1`,`P2`, L446 `P2`, L558 `P0`

The regex cannot distinguish a priority label `(P1)` from a legacy gate token `P1`; both are
"P" + digit as a standalone token. Every hit here is a **priority label**, so this is a
**false positive**, not a real old-gate-token leak.

**Disposition: EDIT, not archival.** The Schienenplan is a current (2026-08-22) track/roadmap
planning page, one day older than the rebaseline directive and still live board content — it
is not superseded. Fix by renaming the priority notation to a non-colliding form, e.g.
`Prio-0/1/2`, `PRIO 1`, or `Priorität 1`, throughout the page (headers + table + prose). That
clears the lint without weakening meaning. Archival would wrongly imply the plan is retired.

(Note: this fix is a vault edit and is out of scope for this inventory task — flagged here for
the OWNER/migration Vorlage, not performed.)

---

## 5 · Archive (`_ARCHIV`) convention

- **Folder:** `G:/My Drive/QuantMechanica - Company Reference/_ARCHIV/`.
- **Structure:** mirrors the vault's numbered top-level folders. Existing subfolders:
  `_ARCHIV/03 Pipeline/` (currently empty), `_ARCHIV/08 Current State/`,
  `_ARCHIV/10 Morning Briefing/`, `_ARCHIV/Agent Tasks/`, `_ARCHIV/Root/`, plus loose dated
  files. **Convention: a superseded page moves to `_ARCHIV/<its original numbered subfolder>/`**
  keeping its filename (usually date-stamped).
- **Linter interaction:** `_ARCHIV` is excluded from `check_forbidden_active_terms`
  (`active_only=True`). Archived pages may therefore retain legacy `P*`/old-role tokens without
  failing lint. Wikilink checks still run across all files (archive included), so moving a page
  can create broken links from active pages — update or drop inbound links when archiving.
- **Manifest:** `00 Governance/company_manifest.json` has no dedicated archive key; the
  convention is filesystem/folder-based, not manifest-driven.

**Pages recommended for archival as part of the migration:** none of the Q-gate pages, and
neither hub page — the migration rewrites those in place (directive §3 requires old IDs keep
their meaning via `gate_contract_version`, which is best served by an in-place rewrite plus a
frozen diff, not deletion). The only genuine archive candidate encountered is the dated import
`08 Current State/FTMO Hindernisse-Analyse 2026-08-16 (Import).md` (optional, housekeeping —
not required by the rebaseline). Once the linear contract ratifies, `Gate Manifest v3 Diff.md`
should be **frozen as historical** (kept in place or moved to `_ARCHIV/03 Pipeline/`) with a
successor v3→linear diff added.

---

## 6 · Proposed linear target order (informational — OWNER ratifies final IDs)

Directive §3: exact new numbers come out of the inventory and must not be cosmetically
pre-shifted; §7.6 requires an OWNER Vorlage for final IDs. The following is the strictly
monotone 3-phase skeleton the pages must express (old ID in parentheses):

```
Phase 1 — Strategie beweist sich
  Research Intake            (Q00)
  Build & Spec               (Q01)
  Baseline Screening         (Q02)   ← hard economic filter, terminal FAIL stays terminal
  Parameter Sweep            (Q03)
  Walk-Forward + Commission  (Q04)
  Gross Full-History Robust. (Q05)
  Stress HARSH               (Q06)
  Multi-Seed                 (Q07)
  Davey Statistical Valid.   (Q08)
  Baseline Full Run          (Q10A → gets a real linear number, evidence role only)

Phase 2 — Strategie wird optimiert / requalifiziert
  News Impact + FTMO Rec.    (Q09)   ← now AFTER Baseline Full Run (fixes "Q10A before Q09")
  Incumbent Full-Hist Conf.  (Q10)   ← dependency only CONFIG_LOCKED
  Pattern Filter Selection   (Q14)
  Parameter Optimization&Frz (Q15)
  Challenger Q02→Q10         (sub-cascade)
  Best-Settings Head-to-Head (Q16)   ← successor is the next higher number, NOT a jump back

Phase 3 — Strategie wird zum Buch bewertet
  Final Portfolio Constr.    (Q11)   ← book trigger: ≥25 qualified candidates AND OWNER order
  Operational Readiness      (Q12)
  Live Burn-In DXZ           (Q13)
```

This removes both named non-linearities (Q10A-before-Q09; Q16→Q11 back-jump). The actual
contiguous integer assignment (e.g. Q00…Q19) is the OWNER Vorlage deliverable, out of scope
for this doc-inventory task.

---

## 7 · Migration touch-list (documentation only)

1. Rewrite `Pipeline Overview.md` topology + repoint canonical source v2→v3→(linear).
2. Rewrite `Pipeline Operations Workflow.md`; fix the Q05 "Stress Medium" name drift; repoint v2.
3. Add the v3→linear column to `Gate Manifest v3 Diff.md`; freeze once linear ratifies.
4. Rewrite Q00–Q16 phase pages with new linear IDs + `gate_contract_version` framing; propagate
   the "historische ID während Rebaseline" banner already present on Q11/Q14 to all pages.
5. Reconcile `Mission Baseline.md` Q00–Q13 vs Q00–Q16 inconsistency; sweep `08 Current State/`
   range references and the `heartbeat_snapshot.py` counter labels.
6. Edit `12 ToDo/13_Schienenplan_2026-08-22.md`: rename priority `P0/P1/P2` → `Prio-0/1/2` to
   clear the linter false positive (edit, not archive).
7. Keep everything Qxx-only on active pages; any page needing a literal `P*` example goes to
   `_ARCHIV/`.

**No vault edits performed by this inventory.** All items above are the OWNER/migration Vorlage
backlog.

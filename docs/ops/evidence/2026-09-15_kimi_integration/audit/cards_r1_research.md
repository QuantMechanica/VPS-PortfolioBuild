# Audit — Internal Research Source (QM-RESEARCH, author Kimi) vs. R1 / R4 and the Strategy-Card tooling

Read-only audit. Truth precedence: code/runtime over repo contracts over Company Reference. Every claim carries a path plus line evidence; UNKNOWN where unverified. (Note: angle-bracket placeholders are written with braces, e.g. {id}, to keep this text machine-safe.)

---

## 1. The exact current R1 rule text(s) and enforcement points

### 1a. Canonical rubric — processes/qb_reputable_source_criteria.md
- Header (L1-4): "Binding for all G0 verdicts. This file is canonical — when vault pages or prompts disagree, this file wins."
- R1 (L27-60): "Single source per card (type is open)." Verbatim (L29-31): "PASS if the card has exactly ONE source attribution with a source_id in the frontmatter for lineage tracking. The type of source is open."
- AI-originated is first-class (L36-38): "AI-originated idea — source_id: AI-{agent}-{short-tag}-{YYYYMMDD} (e.g. AI-claude-mean-rev-fade-20260523), with the AI's prompt/output trail captured in strategy-seeds/sources/{source_id}/."
- Author track record NOT required (L54-56): "AI-developed and OWNER-developed ideas are first-class sources. The strategy will pass or fail on its own data in Q02-Q08."
- Missing source_id repair (L44-52): deterministic fallback OWNER-FABIAN-GRABNER-R1-RECOVERY-20260723.
- Rationale = lineage (L58-60): one source per card so a poisoned source can be traced.

Conclusion: R1 is already fully author/type-agnostic. An internal QM-RESEARCH source by Kimi satisfies R1 as written, provided the card carries a single non-empty source_id.

### 1b. Code enforcement — tools/strategy_farm/farmctl.py
- _card_r1_build_ready (L4229-4237): returns bool(str(fm.get("source_id") or "").strip()) — R1 build-readiness is solely "source_id is non-empty". Docstring: "Internet/book, OWNER, and AI sources are equally valid; only a missing source_id needs deterministic lineage repair."
- approve-card contract (L4464-4471): comment "DL-082 (2026-07-19): R1 source quality is informational, not a gate." Emits r1_source_id_missing only when _card_r1_build_ready is False (L4467-4468). R_STRICT_PASS_FIELDS = (r2_mechanical, r3_data_available, r4_ml_forbidden) (L4219) — R1 excluded; only R2/R3/R4 must equal PASS (L4469-4471).
- r1_track_record frontmatter (L4218, L4573): kept as a label; approve_card writes r1_track_record: UNKNOWN when body coverage is incomplete (L33713-33716) — confirming it is not a pass/fail gate.

### 1c. Paper gate — tools/strategy_farm/card_intake_prescreen.py
Docstring (L8-14) and evaluate_card (L492-559) contain no source/R1 check at all. Gates: duplicate (L501-513), target symbols (L515-521), external feeds (L523-525), charter sections (L527-529), expected_dd_pct 0 to 10 (L531-535), timeframe box (L537-539), prohibited mechanics (L541-543). An internal source_id is invisible to this gate.

### 1d. Prompts (defer to 1a)
- prompts/codex_g0_review.md L34-43: "Treat R1 as informational lineage, never as a reputation gate... If source_id is absent, set it to OWNER-FABIAN-GRABNER-R1-RECOVERY-20260723."
- prompts/claude_research_source.md L35-38, L67-73: anonymous / OWNER / AI sources valid; never reject for reputation.
- prompts/codex_research_source.md L96-99: "every draft must carry one source_id, but ... OWNER ideas, and AI ideas are all valid."
- prompts/mailbox_source_intake_prompt.md L54: "R1 informational lineage (book/web/forum, OWNER, or AI are valid; backfill OWNER if absent)."
- prompts/codex_review_ea.md L215: reviewers explicitly "NOT checking R1-R4 reputable-source criteria."

### 1e. Working precedent for an internal AI source
strategy-seeds/sources/AI-CODEX-XTIXNG-WCLVDIV-RV-20260906/source.md frontmatter already carries source_id, a free-text source_type government_peer_reviewed_bounded_mechanization, parent_sha256, and approval_basis decisions/2026-09-06_xtixng_...source_approval.md. So an internal, durable, sha256-stamped, decision-anchored source is an established pattern.

Net for deliverable 1: No R1 rule text blocks an internal Kimi source. The only R1 requirement is a single non-empty source_id.

---

## 2. Minimal additive design for source_type=internal_research (external cards unchanged)

Because R1 already passes on any non-empty source_id, the design is mostly namespacing plus one prescreen scoping fix; it changes nothing for external cards.

### 2a. Card frontmatter (additive, non-gating)
- source_id: QM-RESEARCH-{id}   (or AI-KIMI-{tag}-{YYYYMMDD}, matching the L36 convention)
- source_type: internal_research   (new, informational label)
- source_author: Kimi   (preserves internal attribution)
- source_uri: QM-RESEARCH://{id}
- source_sha256: {hex}   (of the durable artifact, see section 3)

External cards keep source_id: {book/paper/forum} plus sources: wiki backlinks unchanged. The reserved QM-RESEARCH-/AI-KIMI- prefix is what keeps internal vs external distinguishable for lineage audit — so external attribution is not weakened.

### 2b. Validator changes
- card_intake_prescreen.py _affirmative_prohibited_mechanics (L464-489): scope the ML text-scan (L471-474, L483-489) to the mechanics/rules sections, or exclude a provenance/source section, so an affirmative description of ML-derived research provenance stops emitting PROHIBITED_MECHANICS:ML. Keep the r4_ml_forbidden frontmatter check (L466-469) and the runtime-mechanics ML check. This is the only strictly-required code change.
- farmctl.py _card_r1_build_ready / approve-card contract: no change — already passes.
- farmctl.py VALID_SOURCE_TYPES (L33580-33583): OPTIONAL — add internal_research only if a routable DB sources row via add-source is wanted. AI cards today skip the DB row (card plus decisions only), so this can be deferred.

### 2c. Tests to add
- tests/test_card_intake_prescreen.py: card with source_id QM-RESEARCH-{id} plus an affirmative ML-provenance sentence returns KEEP (no PROHIBITED_MECHANICS:ML) after the scoping fix.
- approve-card contract test: internal source_id passes; r1_source_id_missing fires only when blank.
- Regression: external book/paper card validates unchanged.
- Lineage: QM-RESEARCH- id preserved distinctly through strategy_card_fingerprint (L4548-4566).

---

## 3. Where the QM-RESEARCH-{id} artifact store should live

Follow the existing convention (evidenced by AI-CODEX sources):
- Durable artifact (git-tracked, C:): strategy-seeds/sources/QM-RESEARCH-{id}/source.md — findings plus prompt/output trail, author Kimi. Frontmatter carries the self sha256. (Mirrors strategy-seeds/sources/AI-CODEX-.../source.md.)
- sha256 plus immutability: record the sha256 and approval in decisions/YYYY-MM-DD_qm_research_{id}_source_approval.md — decisions/ is immutable once dated (repo map), matching decisions/2026-09-06_xtixng_...source_approval.md. The decision receipt sha256 is the integrity authority (the source.md file itself is a normal mutable repo file; rely on sha256 plus git history, not filesystem immutability).
- AI prompt trail (runtime): D:/QM/strategy_farm/artifacts/source_notes/{source_id}.md per the research prompts (claude_research_source.md L86).
- Do NOT place the sole copy under D:/QM/strategy_farm/artifacts/ — that tree is not version-controlled; the durable copy must be in the repo.

Card locations are unchanged: drafts to cards_draft/ to G0 to cards_approved/ (D: authoritative, with a C: repo mirror at C:/QM/repo/artifacts/cards_approved/).

---

## 4. R4 — runtime ML (forbidden) vs. research provenance (allowed), and the wording fix

### 4a. Runtime ML enforcement is scoped to EA code only
framework/scripts/build_check.ps1 Invoke-ForbiddenScan (L888-960):
- Scans .mq5/.mqh only (L874-881).
- Blanks comments then string literals before matching (L942-947) — rationale at L901: "Detection is done on comment-blanked text (prose describing ML is not ML)."
- Patterns (L906-931): ML library include/import, serialized model artifact, inference/training API, learning-rate, stored-parameter-updated-from-learning-signal.
- Scoping note (L888-901, ticket 690fc42a): "Identifier NAMES are not evidence of ML."

### 4b. Review prompts confirm runtime-only R4
prompts/codex_review_ea.md section F (L155-168): hard ML in mq5 always FAIL; static/const weight arrays OK (L159-163); ambiguous becomes [R4-ADVISORY], not FAIL (L164-168). prompts/claude_review_ea.md L88-89 (no neural net calls / no adaptive params). Reviewers are told they are not checking R1-R4 source criteria (codex_review_ea.md L215).

### 4c. Card-level R4
card_intake_prescreen._affirmative_prohibited_mechanics (L464-489): trips ML if r4_ml_forbidden frontmatter is false/fail (L466-469) OR an affirmative (non-negated) ML term appears anywhere in the card text (L471-474, L483-489).

### 4d. The distinction is already structurally clean, but one wording/scoping change is needed
Runtime ML lives in .mq5/.mqh (build_check plus review); research provenance lives in .md cards / source.md / decisions/ — never scanned by build_check. So Kimi being an AI/ML research author does not trip runtime R4. The gap is card-side: the prescreen scans the whole card body, so an internal-research card that says e.g. "signal derived via a neural-network-informed study" in affirmative prose would be falsely rejected. Change wording only:
- In qb_reputable_source_criteria.md R4 (L105-133): state R4 forbids ML in the EA runtime logic, and that an ML-assisted research provenance is explicitly not an R4 concern (mirror the build_check L888-901 comment).
- Correspondingly scope the prescreen ML text-scan (section 2b) so provenance prose is not affirmative-matched.

---

## 5. Risks
1. False R4 rejection (concrete blocker): card_intake_prescreen._affirmative_prohibited_mechanics (L464-489) scans full card text; affirmative ML-provenance prose to PROHIBITED_MECHANICS:ML to moved to cards_rejected on --apply.
2. Attribution erosion: reusing the OWNER recovery fallback id or omitting author makes internal/external lineage unauditable. Mitigate with reserved QM-RESEARCH-/AI-KIMI- namespace plus mandatory source_author.
3. Dedupe collision: strategy_card_fingerprint (L4548-4566) folds source_id in; a shared umbrella id across many child ideas inflates near-duplicate hits — use one child id per idea.
4. DB lane mismatch: add_source (L33597-33601) rejects source_types outside VALID_SOURCE_TYPES (L33580-33583). A routable DB internal lane needs the tuple extended; otherwise keep card+decisions-only.
5. Immutability gap: decisions/ is immutable once dated, but strategy-seeds/sources/{id}/source.md is mutable; integrity rests on recorded sha256 plus git history.
6. Location drift: prescreen/approve-card default to D: (non-VC); the durable source artifact must live in the repo (strategy-seeds/sources/).

## Unknowns
- Whether a routable DB sources row (extending VALID_SOURCE_TYPES) is wanted, or card+decisions-only (AI-source precedent). No internal_research/QM-RESEARCH token exists in code today.
- Exact id form: AI-KIMI-{tag}-{date} (documented convention, L36) vs QM-RESEARCH:// URI vs both.
- Whether internal cards need an extra provenance section vs. the existing six charter sections (L379-425).
- Lessons-learned placement: binding change belongs in qb_reputable_source_criteria.md, not lessons-learned/ (which cannot override a gate, per its README); an accompanying lessons entry is optional and unconfirmed.
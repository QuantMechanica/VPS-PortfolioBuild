# Internal Research Source Contract (QM-RESEARCH)

**Status:** CANONICAL. Binding for every Strategy Card whose origin is QuantMechanica's own
internal research (Kimi-authored or otherwise AI/tool-authored edge discovery).
**Authority:** `decisions/2026-09-15_owner_kimi_integration_ml_research_r1_internal.md`
(decision id `OWNER-DEC-KIMI-INTEGRATION-20260915`, decision 2), directive verbatim
`docs/ops/evidence/2026-09-15_kimi_integration/owner_directive_verbatim.md` §1.2, §12, §14.
**Truth precedence:** this file is subordinate only to a current explicit OWNER instruction and
to `processes/qb_reputable_source_criteria.md` (the R1–R4 rubric, which this contract *annexes*,
never overrides). Where this file and a Vault page disagree, `qb_reputable_source_criteria.md`
wins for gate semantics and this file wins for the internal-source artifact layout.
**Do not re-litigate:** the OWNER has ruled that a verifiable internal Kimi-authored research
artifact satisfies R1; "Do not escalate this interpretation back to OWNER as an unresolved
question" (directive §1.2). External attribution is unchanged.

---

## 1. Scope and the invariant

There are exactly two source classes and this contract touches only the first:

| Class | source_id prefix | R1 satisfied by | Changed by this contract? |
|---|---|---|---|
| **Internal research** | `QM-RESEARCH-YYYY-NNNN` | a durable, content-addressed internal artifact authored inside QuantMechanica | YES — this is the new class |
| **External** | book / paper / forum / video / `AI-<agent>-<tag>-<date>` etc. | verifiable external attribution (unchanged) | NO — external rules stay verbatim |

**The invariant (directive §1.2, §14):** external attribution requirements are *not weakened*.
An external card that cites no verifiable source still fails exactly as today. The only thing
added is a *new, reserved, self-describing namespace* whose provenance lives entirely inside the
repo. Because R1 is already source-agnostic on author (see §7), the gate change is minimal; the
weight of this contract is in the artifact store, the ledger, the resolver, and the ML-scan
scoping fix.

**What R1 already is (verified):** `farmctl.py:4229-4237` `_card_r1_build_ready(fm)` returns
`bool(str(fm.get("source_id") or "").strip())` — build-readiness is solely "source_id non-empty".
`R_STRICT_PASS_FIELDS = ("r2_mechanical", "r3_data_available", "r4_ml_forbidden")`
(`farmctl.py:4219`) — R1 is deliberately excluded from the strict pass set; DL-082 (2026-07-19)
made R1 informational. So no new *pass logic* is required for a Kimi source; the work is making
the source **durable, resolvable, hash-bound, and not falsely ML-rejected**.

---

## 2. Research ID format and reference form

### 2.1 Canonical id — `QM-RESEARCH-YYYY-NNNN`

```
QM-RESEARCH-2026-0042
└────┬───┘ └┬┘ └─┬─┘
 fixed literal  year  zero-padded 4-digit monotonic counter within that year
```

- Regex (authoritative): `^QM-RESEARCH-(20\d{2})-(\d{4})$`.
- `YYYY` = UTC year of minting (matches the ledger `created` date).
- `NNNN` = next free integer for that year, zero-padded to 4, allocated by
  `research_source.py mint` against `research_source_ledger.jsonl` (§6). Never reused, never
  re-numbered — a retired id stays burned.
- This is the value written to the card frontmatter `source_id` field, so all existing
  source_id-keyed tooling (`_card_r1_build_ready`, `strategy_card_fingerprint`, lineage repair)
  keeps working unchanged (§8).

**One id = one idea.** Do not mint an umbrella id for a family of child hypotheses: the coarse
`strategy_card_fingerprint` (`farmctl.py:4548-4566`) folds `source_id` into its hash, so a shared
id across many child cards inflates near-duplicate collisions (§8.3). Mint one child id per
distinct mechanical thesis.

### 2.2 Reference form — `QM-RESEARCH://<id>`

- The card carries the resolvable URI in `source_artifact` (and optionally a `source_uri`
  mirror): `QM-RESEARCH://2026-0042`.
- `research_source.py resolve QM-RESEARCH://2026-0042` → the absolute durable path
  `strategy-seeds/sources/QM-RESEARCH-2026-0042/`.
- The `QM-RESEARCH://` scheme is the *only* accepted internal-artifact reference form. A bare
  `source: Kimi` (or `source_author: Kimi` with no resolvable `source_artifact`) is INVALID by
  OWNER decision (directive §1.2: "Never use: `source = Kimi` without a resolvable research
  artifact behind it").

---

## 3. Durable store layout

Follows the established in-repo AI-source convention (precedent verified:
`strategy-seeds/sources/AI-CODEX-XTIXNG-WCLVDIV-RV-20260906/source.md`, carrying `source_id`,
free-text `source_type`, `parent_sha256`, `approval_basis` → a dated `decisions/` receipt).

```
strategy-seeds/sources/QM-RESEARCH-2026-0042/          (git-tracked, on C:, canonical)
├── source.md              # the research artifact (human-readable), frontmatter + provenance + mechanization
├── research.json          # machine record: full directive §1.2 + §12 field set, self-sha256 excluded
├── critic_receipt.json    # cross-vendor critic outcome (non-Kimi critic; §5)
└── lineage.json           # discovery→hypothesis→mechanization→preregistration lineage, parent links
```

Rules:
- **Durable copy is in the repo, on C:.** Never place the sole copy under
  `D:/QM/strategy_farm/artifacts/` — that tree is not version-controlled (cards_r1_research audit
  §3). The runtime prompt/output trail *may* additionally live at
  `D:/QM/strategy_farm/artifacts/source_notes/<id>.md` per the research prompts, but it is a
  mirror, not the source of record.
- **Integrity authority = recorded sha256 + git history**, not filesystem immutability:
  `source.md` is a normal mutable repo file. Its sha256 is recorded in `research.json`, in the
  ledger, and (for a preregistered/carded source) in a dated `decisions/` receipt which *is*
  immutable once dated (repo map convention). This mirrors how
  `decisions/2026-09-06_xtixng_..._source_approval.md` anchors the AI-CODEX precedent.
- **Card locations unchanged:** `cards_draft/` → G0 → `cards_approved/` (D: authoritative, C:
  repo mirror at `C:/QM/repo/artifacts/cards_approved/`). The card *references* the store; it does
  not live in it.

---

## 4. Schema tables

### 4.1 `source.md` frontmatter (the card-facing provenance header)

| Field | Type | Required | Who fills | Validation rule |
|---|---|---|---|---|
| `source_id` | string | YES | `research_source.py mint` | matches `^QM-RESEARCH-20\d{2}-\d{4}$`; equals the directory name |
| `title` | string | YES | Kimi (creator) | non-empty |
| `source_type` | literal | YES | mint | exactly `internal_research` |
| `source_author` | string | YES | mint | non-empty; `Kimi` for Kimi-authored (directive §1.2) |
| `source_model` | string | YES | adapter (captured per run) | exact Kimi model alias, e.g. `kimi-code/kimi-for-coding` (K2.8) — from the run, never guessed |
| `created` | date (UTC) | YES | mint | ISO date; equals ledger `created` |
| `originating_task_id` | string | YES | adapter | the `agent_tasks.id` that produced the artifact |
| `self_sha256` | hex64 | YES | `research_source.py verify` re-computes | sha256 of `source.md` with this line blanked (§7); recorded in `research.json` |
| `status` | enum | YES | ledger-driven | one of `draft\|reviewed\|preregistered\|carded\|retired` (§6) |
| `parent_source_ids` | list | no | Kimi / mint | each resolvable (external id or another `QM-RESEARCH-…`) |
| `## Research provenance` | section (body) | YES | Kimi | the section exempt from the ML-term scan (§9, §11) |

External cards keep `source_id: <book/paper/forum>` and `sources:` backlinks unchanged — none of
the above applies to them.

### 4.2 `research.json` — machine record (union of directive §1.2 minimum and §12 full set)

`schema: "qm.internal-research-source/v1"`

| Field | Type | Required | Who fills | Validation rule |
|---|---|---|---|---|
| `schema` | literal | YES | mint | `qm.internal-research-source/v1` |
| `research_id` | string | YES | mint | equals `source_id` |
| `author` | string | YES | mint | non-empty (`Kimi`) |
| `model` | string | YES | adapter | exact model+version if available; else `UNKNOWN` (never invented) |
| `created_utc` | ISO-8601 | YES | mint | UTC timestamp |
| `originating_task_id` | string | YES | adapter | `agent_tasks.id` |
| `research_question` | string | YES | Kimi | non-empty (§12) |
| `source_datasets` | list[obj] | YES | Kimi/observe | each `{dataset_id, path, sha256}` pointing at an OBSERVE dataset manifest (§ Edge Discovery design) |
| `evidence_paths` | list[str] | YES | Kimi | absolute paths under `D:/QM/reports` or the dataset store |
| `evidence_hashes` | map | YES | mint | sha256 per evidence path; fails closed if any missing (§7) |
| `ml_method` | string\|null | cond. | Kimi | the ML/statistical method if used (directive §11); null if none |
| `observations` | string | YES | Kimi | the empirical finding (§12) |
| `proposed_mechanism` | string | YES | Kimi | the economic/causal hypothesis (directive §12, §15) |
| `candidate_edge` | string | YES | Kimi | the tradeable claim in words |
| `confidence` | string | YES | Kimi | free-text uncertainty statement (§12) |
| `confounders` | list[str] | YES | Kimi | likely confounders (§12, feeds the critic) |
| `related_strategies` | list[str] | YES | Kimi | ea_id / source_id of similar existing QM strategies (§15, §19 redundancy) |
| `critic_receipt` | string | YES | chain | relative path to `critic_receipt.json`; must exist for status ≥ `reviewed` |
| `lineage` | string | YES | mint | relative path to `lineage.json` |
| `search_history_ref` | string | YES | Kimi/observe | pointer into the search-history ledger (data-snooping defence, directive §18); reuses the `qm.dsr-cohort/v1.search_history` shape (`dsr_cohort.py:758-768`) |
| `self_sha256` | hex64 | YES | verify | sha256 of `source.md` (§7) |

**"Missing hash fails closed"** (directive §14): if `evidence_hashes` cannot be computed for
every path in `evidence_paths`, or `self_sha256` is absent, `research_source.py verify` returns a
hard failure and the card is not build-ready for the internal class.

### 4.3 `critic_receipt.json` — cross-vendor critic outcome

`schema: "qm.agent-chain.receipt.v1"` (reuses the existing chain receipt; verified fields
`router_providers` audit §6). Contract-relevant fields for an internal source:

| Field | Type | Required | Who fills | Validation rule |
|---|---|---|---|---|
| `chain_id` | string | YES | agent_chain | non-empty |
| `creator_vendor` | string | YES | agent_chain | `kimi` for a Kimi-authored source |
| `critic_seat_final` | string | YES | agent_chain | vendor **≠** `kimi` (directive §8: a Kimi-authored hypothesis must receive a non-Kimi critic) |
| `critic_verdict` | string | YES | critic seat | informational; an LLM "PASS" is never a pipeline PASS (directive §7) |
| `finding_counts` | obj | YES | agent_chain | per-severity counts |
| `scope_drift` | bool | YES | agent_chain | critic wrote nothing to the repo (read-only critic invariant) |
| `generated_at_utc` | ISO-8601 | YES | agent_chain | — |

Validation coupling: `research_source.py verify` rejects (fails closed) if `creator_vendor == kimi`
and `critic_seat_final == kimi`, or if `critic_receipt.json` is absent while the ledger `status`
is `reviewed` or later.

### 4.4 `lineage.json` — hypothesis lineage & preregistration link

`schema: "qm.research-lineage/v1"`

| Field | Type | Required | Who fills | Validation rule |
|---|---|---|---|---|
| `schema` | literal | YES | mint | `qm.research-lineage/v1` |
| `research_id` | string | YES | mint | equals `source_id` |
| `version` | int | YES | mint | 1 at first mint; +1 per new lineage version (§6 immutability) |
| `parent_version_id` | string\|null | YES | mint | the prior `QM-RESEARCH-…` id when this is a re-mint; null for v1 |
| `discovery_sample` | obj | YES | Kimi | `{period, instruments, dataset_ids}` used for discovery (directive §16) |
| `validation_sample` | obj | YES | Kimi | the held-out period/instruments not used in discovery (§16, §18) |
| `preregistration` | obj\|null | cond. | prereg tool | `{frozen_at_utc, param_count, param_ranges_sha256, success_criteria, failure_criteria}`; required before validation (directive §16) |
| `mechanization` | obj | YES | Kimi | pointer to the mechanical spec section + Codex-implementability assertion (directive §13) |

---

## 5. Cross-vendor critic requirement (linkage to the chain)

Per directive §8 and §15, an internal source is not `reviewed` until a **non-Kimi** critic has
attacked it. The critic is read-only; it does not mutate `agent_tasks`, verdicts, evidence,
pipeline state or repo code. `critic_receipt.json` is the durable evidence and is referenced from
`research.json.critic_receipt`. The `agent_chain.v1.json` `by_creator_vendor.kimi` table must list
only non-kimi seats (Fable design D4). `research_source.py verify` enforces the non-kimi critic
as a hard rule (§4.3). This is *evidence for Fable's preregistration decision*, not a gate — an
LLM PASS is never a pipeline PASS (directive §7).

---

## 6. The append-only ledger — `research_source_ledger.jsonl`

Path: `D:/QM/reports/state/research_source_ledger.jsonl`. `schema: "qm.research-source-ledger/v1"`.
One JSON object per line, append-only (mirrors the proven `tester_memory_ledger.jsonl` /
`kimi_usage_ledger.jsonl` conventions).

| Field | Type | Required | Notes |
|---|---|---|---|
| `schema` | literal | YES | `qm.research-source-ledger/v1` |
| `id` | string | YES | `QM-RESEARCH-YYYY-NNNN` |
| `created` | ISO-8601 | YES | UTC mint time |
| `author` | string | YES | e.g. `Kimi` |
| `model` | string | YES | exact model; `UNKNOWN` allowed, never invented |
| `task_id` | string | YES | originating `agent_tasks.id` |
| `sha256` | hex64 | YES | `self_sha256` of `source.md` at this ledger event |
| `status` | enum | YES | `draft\|reviewed\|preregistered\|carded\|retired` |
| `version` | int | YES | matches `lineage.json.version` |
| `parent_version_id` | string\|null | YES | prior id when this is a re-mint |
| `event` | enum | YES | `mint\|status_change\|reversion` |

### 6.1 Status lifecycle

```
draft ──(non-kimi critic receipt attached)──► reviewed
reviewed ──(preregistration frozen, §16)────► preregistered
preregistered ──(Strategy Card created)─────► carded
any ──(idea abandoned / superseded)─────────► retired
```

Backtest verdicts never write here; this ledger is pre-Q00 provenance only. Once `carded`, the
normal deterministic Q00–Q17 pipeline is the sole judge — Kimi authorship confers no gate
advantage (directive §17).

### 6.2 Immutability rule (directive §16)

The ledger is **append-only**. A row is never edited in place; a status change is a new appended
`status_change` event carrying the same `id` and a bumped `version` where the artifact content
changed. **Any edit to the frozen research content after preregistration = a new lineage version
with a new id and a `parent_version_id` link** — you may not modify the hypothesis and pretend
the new version was the original (directive §16). `research_source.py` refuses to overwrite an
existing `source.md` whose recorded sha256 differs from the on-disk file unless invoked as an
explicit `re-mint` that allocates a fresh id.

---

## 7. Hashing rules

- **Algorithm:** SHA-256, lowercase hex, over UTF-8 bytes.
- **`self_sha256` of `source.md`:** computed with the `self_sha256:` frontmatter line **blanked**
  (replaced by an empty value) so the file can carry its own hash without a fixpoint problem.
  `verify` re-blanks and re-computes; a mismatch fails closed.
- **Evidence hashes:** every path in `research.json.evidence_paths` and every
  `source_datasets[].path` gets its own sha256 in `evidence_hashes` / `source_datasets[].sha256`.
  A missing or unreadable evidence file → hard `verify` failure (directive §14 "missing hash …
  fails closed").
- **Card ↔ source binding:** the card's `source_hash` frontmatter field **must equal**
  `research.json.self_sha256` for the referenced id. `research_source.py verify --card <path>`
  recomputes the store's `self_sha256` and compares; a drift means the card points at a version
  that no longer matches the store → fails closed. This is what makes the reference *verifiable*
  and clears the hallucination-precedent bar (agy video links are not R1 evidence,
  `OPERATING_RULES_2026-07-03.md:27`): the internal artifact is durable, content-addressed and
  independently readable.
- **Preregistration binding:** `lineage.json.preregistration.param_ranges_sha256` freezes the
  allowed parameter ranges so a later widening is detectable.

---

## 8. Strategy Card linkage

### 8.1 Card frontmatter (internal class)

```yaml
source_id:      QM-RESEARCH-2026-0042        # keeps every source_id-keyed tool working
source_type:    internal_research            # informational label (new)
source_author:  Kimi
source_model:   kimi-code/kimi-for-coding    # exact model, from the run
source_artifact: QM-RESEARCH://2026-0042     # resolvable reference
source_hash:    <sha256 == research.json.self_sha256>
```

Plus the existing mandatory card fields, unchanged: `r1_track_record` (may be `UNKNOWN` for an
internally-authored card — it is not a gate), `r2_mechanical`, `r3_data_available`,
`r4_ml_forbidden: PASS` (the *EA* is ML-free; see §10–§11). `STRATEGY_CARD_REQUIRED_FRONTMATTER`
(`farmctl.py:4569+`) is unchanged; the four fields above are additive.

### 8.2 Why existing tooling keeps working

- `_card_r1_build_ready` (`farmctl.py:4229-4237`) sees a non-empty `source_id` → build-ready. No
  change.
- `approve-card` R-strict set excludes R1 (`R_STRICT_PASS_FIELDS`, `farmctl.py:4219`); only
  R2/R3/R4 must equal PASS. No change.
- Lineage repair fallback (`OWNER-FABIAN-GRABNER-R1-RECOVERY-20260723`) never triggers because the
  id is present. No change.

### 8.3 Fingerprint / dedupe collisions

`strategy_card_fingerprint` (`farmctl.py:4548-4566`) hashes
`source_id | slug | universe | timeframe | thesis_terms`. Because each internal idea gets its own
`QM-RESEARCH-…` id, the reserved namespace *increases* dedupe fidelity: two genuinely distinct
Kimi ideas cannot collide on the source component. The failure mode to avoid (audit §5.3) is a
shared umbrella id across child ideas — forbidden by §2.1 (one id per idea). External cards'
fingerprints are unaffected.

---

## 9. Validator behaviour

### 9.1 `research_source.py` (new tool, `tools/strategy_farm/research_source.py`)

| Subcommand | Behaviour | Fail-closed cases |
|---|---|---|
| `mint` | allocate next `QM-RESEARCH-YYYY-NNNN`, scaffold the store dir, write `research.json`/`lineage.json` stubs, append a `draft` ledger row | refuses if id already in ledger; refuses if `author`/`model`/`task_id` missing |
| `resolve QM-RESEARCH://<id>` | print the absolute store path | non-existent id → non-zero exit, `NOT_FOUND` |
| `verify [--card <path>]` | recompute `self_sha256` and evidence hashes; check critic (non-kimi) present for status ≥ reviewed; when `--card` given, compare card `source_hash` to store | any hash mismatch, missing evidence hash, missing `self_sha256`, kimi-critic-on-kimi-creator, or absent artifact → non-zero exit |

### 9.2 `farmctl VALID_SOURCE_TYPES`

`farmctl.py:33580-33583` currently `("book","paper","web_forum","web_blog","mql5_codebase",
"mql5_articles","video","local_archive")`; `add_source` (`:33587-33607`) rejects any other type.
**Add `"internal_research"`** to the tuple so a routable DB `sources` row can be created for an
internal lane. `add_source` then accepts it; the `--source-type` argparse choices
(`farmctl.py:38232`) pick it up automatically from `VALID_SOURCE_TYPES`. (Cards-plus-decisions
without a DB row remains valid too, per the AI-CODEX precedent; the DB row is optional but wanted
for a routable discovery lane.)

### 9.3 `card_intake_prescreen` — ML-term scan scoping (the one strictly-required gate fix)

`_affirmative_prohibited_mechanics` (`card_intake_prescreen.py:464-489`) currently scans the
**whole** card text (`scan_text = ... document.text`, line 483) for ML terms
(`machine learning|random forest|neural network|xgboost|lstm|hidden markov|viterbi`, line 472) and
appends `PROHIBITED_MECHANICS:ML` (via `evaluate_card`, lines 541-543). An internal-research card
that *truthfully describes* its ML-assisted provenance ("edge discovered via a random-forest
feature-importance study") would be falsely rejected.

**Fix (Fable design D5):** scope the affirmative ML text-scan to the *mechanics/rules* sections
and **exempt a `## Research provenance` section**. Concretely: before the per-line scan, strip the
body span from the `## Research provenance` heading to the next same-level heading, so provenance
prose is never affirmative-matched. Keep unchanged:
- the frontmatter `r4_ml_forbidden` / `ml_required` check (lines 466-469) — a card claiming the EA
  itself uses ML still trips ML;
- the HFT/GRID/MARTINGALE/AVERAGING patterns (still whole-card, unchanged);
- the runtime ML enforcement in `build_check.ps1` (§10).

Fail-closed cases after the fix:
- ML term in the **mechanics/entry/exit/rules** sections → still `PROHIBITED_MECHANICS:ML`.
- `r4_ml_forbidden: false` (or `ml_required: true`) in frontmatter → still `ML`.
- ML term only inside `## Research provenance` → **KEEP** (no ML finding).

---

## 10. R4 enforcement points that must NOT change

Runtime-ML enforcement is scoped to EA *code* and is untouched by this contract:

- `framework/scripts/build_check.ps1` `Invoke-ForbiddenScan` (L888-960) scans **`.mq5`/`.mqh`
  only** (L874-881), comment-blanks then string-blanks before matching (L942-947; rationale L901
  "prose describing ML is not ML"), and rejects ML library includes, serialized model artifacts,
  inference/training APIs, learning-rate, and PnL-learning-signal parameter updates (L906-931).
  "Identifier NAMES are not evidence of ML" (L888-901, ticket 690fc42a). **No change.**
- `prompts/codex_review_ea.md` §F (L155-168): hard ML in `.mq5` always FAIL; static/const weight
  arrays OK; ambiguous → `[R4-ADVISORY]`, not FAIL. **No change.**
- Card schema still requires `r4_ml_forbidden` and a valid internal card sets it `PASS` because
  the **EA** is ML-free. **No change.**

**The distinction that makes this safe:** runtime ML lives in `.mq5`/`.mqh` (scanned); research
provenance lives in `.md`/`source.md`/`decisions/` (never scanned by `build_check`). Kimi being an
ML-assisted research author therefore cannot trip runtime R4. The only gap was the card-side
whole-text prescreen scan, closed in §9.3. The MECHANIZE gate (directive §13) is the hard
boundary: no ML-discovered hypothesis enters Q00 while it still depends on a research model — it
must be reducible to explicit rules, finite bounded parameters, no inference API, no model file,
implementable by Codex from the card alone.

---

## 11. Canonical policy annex texts (paste-ready)

The following are written to be pasted verbatim into the named canonical documents. They *annex*;
they never alter historical evidence. The HR14 annex requires a dated DL + written OWNER approval
(Hard-Rule change); it is already authorized by
`decisions/2026-09-15_owner_kimi_integration_ml_research_r1_internal.md` decision 3.

### 11.1 Hard Rules — HR14 annex (`01 Identity/Hard Rules.md`, appended under rule 14)

> **Annex 2026-09-15 (OWNER-DEC-KIMI-INTEGRATION-20260915).** Hard Rule 14 is scoped: *no machine
> learning, neural networks, or adaptive parameters inside an EA or its live/backtest decision
> engine.* Machine learning and advanced statistics ARE permitted as **offline research
> instruments** for edge discovery (clustering, feature importance, regime detection, hypothesis
> generation, cross-experiment analysis). The permission never reaches trading logic: before a
> candidate enters Q00 it must be reduced to explicit mechanical rules — finite bounded
> parameters, deterministic entry/exit/risk/filter logic, no inference API, no model file, no
> online learning, no retraining, no adaptive black box. The final EA must be executable from its
> mechanical specification alone. Historical evidence is unchanged. This annex generalizes the
> already-repo statement in `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md:17-18` ("No ML inside the EA
> … the AIs are the research/development tools, never a model embedded in the EA") and
> `START_HERE` rule 8.

### 11.2 `processes/qb_reputable_source_criteria.md` — R1 annex (append under R1)

> **Internal-research sources (annex 2026-09-15).** A QuantMechanica-discovered edge does not
> require an external human author, book, paper, video or website to satisfy R1. For an internally
> discovered edge the canonical internal research artifact is the source. R1 PASSES for a card
> whose single `source_id` is a reserved internal id of the form `QM-RESEARCH-YYYY-NNNN`, provided
> the card also carries `source_type: internal_research`, `source_author`, `source_model`,
> `source_artifact: QM-RESEARCH://<id>` (resolvable), and `source_hash` (sha256 matching the
> durable artifact). `source = Kimi` (or any author name) WITHOUT a resolvable, hash-bound
> artifact is INVALID. The durable artifact lives at
> `strategy-seeds/sources/QM-RESEARCH-YYYY-NNNN/` and is governed by
> `docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md`. **External attribution is unchanged:** an
> external card still requires its verifiable external source exactly as before. This annex adds a
> namespace; it does not weaken external R1.

### 11.3 `processes/qb_reputable_source_criteria.md` — R4 annex (append under R4)

> **R4 scope clarification (annex 2026-09-15).** R4 (Hard Rule 14) forbids ML **in the EA runtime
> decision engine**. An ML-assisted *research provenance* — an edge discovered with ML/statistical
> methods and then reduced to explicit mechanical rules — is explicitly NOT an R4 concern. R4's
> in-EA reject list (neural nets, ONNX/inference, PnL-adaptive parameters, online/retraining
> logic, non-deterministic entries, unbounded martingale) stands verbatim. A card describing its
> ML-derived provenance in a `## Research provenance` section is not an R4 violation and must not
> be prescreen-rejected for it (see `INTERNAL_RESEARCH_SOURCE_CONTRACT.md` §9.3). Mirror of the
> `build_check.ps1` L888-901 principle: "prose describing ML is not ML."

### 11.4 `04 Processes/Research Methodology.md` — mirror + source-category row

> **R1 (mirror):** `QM-RESEARCH://<id>` is a valid verifiable reference type for internally
> authored strategies. **R4 (mirror):** governs the EA decision engine; offline research ML that
> outputs fixed mechanical rules is out of R4 scope. **Source category (new row):** *internal
> AI-authored research* — `source_type: internal_research`, id `QM-RESEARCH-YYYY-NNNN`, durable
> artifact under `strategy-seeds/sources/`, cross-vendor critic required, HR16 one-research-at-a-
> time unchanged.

### 11.5 `CLAUDE.md` — Hard Rules block cross-reference (append to the ML bullet)

> ML is forbidden **inside V5 EAs and their live/backtest decision engine** (HR14, annexed
> 2026-09-15). ML/statistics ARE allowed as offline research instruments; every candidate entering
> Q00 must be fully mechanical. Internal Kimi-authored research can satisfy R1 via a durable
> `QM-RESEARCH://<id>` artifact — see `docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md`.

---

## 12. Regression test matrix (directive §14 → test names)

Tests live in `tools/strategy_farm/tests/`. The five OWNER-mandated cases plus the coupling
checks:

| # | Directive §14 requirement | Test name | Assertion |
|---|---|---|---|
| T1 | external unattributed card still FAILS | `test_r1_external_unattributed_fails` | a card with no `source_id` is not build-ready (`_card_r1_build_ready` False) / prescreen flags missing lineage |
| T2 | external valid source PASSES | `test_r1_external_valid_passes` | book/paper card with `source_id` builds unchanged |
| T3 | valid Kimi internal research source PASSES | `test_r1_internal_research_valid_passes` | card `source_id=QM-RESEARCH-2026-0001`, resolvable artifact, matching `source_hash` → build-ready + `verify` OK |
| T4 | author=Kimi without durable artifact FAILS | `test_r1_internal_kimi_no_artifact_fails` | `source_author=Kimi`, `source_artifact` unresolvable / absent → `research_source.py verify` non-zero, card not build-ready for internal class |
| T5 | missing hash / provenance fails closed | `test_r1_internal_missing_hash_fails_closed` | `source_hash` absent or evidence hash unreadable → `verify` hard fail |
| T6 | prescreen ML scan scoping | `test_prescreen_ml_provenance_exempt` | card with ML term only inside `## Research provenance` → KEEP; ML term in mechanics → `PROHIBITED_MECHANICS:ML` |
| T7 | frontmatter ML still trips | `test_prescreen_r4_frontmatter_ml_trips` | `r4_ml_forbidden: false` → ML finding regardless of section |
| T8 | non-kimi critic invariant | `test_internal_source_critic_non_kimi` | `verify` rejects `critic_seat_final == kimi` for a kimi creator |
| T9 | VALID_SOURCE_TYPES accepts internal | `test_valid_source_types_internal_research` | `add_source(..., source_type="internal_research")` succeeds; unknown type still rejected |
| T10 | fingerprint distinctness | `test_fingerprint_internal_ids_distinct` | two distinct `QM-RESEARCH-…` ids do not collide in `strategy_card_fingerprint` |
| T11 | ledger immutability / re-mint | `test_ledger_append_only_remint` | editing frozen content after preregistration forces a new id + `parent_version_id`; no in-place overwrite |
| T12 | runtime ML still FAILS | `test_build_check_runtime_ml_rejected` | an `.mq5` with an inference call still fails `Invoke-ForbiddenScan` (unchanged) |

Use mocks/fixtures for the store and ledger; do not burn Kimi subscription capacity to test these
(directive §22).

---

## 13. Worked examples

### 13.1 Valid internal card frontmatter

```yaml
---
ea_id: QM5_41xxx
slug: xau-regime-gap-fade-d1
g0_status: PENDING
r1_track_record: UNKNOWN            # informational, not a gate
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS               # the EA is ML-free
expected_trades_per_year_per_symbol: 22
source_id: QM-RESEARCH-2026-0042
source_type: internal_research
source_author: Kimi
source_model: kimi-code/kimi-for-coding
source_artifact: QM-RESEARCH://2026-0042
source_hash: 7f3a...e91c            # == research.json.self_sha256
---

## Research provenance
Edge discovered via a random-forest feature-importance study over the OPT_CENSUS
dataset (dataset_id DS-2026-0042, sha256 …). ML was used only to rank features;
the resulting rule set below is fully deterministic. Cross-vendor critic:
critic_receipt.json (creator=kimi, critic=claude sonnet).

## Structural cause
… (mechanical thesis; no ML terms here) …
```

`_card_r1_build_ready` → True (source_id present). `research_source.py verify --card <path>` →
OK (hash matches, artifact resolves, non-kimi critic present). Prescreen → KEEP (the
"random-forest" mention is inside `## Research provenance`, exempt).

### 13.2 Invalid — author=Kimi without a resolvable artifact

```yaml
source_id: kimi-idea-42
source_author: Kimi
# no source_type, no source_artifact, no source_hash
```

`research_source.py verify` → non-zero (`NOT_FOUND` / missing hash). By OWNER decision
(directive §1.2) `source = Kimi` without a resolvable artifact is INVALID; the internal class is
not satisfied. (Note: because raw R1 build-readiness only checks `source_id` non-empty, the *hard*
enforcement for the internal class is `verify` + the prescreen provenance/hash requirement — this
is the fail-closed path in T4/T5, and why `source_hash` and a resolvable `source_artifact` are
mandatory frontmatter for `source_type: internal_research`.)

### 13.3 External card — unchanged

```yaml
source_id: mulham-channel-breakout-20260714
source_type: web_forum
sources:
  - "[[Mulham breakout thread]]"
```

No `QM-RESEARCH` namespace, no `internal_research` type. Evaluated exactly as today — R1 passes on
the non-empty `source_id`; external attribution rules are untouched.

---

## 14. What is explicitly NOT changed

- External R1 attribution (directive §1.2, §14).
- Numeric gate thresholds, verdict logic, `R_STRICT_PASS_FIELDS`, Q00–Q17.
- Runtime ML enforcement (`build_check.ps1`, review prompts).
- Any dated `decisions/*.md`, `docs/ops/evidence/*`, historical audit/window-sweep artifacts —
  annexes append, never alter prior evidence.
- HR16 (one research at a time) — Kimi authorship does not relax it.

## Open / unverified

- **UNVERIFIED:** whether the OWNER wants a routable DB `sources` row (extending
  `VALID_SOURCE_TYPES`) for the internal lane, or cards-plus-decisions only (AI-CODEX precedent).
  This contract specifies the tuple extension so the option exists; using it is a routing choice,
  not a gate change.
- **UNVERIFIED:** the exact `## Research provenance` heading text as the scan-exemption anchor is
  a Fable design choice (D5); if the prescreen team prefers a different marker
  (e.g. a `provenance_section: true` frontmatter flag) the scoping logic in §9.3 must move with it.
- **UNVERIFIED (defer to implementation probe):** whether `source_model` can always be captured
  from the Kimi CLI run (the CLI prints no model line in `-p` output per the kimi_cli audit §5);
  the adapter records the `-m` alias it invoked, so `source_model` reflects the *requested* model,
  not a CLI-confirmed one. Mark `UNKNOWN` if the adapter cannot attest it.

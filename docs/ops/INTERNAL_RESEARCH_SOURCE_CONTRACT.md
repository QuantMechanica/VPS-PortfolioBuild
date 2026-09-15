# Internal Research Source Contract (QM-RESEARCH)

**Status:** FINAL v1 (2026-09-15). CANONICAL. Binding for every Strategy Card whose origin is
QuantMechanica's own internal research (internally authored by an authorized research agent —
Kimi, Fable, or another authorized AI/tool-authored edge discovery; see Annex 2026-09-15b).
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

> This document was reworked against the adversarial review and the binding **Orchestrator
> Resolutions R-A … R-I** (see the *Review disposition* appendix at the end). The largest change
> from the draft: R1 for the internal class is **no longer** claimed to pass with "only the
> ML-scan scoping fix". A concrete, deterministic, fail-closed intake verify is now a **required**
> code change (R-A), and the hash model is anchored on `sha256(source.md)` plus an in-file
> manifest block (R-B), not a self-blanked frontmatter hash.

---

## 1. Scope and the invariant

There are exactly two source classes and this contract touches only the first:

| Class | source_id prefix | R1 satisfied by | Changed by this contract? |
|---|---|---|---|
| **Internal research** | `QM-RESEARCH-YYYY-NNNN` | a durable, content-addressed internal artifact authored inside QuantMechanica, **resolvable and hash-verified at intake** | YES — this is the new class |
| **External** | book / paper / forum / video / `AI-<agent>-<tag>-<date>` etc. | verifiable external attribution (unchanged) | NO — external rules stay verbatim, unchanged code path |

**The invariant (directive §1.2, §14):** external attribution requirements are *not weakened*.
An external card that cites no verifiable source still fails exactly as today. The only thing
added is a *new, reserved, self-describing namespace* whose provenance lives entirely inside the
repo **and is checked at card intake**. The external card code path is untouched (R-A).

**What R1 already is (verified — audit `cards_r1_research.md` §1b):** `farmctl.py:4229-4237`
`_card_r1_build_ready(fm)` returns `bool(str(fm.get("source_id") or "").strip())` — raw
build-readiness is solely "source_id non-empty". `R_STRICT_PASS_FIELDS = ("r2_mechanical",
"r3_data_available", "r4_ml_forbidden")` (`farmctl.py:4219`) — R1 is deliberately excluded from
the strict pass set; DL-082 (2026-07-19) made R1 informational.

**Why that is not sufficient for this class (review blocking finding; audit `critic.md` §5).**
Because the raw check only tests that `source_id` is a non-empty string, a card carrying
`source_id: QM-RESEARCH-2026-0001` (or `source_author: Kimi`) with **no resolvable artifact and
no valid hash** would pass R1 build-readiness and prescreen today — an unbacked/hallucinated
internal source masquerading as provenance, the exact agy-video-hallucination failure mode
(`OPERATING_RULES_2026-07-03.md:27`). Therefore this contract adds a **deterministic, fail-closed
intake verify** for the internal class (§9.3) on top of the unchanged raw check. The raw
`_card_r1_build_ready` stays source-agnostic; the internal class is enforced by the added verify,
never by weakening or re-scoring the raw R1 field.

---

## 2. Research ID format and reference form

### 2.1 Canonical id — `QM-RESEARCH-YYYY-NNNN`

```
QM-RESEARCH-2026-0042
└────┬───┘ └┬┘ └─┬─┘
 fixed literal  year  zero-padded 4-digit monotonic counter within that year
```

- **Mint regex (authoritative for allocation):** `^QM-RESEARCH-(20\d{2})-(\d{4})$`.
- **Intake trigger regex (R-A, deliberately broader):** `^QM-RESEARCH-\d{4}-\d{4}$`. The intake
  branch (§9.3) fires on this broader form on purpose: a near-miss year (`QM-RESEARCH-1999-0001`)
  is still routed to `research_source.verify` and **fails closed** rather than slipping through as
  an "external" card that would pass on a non-empty `source_id`.
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
  `source: Kimi` (or `source_author: Kimi` with no resolvable, hash-verified `source_artifact`)
  is INVALID by OWNER decision (directive §1.2) and is rejected at intake with reason
  `INTERNAL_SOURCE_UNRESOLVED` (§9.3, R-A).

---

## 3. Durable store layout

Follows the established in-repo AI-source convention (precedent verified — audit
`cards_r1_research.md` §1e: `strategy-seeds/sources/AI-CODEX-XTIXNG-WCLVDIV-RV-20260906/source.md`
carries `source_id`, a free-text `source_type`, `parent_sha256`, `approval_basis` → a dated
`decisions/` receipt).

```
strategy-seeds/sources/QM-RESEARCH-2026-0042/          (git-tracked, on C:, canonical)
├── source.md              # human-readable artifact: frontmatter + provenance + mechanization + a fenced Source-manifest block (R-B)
├── research.json          # machine record: directive §1.2 + §12 field set; numeric claims reference computed-output files (R-C)
├── critic_receipt.json    # cross-vendor critic outcome (non-Kimi critic; read-only posture, §5, R-D)
└── lineage.json           # discovery→hypothesis→mechanization→preregistration lineage, parent links
```

Rules:
- **Durable copy is in the repo, on C:.** Never place the sole copy under
  `D:/QM/strategy_farm/artifacts/` — that tree is not version-controlled (audit
  `cards_r1_research.md` §3, risk 6). The runtime prompt/output trail *may* additionally live at
  `D:/QM/strategy_farm/artifacts/source_notes/<id>.md` per the research prompts, but it is a
  mirror, not the source of record.
- **Integrity authority = `sha256(source.md)` + the in-file manifest block + git history** (R-B),
  not filesystem immutability: `source.md` is a normal mutable repo file. Its content hash is the
  card's `source_hash`, the ledger's `sha256`, and (for a preregistered/carded source) is
  recorded in a dated `decisions/` receipt which *is* immutable once dated (repo map convention).
  This mirrors how `decisions/2026-09-06_xtixng_..._source_approval.md` anchors the AI-CODEX
  precedent (audit §1e).
- **Card locations unchanged:** `cards_draft/` → G0 → `cards_approved/` (D: authoritative, C:
  repo mirror at `C:/QM/repo/artifacts/cards_approved/`). The card *references* the store; it does
  not live in it.

---

## 4. Schema tables

### 4.1 `source.md` — frontmatter + manifest block

**Frontmatter (the card-facing provenance header):**

| Field | Type | Required | Who fills | Validation rule |
|---|---|---|---|---|
| `source_id` | string | YES | `research_source.py mint` | matches `^QM-RESEARCH-20\d{2}-\d{4}$`; equals the directory name |
| `title` | string | YES | Kimi (creator) | non-empty |
| `source_type` | literal | YES | mint | exactly `internal_research` |
| `source_author` | string | YES | mint | non-empty; an authorized internal research agent (`Kimi`, `Fable`, `Claude`, `Codex`, `Antigravity`) or a documented multi-agent collaboration (`multi-agent:<list>`), per `config/research_source.v1.json`. (SUPERSEDED 2026-09-15 by OWNER-DEC-CBE-20260915: the earlier `Kimi`-only wording is generalized; see Annex 2026-09-15b.) |
| `source_model` | string | YES | adapter (captured per run) | exact Kimi model alias from the run (e.g. `kimi-code/kimi-for-coding`); `UNKNOWN` if the adapter cannot attest it — never guessed (§ open items) |
| `created` | date (UTC) | YES | mint | ISO date; equals ledger `created` |
| `originating_task_id` | string | YES | adapter | the `agent_tasks.id` that produced the artifact |
| `status` | enum | YES | ledger-driven | one of `draft\|reviewed\|preregistered\|carded\|retired` (§6) |
| `parent_source_ids` | list | no | Kimi / mint | each resolvable (external id or another `QM-RESEARCH-…`) |
| `## Research provenance` | section (body) | YES | Kimi | the section exempt from the ML-term scan (§9.4, §11) |

**Source-manifest block (R-B) — a fenced block in the body of `source.md`:**

```qm-source-manifest
research.json:       <sha256>
lineage.json:        <sha256>
critic_receipt.json: <sha256>
# every computed-output file cited by a quantitative claim (R-C numeric provenance):
datasets/DS-2026-0042_projector.json: <sha256>
campaigns/CMP-2026-0042.json:         <sha256>
```

- `source.md` does **not** carry its own hash (no self-referential fixpoint). Instead the card's
  `source_hash = sha256(source.md)` over full UTF-8 bytes (§7). Because the manifest block hashes
  the *other* files, any edit to `research.json`, `lineage.json`, `critic_receipt.json`, or any
  cited computed-output file forces the manifest block to change, which changes `sha256(source.md)`,
  which breaks the card binding until a new version id is minted (§6.2 immutability).
- The manifest block is the **authority** for the sha256 of `research.json`, `lineage.json`,
  `critic_receipt.json`, and every dataset/computed-output file cited by a numeric claim.
  `research_source.py verify` recomputes each and compares (§7, §9.3).

External cards keep `source_id: <book/paper/forum>` and `sources:` backlinks unchanged — none of
the above applies to them (unchanged code path, R-A).

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
| `source_datasets` | list[obj] | YES | Kimi/observe | each `{dataset_id, path, sha256}` pointing at an OBSERVE dataset manifest; the sha256 must also appear in the `source.md` manifest block |
| `computed_outputs` | list[obj] | YES | observe/discover | each `{claim_ref, file, sha256}` — the deterministic projector/campaign JSON that produced a stated number (R-C numeric provenance); sha256 must appear in the `source.md` manifest block |
| `quantitative_claims` | list[obj] | YES | Kimi | each `{claim, value, computed_output_ref}`; every value **must** cite one `computed_outputs[].claim_ref` — no free-floating LLM number (§4.4, R-C) |
| `ml_method` | string\|null | cond. | Kimi | the ML/statistical method if used (directive §11); null if none |
| `observations` | string | YES | Kimi | the empirical finding, phrased against `quantitative_claims` (§12) |
| `proposed_mechanism` | string | YES | Kimi | the economic/causal hypothesis (directive §12, §15) |
| `candidate_edge` | string | YES | Kimi | the tradeable claim in words |
| `confidence` | string | YES | Kimi | free-text uncertainty statement (§12) |
| `confounders` | list[str] | YES | Kimi | likely confounders (§12, feeds the critic) |
| `related_strategies` | list[str] | YES | Kimi | ea_id / source_id of similar existing QM strategies (§15, redundancy check) |
| `research_trial_count` | int | YES | observe/discover | the search count for this hypothesis family, taken from the research-layer `search_history_ledger` (R-C); must be `>= 0` and consistent with the ledger (§4.3, §9.3) |
| `search_history_ref` | string | YES | observe | pointer into the **research-layer** `search_history_ledger.jsonl` (data-snooping evidence, directive §18). **Not** coupled to the Q08 DSR gate — see §4.3 |
| `critic_receipt` | string | YES | chain | relative path to `critic_receipt.json`; must exist for status ≥ `reviewed` |
| `lineage` | string | YES | mint | relative path to `lineage.json` |

**"Missing hash fails closed"** (directive §14): if any sha256 in the `source.md` manifest block
cannot be recomputed and matched (a manifest entry whose file is absent/unreadable/changed), or if
`sha256(source.md)` ≠ the card `source_hash`, `research_source.py verify` returns a hard failure
and the internal-class intake check (§9.3) rejects the card.

### 4.3 Trial accounting and DSR — no gate coupling (R-C)

The DSR/FDR gate is ROT (CLAUDE.md standing authorization; directive §5 "no gate-threshold
changes"). **This contract makes no change to the DSR/FDR formula or to how `dsr_cohort`
computes `research_trial_count`/`effective_trial_count`** — those remain reconstructed only from
a sealed DL-089 census (`dsr_cohort.py:751-768`; unit `candidate_configuration`), exactly as
today. The research-search family count is a **different quantity** and must never be injected
into that sealed cohort field.

Instead:
- The research-layer `search_history_ledger.jsonl` (defined in `KIMI_EDGE_DISCOVERY_DESIGN.md`,
  the OBSERVE/DISCOVER layer) records how many searches a hypothesis family took. That count is
  **evidence** for the `research_trial_count` the card / single-configuration contract already
  declares — surfaced only to (1) the preregistration decision, (2) the ATTACK critic prompt, and
  (3) research reporting / Deflated-Sharpe / BH-FDR computed **on the research ledger**, never on
  the Q08 cohort.
- **Intake coupling (fails closed, §9.3):** an internal card must declare `research_trial_count
  >= ` the research-layer ledger's count for its hypothesis family. If the ledger shows searches
  but the card declares `0` (or omits it), intake rejects with `INTERNAL_SOURCE_UNRESOLVED`
  (sub-reason `TRIAL_COUNT_UNDERSTATED`). This defends against data-snooping without touching the
  gate.
- If OWNER later wants the research family-count folded into the Q08 DSR deflation, that is a
  separate explicit **ROT gate-contract decision package** — it is *not* implemented in this
  layer.

### 4.4 Numeric provenance rule (R-C)

Every quantitative claim in a QM-RESEARCH artifact (`research.json`, `source.md`, `lineage.json`)
**must reference a computed output file** — a deterministic projector/campaign JSON whose sha256 is
recorded in the `source.md` manifest block. **An LLM's number is never the evidence** (directive
§4/§6). Concretely:

- `research.json.quantitative_claims[].value` must cite a `computed_outputs[].claim_ref`.
- `research_source.py verify` rejects (fails closed) an artifact whose stated metric has no
  backing computed-file hash in the manifest block, or whose cited file's sha256 does not match.
- Kimi prose in `source.md` may cite **only** figures present in the provided deterministic
  summaries / dataset outputs; a figure with no manifest-backed source is a hard verify failure.

This is the deterministic gate that distinguishes a script-computed figure from an LLM-asserted
one; it closes the review's major finding that the "numbers re-derived in Python" posture was
asserted but unenforced.

### 4.5 `critic_receipt.json` — cross-vendor critic outcome (real receipt field paths, R-I)

`schema: "qm.agent-chain.receipt.v1"` (the existing chain receipt; fields verified in audit
`router_providers.md` §6, receipt at `D:/QM/strategy_farm/state/agent_chain/<chain_id>.json`).
Contract-relevant field paths for an internal source, using the **real** receipt schema (R-I):

| Field path | Type | Required | Who fills | Validation rule |
|---|---|---|---|---|
| `chain_id` | string | YES | agent_chain | non-empty |
| `plan.creator.vendor` | string | YES | agent_chain | `kimi` for a Kimi-authored source |
| `plan.creator.model` | string | YES | agent_chain | exact creator model alias |
| `plan.critic.vendor` | string | YES | agent_chain | vendor **≠** `kimi` (directive §8: a Kimi-authored hypothesis must receive a non-Kimi critic) |
| `plan.critic.model` | string | YES | agent_chain | exact critic model alias |
| `stages[].seat` | list | YES | agent_chain | the seat run at each stage (creator/critic/formatter) |
| `critic_verdict` | string | YES | critic seat | informational; an LLM "PASS" is never a pipeline PASS (directive §7) |
| `finding_counts` | obj | YES | agent_chain | per-severity counts |
| `scope_drift` | bool | YES | agent_chain | true if the critic exceeded its brief |
| `repo_write` | bool | YES | adapter | true if the critic wrote **anything** to `C:/QM/repo` or the `D:/QM` verdict/evidence paths (R-D); `verify` fails closed on `true` |
| `critic_fallback_used` | bool | YES | agent_chain | whether a fallback critic seat was used |
| `critic_seat_final` | string | YES | agent_chain | the seat that actually produced the critique; must not be a `kimi` seat for a `kimi` creator |
| `receipt_path` | string | YES | agent_chain | absolute path to this receipt |
| `generated_at_utc` | ISO-8601 | YES | agent_chain | — |

Validation coupling (`research_source.py verify`, fails closed):
- rejects if `plan.creator.vendor == kimi` and (`plan.critic.vendor == kimi` **or**
  `critic_seat_final` is a `kimi` seat) — the non-kimi critic invariant (directive §8);
- rejects if `critic_receipt.json` is absent while the ledger `status` is `reviewed` or later;
- rejects if `repo_write == true` — a critic that wrote anything is FAILED and its output
  discarded (R-D; §5).

### 4.6 `lineage.json` — hypothesis lineage & preregistration link

`schema: "qm.research-lineage/v1"`

| Field | Type | Required | Who fills | Validation rule |
|---|---|---|---|---|
| `schema` | literal | YES | mint | `qm.research-lineage/v1` |
| `research_id` | string | YES | mint | equals `source_id` |
| `version` | int | YES | mint | 1 at first mint; +1 per new lineage version (§6.2 immutability) |
| `parent_version_id` | string\|null | YES | mint | the prior `QM-RESEARCH-…` id when this is a re-mint; null for v1 |
| `discovery_sample` | obj | YES | Kimi | `{period, instruments, dataset_ids}` used for discovery (directive §16) |
| `validation_sample` | obj | YES | Kimi | the held-out period/instruments not used in discovery (§16, §18) |
| `preregistration` | obj\|null | cond. | prereg tool | `{frozen_at_utc, param_count, param_ranges_sha256, success_criteria, failure_criteria}`; required before validation (directive §16) |
| `mechanization` | obj | YES | Kimi | pointer to the mechanical spec section + Codex-implementability assertion (directive §13) |

---

## 5. Cross-vendor critic requirement & read-only posture (R-D)

Per directive §8 and §15, an internal source is not `reviewed` until a **non-Kimi** critic has
attacked it. Enforcement of the critic's read-only posture is layered (R-D):

1. **Primary — capability-denied posture (prevention).** The Kimi critic runs under an
   agent-file/posture that **denies file-writing tools**, with `--add-dir` limited to a scratch
   directory that has read access to the repo (never `--add-dir` the live tree; never any T_Live
   path). This posture is verified by the **probe battery** (does `--add-dir` grant write? does
   `--plan` deny writes?) — `--plan` behaviour is currently **UNVERIFIED** (audit `critic.md` §4;
   `kimi_cli.md` §4 documents `--auto` as "everything runs, no interruption"). The probe battery,
   and running the critic against a throwaway copy rather than the live tree, live in
   `KIMI_INTEGRATION_ARCHITECTURE.md` (its blocking finding); this contract consumes their result.
2. **Secondary — git-status hash guard (detection).** The adapter records a git-status hash of
   `C:/QM/repo` (extended to the `D:/QM` verdict/evidence paths) before and after the critic run.
   Any delta ⇒ `repo_write = true`.
3. **Fail-closed outcome.** A critic run that wrote **anything** is FAILED and its output
   discarded: `agent_chain` marks the run status `critic_wrote` and **no formatter stage runs**.
   `research_source.py verify` fails closed when `critic_receipt.json` carries `repo_write == true`
   (§4.5).

`critic_receipt.json` is the durable evidence and is referenced from `research.json.critic_receipt`.
The `agent_chain.v1.json` `by_creator_vendor.kimi` table must list **only** non-kimi seats — this
is a **D4 design target to be added** to `agent_chain.v1.json` (today the config vendors are
`claude/codex/agy` with **no** `kimi` key — audit `critic.md` §9, `router_providers.md` §4; the
"never list a kimi seat inside `by_creator_vendor.kimi`" invariant is `router_providers.md` §9
risk 7). `research_source.py verify` enforces the non-kimi critic as a hard rule (§4.5). This is
*evidence for the preregistration decision*, not a gate — an LLM PASS is never a pipeline PASS
(directive §7).

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
| `sha256` | hex64 | YES | `sha256(source.md)` at this ledger event (= the card `source_hash`, R-B) |
| `status` | enum | YES | `draft\|reviewed\|preregistered\|carded\|retired` |
| `version` | int | YES | matches `lineage.json.version` |
| `parent_version_id` | string\|null | YES | prior id when this is a re-mint |
| `event` | enum | YES | `mint\|status_change\|reversion` |

### 6.1 Status lifecycle

```
draft ──(non-kimi read-only critic receipt attached)──► reviewed
reviewed ──(preregistration frozen, §16)─────────────► preregistered
preregistered ──(Strategy Card created)──────────────► carded
any ──(idea abandoned / superseded)──────────────────► retired
```

Backtest verdicts never write here; this ledger is pre-Q00 provenance only. Once `carded`, the
normal deterministic Q00–Q17 pipeline is the sole judge — Kimi authorship confers no gate
advantage (directive §17). The intake verify (§9.3) requires the ledger row `status` to be in
`{reviewed, preregistered, carded}` (R-A): a `draft` or `retired` source is not admissible.

### 6.2 Immutability rule (directive §16, R-B)

The ledger is **append-only**. A row is never edited in place; a status change is a new appended
`status_change` event carrying the same `id` and the current `version`. **Any edit to the frozen
research content after preregistration = a new lineage version with a new id and a
`parent_version_id` link** — you may not modify the hypothesis and pretend the new version was the
original (directive §16). Because the card binding is `source_hash = sha256(source.md)` and the
manifest block hashes every companion file, *any* content edit changes `sha256(source.md)` and
breaks the card binding until a fresh id is minted. `research_source.py` refuses to overwrite an
existing `source.md` whose recomputed `sha256(source.md)` differs from the ledger's recorded
`sha256` unless invoked as an explicit `re-mint` that allocates a fresh id with a
`parent_version_id` link.

---

## 7. Hashing rules (R-B)

- **Algorithm:** SHA-256, lowercase hex, over UTF-8 bytes.
- **`source_hash` = `sha256(source.md)`** over the full file bytes. `source.md` carries no
  self-hash, so there is no fixpoint problem. This value is the card's `source_hash` frontmatter
  field and the ledger's `sha256` field.
- **Manifest block anchoring:** the fenced `qm-source-manifest` block in `source.md` records the
  sha256 of `research.json`, `lineage.json`, `critic_receipt.json`, and every cited
  dataset/computed-output file. `research_source.py verify` recomputes each and compares; any
  mismatch or missing file → hard failure (directive §14 "missing hash … fails closed").
- **Card ↔ source binding:** `research_source.py verify --card <path>` recomputes
  `sha256(source.md)` and compares it to the card's `source_hash`. A drift means the card points
  at a version that no longer matches the store → fails closed. This is what makes the reference
  *verifiable* and clears the hallucination-precedent bar (agy video links are not R1 evidence,
  `OPERATING_RULES_2026-07-03.md:27`): the internal artifact is durable, content-addressed and
  independently readable.
- **Preregistration binding:** `lineage.json.preregistration.param_ranges_sha256` freezes the
  allowed parameter ranges so a later widening is detectable.

---

## 8. Strategy Card linkage

### 8.1 Card frontmatter (internal class)

```yaml
source_id:      QM-RESEARCH-2026-0042        # keeps every source_id-keyed tool working
source_type:    internal_research            # informational label (new); also the intake trigger (§9.3)
source_author:  Kimi
source_model:   kimi-code/kimi-for-coding    # exact model, from the run; UNKNOWN if unattestable
source_artifact: QM-RESEARCH://2026-0042     # resolvable reference
source_hash:    <sha256(source.md)>          # R-B; == ledger sha256
research_trial_count: 7                       # >= research-layer ledger count for the family (R-C, §4.3)
```

Plus the existing mandatory card fields, unchanged: `r1_track_record` (may be `UNKNOWN` for an
internally-authored card — it is not a gate), `r2_mechanical`, `r3_data_available`,
`r4_ml_forbidden: PASS` (the *EA* is ML-free; see §10–§11). `STRATEGY_CARD_REQUIRED_FRONTMATTER`
(`farmctl.py:4569+`) is unchanged; the fields above are additive.

### 8.2 Existing raw tooling — unchanged; the internal class is enforced by the added verify

- `_card_r1_build_ready` (`farmctl.py:4229-4237`) still returns build-ready on a non-empty
  `source_id`. **No change to the raw check.**
- `approve-card` R-strict set still excludes R1 (`R_STRICT_PASS_FIELDS`, `farmctl.py:4219`); only
  R2/R3/R4 must equal PASS. **No change to R-strict.**
- Lineage repair fallback (`OWNER-FABIAN-GRABNER-R1-RECOVERY-20260723`) never triggers because the
  id is present. **No change.**

**But the internal class is not admitted on the raw check alone.** R-A adds a deterministic,
fail-closed verify branch in **both** `card_intake_prescreen.evaluate_card` and `farmctl
approve-card` (the G0 promotion path, `_card_r1_build_ready`'s caller). This supersedes the draft's
claim that "only the ML-scan scoping change is strictly required" (the review's blocking finding;
audit `critic.md` §5): the ML-scan scoping (§9.4) **and** the intake verify (§9.3) are both
required. External cards keep the unchanged code path.

### 8.3 Fingerprint / dedupe collisions

`strategy_card_fingerprint` (`farmctl.py:4548-4566`) hashes
`source_id | slug | universe | timeframe | thesis_terms`. Because each internal idea gets its own
`QM-RESEARCH-…` id, the reserved namespace *increases* dedupe fidelity: two genuinely distinct
Kimi ideas cannot collide on the source component. The failure mode to avoid (audit
`cards_r1_research.md` risk 3) is a shared umbrella id across child ideas — forbidden by §2.1
(one id per idea). External cards' fingerprints are unaffected.

---

## 9. Validator behaviour

### 9.1 `research_source.py` (new tool, `tools/strategy_farm/research_source.py`)

| Subcommand | Behaviour | Fail-closed cases |
|---|---|---|
| `mint` | allocate next `QM-RESEARCH-YYYY-NNNN`, scaffold the store dir, write `research.json`/`lineage.json` stubs + `source.md` skeleton with an empty manifest block, append a `draft` ledger row | refuses if id already in ledger; refuses if `author`/`model`/`task_id` missing |
| `resolve QM-RESEARCH://<id>` | print the absolute store path | non-existent id → non-zero exit, `NOT_FOUND` |
| `verify [--card <path>]` | recompute `sha256(source.md)`; recompute every manifest-block hash and the numeric-provenance computed-output hashes; check the non-kimi read-only critic (`repo_write==false`, non-kimi critic) present for status ≥ reviewed; check ledger row `status ∈ {reviewed,preregistered,carded}`; when `--card` given, compare card `source_hash` to `sha256(source.md)` and `research_trial_count` to the research ledger | any hash mismatch, missing manifest/evidence hash, numeric claim without a backing computed-output hash, kimi-critic-on-kimi-creator, `repo_write==true`, understated `research_trial_count`, bad ledger status, or absent artifact → non-zero exit |

### 9.2 `farmctl VALID_SOURCE_TYPES`

`farmctl.py:33580-33583` currently `("book","paper","web_forum","web_blog","mql5_codebase",
"mql5_articles","video","local_archive")`; `add_source` (`:33587-33607`) rejects any other type
(audit `cards_r1_research.md` §2b, risk 4). **Add `"internal_research"`** to the tuple so a
routable DB `sources` row can be created for an internal lane. `add_source` then accepts it; the
`--source-type` argparse choices (`farmctl.py:38232`) pick it up automatically from
`VALID_SOURCE_TYPES`. (Cards-plus-decisions without a DB row remains valid too, per the AI-CODEX
precedent; the DB row is optional but wanted for a routable discovery lane — see open items.)

### 9.3 Internal-source intake verify — the concrete fail-closed gate (R-A, required)

This is the code change the review's blocking finding demanded and the draft omitted. Two
enforcement points, one behaviour, external cards untouched:

**(1) `card_intake_prescreen.evaluate_card`** gains a branch: when frontmatter
`source_type == internal_research` **OR** `source_id` (or `source_uri`) matches
`^QM-RESEARCH-\d{4}-\d{4}$`, the card MUST pass `research_source.verify(id)`:
- artifact directory present (`resolve` succeeds);
- `sha256(source.md)` == card `source_hash`;
- `research.json` / `lineage.json` / `critic_receipt.json` hashes present in the `source.md`
  manifest block and matching on recompute;
- every `quantitative_claims[].value` backed by a `computed_outputs` hash in the manifest (R-C
  numeric provenance);
- `research_trial_count` (card) ≥ research-layer ledger count for the family (R-C, §4.3);
- non-kimi read-only critic present (`repo_write==false`) for status ≥ reviewed;
- ledger row `status ∈ {reviewed, preregistered, carded}`.

On any miss → **REJECT** with prescreen reason **`INTERNAL_SOURCE_UNRESOLVED`** (the canonical
R-A reason). `verify` may emit diagnostic sub-reasons for the operator — `NOT_FOUND`,
`HASH_MISMATCH`, `MANIFEST_MISSING`, `NUMERIC_UNBACKED`, `TRIAL_COUNT_UNDERSTATED`,
`CRITIC_KIMI_ON_KIMI`, `CRITIC_WROTE`, `LEDGER_STATUS_BAD` — carried as detail under the single
`INTERNAL_SOURCE_UNRESOLVED` reason. `--apply` then routes the card to `cards_rejected/`.

**(2) `farmctl approve-card`** (the G0 promotion path; `_card_r1_build_ready`'s caller,
`farmctl.py:4464-4471`) performs the **same** `research_source.verify` for the internal class and
**refuses** promotion on any miss, with the same `INTERNAL_SOURCE_UNRESOLVED` verdict. The raw
`_card_r1_build_ready` field is unchanged; the refusal is an added guard, not a re-scoring of R1.

**(3)** `author = Kimi` (or `source_id` in the namespace) with **no resolvable, hash-verified
artifact** is exactly this REJECT — it can no longer masquerade as a valid source (directive §1.2;
worked example §13.2). This is what makes the directive-§14 tests `author=Kimi without artifact
FAILS` and `missing hash fails closed` actually green (they cannot pass under the draft's
"no-code-change" design).

### 9.4 `card_intake_prescreen` — ML-term scan scoping (the second required gate fix)

`_affirmative_prohibited_mechanics` (`card_intake_prescreen.py:464-489`) currently scans the
**whole** card text (`scan_text = ... document.text`, line 483) for ML terms
(`machine learning|random forest|neural network|xgboost|lstm|hidden markov|viterbi`, line 472) and
appends `PROHIBITED_MECHANICS:ML` (via `evaluate_card`, lines 541-543 — audit `cards_r1_research.md`
§2b/§4c). An internal-research card that *truthfully describes* its ML-assisted provenance
("edge discovered via a random-forest feature-importance study") would be falsely rejected.

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

### 9.5 Denied-authority guards for the Kimi source lane (R-F)

The layer distinguishes **code-level guards** (structural; cannot be talked around) from
**process-level guards** (receipts and orchestrator review):

| Guard | Kind | Mechanism |
|---|---|---|
| Kimi cannot claim code/ops/repo rows | code-level | capability omission — do not declare `code/ops/repo_edit/scalpel_mechanization`; a lane declaring only research caps cannot claim those task_types (`agent_router.py:1678-1680`; audit `router_providers.md` §2) |
| No verdict write in any Kimi branch | code-level | no Kimi branch calls a verdict-writing path; verdicts/`APPROVED` are the human `close-review` only. (The "leave in REVIEW / no self-approve" text at `run_agent_orchestration_task.py:273-294` is a **prompt docstring, not enforcement** — audit; the real guard is that no Kimi task-type routes to a verdict path.) |
| T_Live never reachable | code-level | no T_Live path is ever placed in a Kimi `--add-dir`; the critic scratch dir excludes T_Live |
| No farmctl mutation from a Kimi task | code-level | the Kimi tool envelope does not expose `farmctl close-review` / git-main operations (same read-only work as §5) |
| Non-kimi read-only critic; numeric provenance; trial count | process-level (receipt) | enforced by `research_source.verify` reading `critic_receipt.json` and the manifest (§4.5, §4.4, §4.3) |
| Final admission | process-level | orchestrator review + the deterministic Q00–Q17 pipeline remain the judge (directive §7, §17) |

### 9.6 Adapter single-flight & pacing (R-E, R-G — cross-reference)

Every Kimi invocation (orchestration lane, chain, or research tooling) goes through
`kimi_adapter.py`, which holds a **machine-wide single-flight lock** (named mutex / lockfile with
pid) around the call because the OAuth credential-file refresh is a shared-file race (audit
`critic.md` §4: a rolling ~900s token; concurrent processes race the refresh). `max_parallel=1`
on the lane is the second belt, not the primary guard. Governor pacing (conservative daily/weekly
caps; CONSERVE narrows Kimi to the high-value capabilities; the gemini-down interaction) is
specified in `KIMI_INTEGRATION_ARCHITECTURE.md` (R-E, R-G); this contract only notes that a
CONSERVE/EXHAUSTED state must not silently admit an unverified internal source — the intake verify
(§9.3) is independent of quota state.

---

## 10. R4 enforcement points that must NOT change

Runtime-ML enforcement is scoped to EA *code* and is untouched by this contract (audit
`cards_r1_research.md` §4a):

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
ML-assisted research author therefore cannot trip runtime R4. The only card-side gap was the
whole-text prescreen scan, closed in §9.4. The MECHANIZE gate (directive §13) is the hard
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
> `source_artifact: QM-RESEARCH://<id>` (resolvable), `source_hash` (`sha256(source.md)`), and a
> `research_trial_count` consistent with the research-search ledger — **and the internal-source
> intake verify passes** (`INTERNAL_RESEARCH_SOURCE_CONTRACT.md` §9.3). `source = Kimi` (or any
> author name) WITHOUT a resolvable, hash-verified artifact is INVALID and is rejected at intake
> with reason `INTERNAL_SOURCE_UNRESOLVED`. The durable artifact lives at
> `strategy-seeds/sources/QM-RESEARCH-YYYY-NNNN/` and is governed by
> `docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md`. **External attribution is unchanged:** an
> external card still requires its verifiable external source exactly as before, on the unchanged
> code path. This annex adds a namespace and an intake check; it does not weaken external R1.

### 11.3 `processes/qb_reputable_source_criteria.md` — R4 annex (append under R4)

> **R4 scope clarification (annex 2026-09-15).** R4 (Hard Rule 14) forbids ML **in the EA runtime
> decision engine**. An ML-assisted *research provenance* — an edge discovered with ML/statistical
> methods and then reduced to explicit mechanical rules — is explicitly NOT an R4 concern. R4's
> in-EA reject list (neural nets, ONNX/inference, PnL-adaptive parameters, online/retraining
> logic, non-deterministic entries, unbounded martingale) stands verbatim. A card describing its
> ML-derived provenance in a `## Research provenance` section is not an R4 violation and must not
> be prescreen-rejected for it (see `INTERNAL_RESEARCH_SOURCE_CONTRACT.md` §9.4). Mirror of the
> `build_check.ps1` L888-901 principle: "prose describing ML is not ML."

### 11.4 `04 Processes/Research Methodology.md` — mirror + source-category row

> **R1 (mirror):** `QM-RESEARCH://<id>` is a valid verifiable reference type for internally
> authored strategies, admitted only when the intake verify passes. **R4 (mirror):** governs the
> EA decision engine; offline research ML that outputs fixed mechanical rules is out of R4 scope.
> **Source category (new row):** *internal AI-authored research* — `source_type:
> internal_research`, id `QM-RESEARCH-YYYY-NNNN`, durable artifact under `strategy-seeds/sources/`,
> `sha256(source.md)`-anchored, cross-vendor read-only critic required, numeric claims backed by
> computed-output hashes, HR16 one-research-at-a-time unchanged.

### 11.5 `CLAUDE.md` — Hard Rules block cross-reference (append to the ML bullet)

> ML is forbidden **inside V5 EAs and their live/backtest decision engine** (HR14, annexed
> 2026-09-15). ML/statistics ARE allowed as offline research instruments; every candidate entering
> Q00 must be fully mechanical. Internal Kimi-authored research can satisfy R1 via a durable,
> hash-verified `QM-RESEARCH://<id>` artifact that passes the internal-source intake verify — see
> `docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md`.

---

## 12. Regression test matrix (directive §14 → test names)

Tests live in `tools/strategy_farm/tests/`. The five OWNER-mandated cases plus the coupling
checks. **These now have a gate that can produce the required failures** (§9.3), which the draft
lacked.

| # | Directive §14 requirement | Test name | Assertion |
|---|---|---|---|
| T1 | external unattributed card still FAILS | `test_r1_external_unattributed_fails` | a card with no `source_id` is not build-ready (`_card_r1_build_ready` False) / prescreen flags missing lineage |
| T2 | external valid source PASSES | `test_r1_external_valid_passes` | book/paper card with `source_id` builds unchanged (unchanged code path) |
| T3 | valid Kimi internal research source PASSES | `test_r1_internal_research_valid_passes` | card `source_id=QM-RESEARCH-2026-0001`, resolvable artifact, matching `source_hash`, numeric claims backed, non-kimi read-only critic, ledger status `reviewed`+ → intake verify OK + build-ready |
| T4 | author=Kimi without durable artifact FAILS | `test_r1_internal_kimi_no_artifact_fails` | `source_author=Kimi`, `source_artifact` unresolvable/absent → intake `INTERNAL_SOURCE_UNRESOLVED`, `approve-card` refuses |
| T5 | missing hash / provenance fails closed | `test_r1_internal_missing_hash_fails_closed` | `source_hash` mismatch or a manifest hash unreadable → `verify` hard fail → intake reject |
| T6 | prescreen ML scan scoping | `test_prescreen_ml_provenance_exempt` | card with ML term only inside `## Research provenance` → KEEP; ML term in mechanics → `PROHIBITED_MECHANICS:ML` |
| T7 | frontmatter ML still trips | `test_prescreen_r4_frontmatter_ml_trips` | `r4_ml_forbidden: false` → ML finding regardless of section |
| T8 | non-kimi read-only critic invariant | `test_internal_source_critic_non_kimi` | `verify` rejects `critic_seat_final`/`plan.critic.vendor == kimi` for a kimi creator, and rejects `repo_write==true` |
| T9 | numeric provenance backed | `test_internal_numeric_claim_requires_computed_output` | a quantitative claim with no backing `computed_outputs` hash → `verify` hard fail |
| T10 | trial-count not understated | `test_internal_trial_count_ge_ledger` | ledger shows searches but card declares 0 → intake `INTERNAL_SOURCE_UNRESOLVED` (`TRIAL_COUNT_UNDERSTATED`) |
| T11 | VALID_SOURCE_TYPES accepts internal | `test_valid_source_types_internal_research` | `add_source(..., source_type="internal_research")` succeeds; unknown type still rejected |
| T12 | fingerprint distinctness | `test_fingerprint_internal_ids_distinct` | two distinct `QM-RESEARCH-…` ids do not collide in `strategy_card_fingerprint` |
| T13 | ledger immutability / re-mint | `test_ledger_append_only_remint` | editing frozen content after preregistration changes `sha256(source.md)`, breaks the card binding, and forces a new id + `parent_version_id`; no in-place overwrite |
| T14 | runtime ML still FAILS | `test_build_check_runtime_ml_rejected` | an `.mq5` with an inference call still fails `Invoke-ForbiddenScan` (unchanged) |

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
source_hash: 7f3a...e91c            # == sha256(source.md), == ledger sha256
research_trial_count: 7             # >= research-layer ledger count for this family
---

## Research provenance
Edge discovered via a random-forest feature-importance study over the OPT_CENSUS
dataset (dataset_id DS-2026-0042, sha256 …). ML was used only to rank features;
the resulting rule set below is fully deterministic. Every figure cited here comes
from datasets/DS-2026-0042_projector.json (sha256 in the source manifest).
Cross-vendor critic: critic_receipt.json (creator=kimi, critic=claude sonnet, repo_write=false).

## Structural cause
… (mechanical thesis; no ML terms here) …
```

`_card_r1_build_ready` → True (source_id present). Intake verify (§9.3) → OK (hash matches,
artifact resolves, numeric claims backed, trial count consistent, non-kimi read-only critic,
ledger status reviewed). Prescreen ML scan → KEEP (the "random-forest" mention is inside
`## Research provenance`, exempt).

### 13.2 Invalid — author=Kimi without a resolvable artifact

```yaml
source_id: kimi-idea-42
source_author: Kimi
# no source_type, no source_artifact, no source_hash
```

The `source_id` does not match the namespace and there is no resolvable artifact. If instead the
card carried `source_type: internal_research` (or a `QM-RESEARCH-…` id) with no store behind it,
the §9.3 intake branch fires and `research_source.verify` returns non-zero (`NOT_FOUND` /
`HASH_MISMATCH`). By OWNER decision (directive §1.2) `source = Kimi` without a resolvable,
hash-verified artifact is INVALID; intake rejects with `INTERNAL_SOURCE_UNRESOLVED` and
`approve-card` refuses promotion. This is the fail-closed path in T4/T5 — and the reason the raw
`_card_r1_build_ready` non-empty check is no longer the last word for the internal class.

### 13.3 External card — unchanged

```yaml
source_id: mulham-channel-breakout-20260714
source_type: web_forum
sources:
  - "[[Mulham breakout thread]]"
```

No `QM-RESEARCH` namespace, no `internal_research` type. The §9.3 branch does not fire. Evaluated
exactly as today — R1 passes on the non-empty `source_id`; external attribution rules are
untouched (R-A: external code path unchanged).

---

## 14. What is explicitly NOT changed

- External R1 attribution and the external card code path (directive §1.2, §14; R-A).
- The DSR/FDR gate: no change to the formula or to `dsr_cohort`'s `research_trial_count` /
  `effective_trial_count` (`dsr_cohort.py:751-768`); the research-search count stays in the
  research layer (§4.3, R-C).
- Numeric gate thresholds, verdict logic, `R_STRICT_PASS_FIELDS`, Q00–Q17 (ROT).
- Runtime ML enforcement (`build_check.ps1`, review prompts).
- Any dated `decisions/*.md`, `docs/ops/evidence/*`, historical audit/window-sweep artifacts —
  annexes append, never alter prior evidence.
- HR16 (one research at a time) — Kimi authorship does not relax it.

## 15. Open / unverified

- **UNVERIFIED:** whether the OWNER wants a routable DB `sources` row (extending
  `VALID_SOURCE_TYPES`) for the internal lane, or cards-plus-decisions only (AI-CODEX precedent).
  This contract specifies the tuple extension so the option exists; using it is a routing choice,
  not a gate change (audit `cards_r1_research.md` unknowns).
- **UNVERIFIED:** the exact `## Research provenance` heading text as the scan-exemption anchor is
  a Fable design choice (D5); if the prescreen team prefers a different marker
  (e.g. a `provenance_section: true` frontmatter flag) the scoping logic in §9.4 must move with it.
- **UNVERIFIED (defer to implementation probe):** whether `source_model` can always be captured
  from the Kimi CLI run (the CLI prints no confirmed model line in `-p` output per audit
  `kimi_cli.md` §5); the adapter records the `-m` alias it invoked, so `source_model` reflects the
  *requested* model, not a CLI-confirmed one. Mark `UNKNOWN` if the adapter cannot attest it.
- **UNVERIFIED:** `--plan` read-only behaviour and whether `--add-dir` grants write — the critic
  read-only posture (§5, R-D) depends on the probe battery in `KIMI_INTEGRATION_ARCHITECTURE.md`;
  until those probes pass, the critic must run against a throwaway copy, never the live tree.
- **UNVERIFIED:** the `by_creator_vendor.kimi` block and the `kimi` vendor key are **D4 design
  targets** not yet present in `agent_chain.v1.json` (today vendors are `claude/codex/agy`, no
  `kimi` — audit `critic.md` §9). The invariant "never list a kimi seat inside
  `by_creator_vendor.kimi`" is `router_providers.md` §9 risk 7.

---

## Appendix — Review disposition

Two review files sit in `.../design/`. The one named `INTERNAL_RESEARCH_SOURCE_CONTRACT.review.json`
actually reviews `KIMI_EDGE_DISCOVERY_DESIGN` (its findings cite OBSERVE/DISCOVER/LEARN, the
`dsr_cohort` coupling, the disk gate, and a "Section 10 research-objective metrics" section that
does not exist in this document). Per the task note, findings from **both** reviews that touch this
document's topics are dispositioned below; findings that belong wholly to another document are
marked as such. Orchestrator resolutions R-A…R-I are binding and applied.

From `INTERNAL_RESEARCH_SOURCE_CONTRACT.review.json` (mislabeled; = Edge Discovery review):

- **F1 (blocking) — DSR coupling of `research_trial_count`.** APPLIED via R-C. This document
  introduces no coupling to `dsr_cohort` (§4.3, §14); the research-search count lives in the
  research-layer `search_history_ledger` as evidence for the card's declared `research_trial_count`,
  with an intake check that fails closed on understatement. No gate/formula change.
- **F2 (blocking) — R1 has no enforced intake verify; author=Kimi/no-artifact would PASS.**
  APPLIED via R-A. Added a concrete fail-closed verify in `card_intake_prescreen.evaluate_card`
  and `farmctl approve-card`, reason `INTERNAL_SOURCE_UNRESOLVED`, with named diagnostic
  sub-reasons (§8.2, §9.3, §13.2). Supersedes the draft's "only the ML-scan scoping is required".
- **F3 (major) — numeric re-derivation asserted but unenforced.** APPLIED via R-C. Added the
  numeric-provenance rule (§4.4): every quantitative claim references a computed-output file whose
  sha256 is in the manifest; `verify` rejects unbacked numbers (T9).
- **F4 (major) — research-objective metrics split (novelty/robustness/etc.).** RESOLVED-BY-
  ORCHESTRATOR (R-H): this document has no research-objective-metrics section; the authoring-time
  vs post-pipeline split is carried in `KIMI_EDGE_DISCOVERY_DESIGN.md`. Nothing to change here.
- **F5 (minor) — D: 80 GB disk gate deadlock.** REJECTED (belongs to another document): the disk
  gate is a DISCOVER-layer constraint in `KIMI_EDGE_DISCOVERY_DESIGN.md`, not referenced by this
  contract.
- **F6 (minor) — `by_creator_vendor.kimi` presented as current fact; miscited section.** APPLIED
  (cheap): §5 and §15 now mark the kimi vendor block and `by_creator_vendor.kimi` as **D4 design
  targets** not yet in `agent_chain.v1.json`, and cite the invariant correctly as
  `router_providers.md` §9 risk 7.
- **F7 (minor) — "invalid" verdict-taxonomy disposition inconsistency.** REJECTED (belongs to
  another document): the taxonomy split is an OBSERVE-projector concern in
  `KIMI_EDGE_DISCOVERY_DESIGN.md`.

From `KIMI_INTEGRATION_ARCHITECTURE.review.json` (touching this document's topics):

- **A1 (blocking) — critic read-only enforced only by post-hoc git-hash (detection, repo-scoped).**
  APPLIED via R-D for the parts this document owns: `critic_receipt.json` gains `repo_write`,
  `verify` fails closed on `repo_write==true`, a critic that wrote is FAILED/discarded
  (`critic_wrote`, no formatter). The primary prevention (capability-denied posture, scratch
  `--add-dir`, throwaway-copy run, probe battery, D:/QM-scoped guard) is specified in
  `KIMI_INTEGRATION_ARCHITECTURE.md`; §5 consumes it and marks `--plan`/`--add-dir` UNVERIFIED.
- **A2 (major) — single-flight lock, not `max_parallel`.** RESOLVED-BY-ORCHESTRATOR (R-E): the
  machine-wide `kimi_adapter.py` single-flight lock (with `max_parallel=1` as the second belt) is
  cross-referenced in §9.6; the mechanism's home is the architecture document.
- **A3 (major) — denied-authority: code guards vs prompt docstrings.** APPLIED via R-F: §9.5 is a
  denied-authority table separating code-level guards (capability omission, no verdict path, T_Live
  never in `--add-dir`, no farmctl mutation) from process-level guards (receipts, orchestrator
  review), and it notes the `run_agent_orchestration_task.py:273-294` text is a prompt docstring,
  not enforcement.
- **A4 (major) — cost_rank 12 / gemini-down capture.** RESOLVED-BY-ORCHESTRATOR (R-G): governor
  caps and the gemini-down interaction are the architecture/governor document's scope; §9.6 only
  notes that quota state must never admit an unverified source (intake verify is quota-independent).
- **A5–A9 (minors) — CONSERVE wording, chain vendor gate, subscription period, credential ACL,
  malformed-JSON test split.** REJECTED for this document (belong to
  `KIMI_INTEGRATION_ARCHITECTURE.md`); none touch the source contract.

Kept from the reviews (unchanged in this document): R1 is already source-agnostic on the raw check
(`farmctl.py:4229-4237`, R1 excluded from `R_STRICT_PASS_FIELDS` at `:4219`); runtime R4 untouched
(`build_check.ps1`, `.mq5`/`.mqh` only, comments/strings blanked); the ML-scan scoping fix; the
cross-vendor critic-as-evidence-not-gate posture; the durable, content-addressed, in-repo-on-C:
store with a dated `decisions/` receipt as the hallucination-precedent bar; append-only/rebuildable
reversibility.

---

## Annex 2026-09-15b — Author generalization + resource-guard recalibration (OWNER-DEC-CBE-20260915)

Authority: OWNER master directive 2026-09-15 (continuous book evolution / FTMO acceleration /
autonomous edge discovery), verbatim at
`docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_verbatim.md` §34, §36, §37.
Append-only; the FINAL v1 body above stands except where a line is marked SUPERSEDED.

### Author generalization (directive §36, §37)

The internal-source class is **not restricted to Kimi**. An internal research artifact records an
explicit `source_author` (in `source.md` frontmatter and `research.json.author`) which must be one
of the **authorized research agents** or a **documented multi-agent collaboration**:

- `Kimi`, `Fable`, `Claude`, `Codex`, `Antigravity`, or
- `multi-agent:<list>` (e.g. `multi-agent:Fable+Kimi`) for a documented collaboration.

The authorized set lives in `tools/strategy_farm/config/research_source.v1.json` (OWNER-tunable;
env override `QM_RESEARCH_AUTHORIZED_AUTHORS`, comma-separated). `research_source.verify` matches
case-insensitively and fails closed with sub-reason `UNAUTHORIZED_AUTHOR` when the durable
artifact's author is present but not authorized. **Every other requirement is unchanged**: a
durable resolvable artifact, `source_hash = sha256(source.md)`, the manifest block, numeric
provenance, the cross-vendor non-Kimi critic invariant, ledger status, and the fail-closed
`INTERNAL_SOURCE_UNRESOLVED` intake verdict all stand verbatim. `author = <name>` WITHOUT a
resolvable, hash-verified artifact remains INVALID (directive §36). The non-Kimi-critic invariant
(§4.5) is unaffected: a Kimi-authored hypothesis still requires a non-Kimi critic; a Fable-authored
hypothesis likewise gets an independent cross-vendor critic.

### Resource-guard recalibration (directive §34)

The former flat `D: < 80 GB` research block is SUPERSEDED. It permanently disabled research because
the tester-cache purge parks D: at its 60 GB low-water, so an 80 GB floor was above the disk's own
operating band. `tools/strategy_farm/research/research_env.py` now watches the volume research
actually uses (the C: dataset-output location, `observe_projector.DEFAULT_OUT_ROOT`) with a measured
`20 GB` floor, and imposes the `60 GB` tester-purge low-water as a factory-yield floor **only when
research scratch is placed on the factory drive (D:)**. The 60 GB low-water is read from the shared
`tools/strategy_farm/config/factory_disk_policy.v1.json` so it can never drift from the purge.
Layering invariant: `worker_disk_floor (40) <= purge_low_water (60) <= research floor on D:`. No
canonical evidence, verdict, immutable report, or trade stream is deleted to create space. Config
overrides: `QM_RESEARCH_SCRATCH`, `QM_RESEARCH_MIN_FREE_GB`, `QM_FACTORY_MIN_FREE_GB`.

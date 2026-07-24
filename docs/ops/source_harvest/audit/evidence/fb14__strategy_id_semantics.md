# FB-14 — `strategy_id` semantics in ea_id_registry.csv

Date: 2026-07-24 · Author: board-advisor audit lane · Status: ANALYSIS + cleanup policy

## Observed reality

`framework/registry/ea_id_registry.csv` (header `ea_id,slug,strategy_id,status,owner,created_at`):

- **4152** data rows; **17** with an empty `strategy_id`.
- **928** distinct `strategy_id` values (case-insensitive).
- **180** `strategy_id` values are shared by more than one `ea_id` ("duplicate groups"),
  covering **3387 rows (~82% of the registry)**. In **177** of those 180 groups the member
  slugs are *unrelated* (>1 distinct base slug).
- The sharing is **batch-scale**, not accidental pairs: largest groups are
  `6E967762-…` (**473** EAs), `D11962D5-…` (210), `B8B5125A-…` (197), `BA57D97A-…` (189),
  `EDE348B4-…` (126). The 473-member `6E967762-…` batch spans raschke, sidus, vegas-tunnel,
  wyckoff, demark, ehlers and the whole `ff-*` forum-mining set — including the example pair
  **1490 `raschke-anti-pullback-reversal-h4`** and **9936 `ff-range-breakout-gmt3-h1`**.

**Conclusion:** `strategy_id` is **not** a unique per-strategy key. In practice it is a
**source/batch provenance id** — a per-source UUID (or an `SRCxx_Syy` token, or `TBD`)
stamped across every EA harvested in one import wave. The intake convention confirms this:
`test_mailbox_source_intake.py:467` requires the builder prompt to say *"Reuse its EA ID only
when `strategy_id == source_id`"* — i.e. the column is treated as `source_id`.

## Consumers and their impact

| Consumer | Use of `strategy_id` | Impact of the shared-id reality |
|---|---|---|
| `framework/scripts/research_dedup_check.py` | `cmd_check` L207-215: exact match of candidate `strategy_id` vs **any** registry row ⇒ prints `EXACT DUPLICATE` and `return 2`; `Candidate.is_dup_of` (L69) OR-matches slug/strategy_id for cards; L233 fuzzy-matches `strategy_id` | **Can emit false dup-blocks.** A genuinely new strategy that (re)uses a source's batch-id as its `strategy_id` collides with 1..N unrelated rows and gets verdict `DUPLICATE — link as _v<n>, NOT new ea_id` on `strategy_id` grounds alone. |
| `framework/scripts/validate_registries.py` | L26: `strategy_id` in `REQUIRED_EA_COLUMNS` | Structural presence only — **no uniqueness check**. |
| `farmctl.py` health `chk_ea_id_slug_uniqueness` (test_health_registry_uniqueness) | checks **ea_id/slug** uniqueness | Does **not** check `strategy_id`; the 180 shared groups pass health cleanly (intended). |
| `farmctl.py` reserve-ea-id (L14766-14815) | writes `strategy_id` as provenance | Correct for a source-id; no assumption of uniqueness. |
| `mailbox_source_intake` | `strategy_id == source_id` gate for EA-ID reuse | Consistent with source-id semantics. |
| `skill_g0_card_lint.py`, `generate_research_sets.py` (20009), rekey tests | field presence / self-referential casefold match | Unaffected. |

**Does the dup-check produce false dup-blocks? Yes, potentially — but it is advisory, not an
enforced gate.** It is invoked as a manual pre-allocation check (referenced from ops evidence
docs, not wired into the pipeline). The empirical proof it is *not* enforced on bulk intake: if
its `strategy_id` EXACT-DUPLICATE branch actually blocked allocation, the 473-member and 210-member
same-id batches could never have been created. The real-world harm is narrow: an operator running
`research_dedup_check.py check --strategy-id <batch-uuid> …` for a legitimately new same-source
strategy gets a false `DUPLICATE` verdict (exit 2) and could wrongly link it as `_v<n>` instead of
allocating a fresh `ea_id`. The **slug** branch (L205-206) remains the reliable duplicate signal.

## Recommended cleanup policy

1. **Do not rekey or dedupe historical rows.** The 3387 shared-id rows are legitimate source
   provenance; `strategy_id` is a *source_id*, not a per-EA key. Bulk "fixing" it would destroy
   provenance and churn the registry for no gain (uniqueness is already carried by `ea_id`+`slug`).
2. **Rename the concept in one line of doc, not in data.** Record in the registry doc / intake
   convention that `strategy_id` == **source/batch id** (many-EAs-to-one is expected and valid).
   This stops future audits from re-flagging it as "duplicates".
3. **Fix the one consumer that mis-assumes uniqueness.** In `research_dedup_check.py`, demote the
   `strategy_id`-only match from `EXACT DUPLICATE / return 2` to an advisory note (keep the **slug**
   exact-match as the blocking signal; keep `strategy_id` for grouping/context and for fuzzy hints).
   This removes the false-block path while preserving real slug-based dedup. (Small, isolated change —
   flag for the orchestrator; not applied here.)
4. **Backfill the 17 empty `strategy_id`s** opportunistically with their source-id when next touched
   (housekeeping, non-urgent).

Net: no data migration; one doc line clarifying `strategy_id = source_id`; one advisory-vs-block
downgrade in `research_dedup_check.py`.

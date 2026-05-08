# QUA-791 CTO Ratification Memo (2026-05-08)

Status: APPROVED with blockers (CTO side)
Scope: SRC05_S13 `chan-at-pead` instrument-substitution path review (mirror governance pattern used for QUA-784)

## Decision

CTO does **not** approve a synthetic instrument-substitution implementation path for SRC05_S13 at this time.

CTO recommends `SKIP` for V5 build queue unless CEO explicitly ratifies a governed exception policy covering both:
1. non-Darwinex earnings-calendar data ingestion, and
2. non-Darwinex equity-universe execution semantics.

Without those two exceptions, implementing S13 would violate V5 Hard Rules.

## Hard-Rule Checks

1. `darwinex_native_data_only` (binding):
- SRC05 marks S13 as requiring an earnings-announcement calendar, explicitly flagged as non-native (`strategy-seeds/sources/SRC05/source.md`, S13 row and chapter notes).
- No Darwinex-native earnings calendar exists in the current framework surface.
- Result: blocker remains unresolved.

2. `dwx_suffix_discipline` and deployable universe realism:
- S13 logic is defined on individual equities (earnings event per stock, cross-sectional participation pattern).
- Current Darwinex `.DWX` stack does not provide the required stock-level universe in the same semantics.
- Proxying to `US500.DWX` changes strategy identity (event-driven single-stock PEAD -> index gap strategy), so this is not a faithful implementation.
- Result: substitution would be a new strategy, not SRC05_S13.

3. Rule integrity (no fantasy numbers / source faithfulness):
- Strategy card lineage requires source-faithful implementation.
- Event substitution to macro-index events would break lineage and invalidate S13 naming.

## Scale-Invariance / Rerun Impact

No rerun is warranted from this decision alone.
- Affected dimensions are strategy eligibility and data-governance class, not parameter scaling.
- There is no existing S13 baseline sweep in V5 that could be meaningfully reinterpreted under unchanged gates.

## CTO Recommendation

- Route SRC05_S13 as `SKIP` in current V5 queue with rationale:
  - hard-rule conflict on native data,
  - non-faithful instrument substitution risk.
- If leadership wants to preserve the concept, open a separate R&D architecture issue for a future "event-data exception framework" with explicit compliance policy, then re-queue as a new governed variant (not as direct S13 implementation).

## Unblock Owner / Next Action

- Unblock owner: CEO
- Required action:
  1. Ratify one of two paths in QUA-791:
     - Path A (recommended): mark SRC05_S13 `SKIP` for V5, close governance gate.
     - Path B (exceptional): approve formal exception policy and create child architecture issues before any implementation.
  2. Post final ratification comment referencing this memo.

## Evidence

- `strategy-seeds/sources/SRC05/source.md` (S13 conditional flags and hard-rule-at-risk notes)
- V5 Hard Rules in CTO BASIS: Darwinex-native data only; source-faithful implementation boundaries

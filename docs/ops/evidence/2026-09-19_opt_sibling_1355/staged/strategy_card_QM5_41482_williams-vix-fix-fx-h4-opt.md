---
ea_id: QM5_41482
slug: williams-vix-fix-fx-h4-opt
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
parent_ea_id: QM5_1355
parent_slug: williams-vix-fix-fx-h4
parent_card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_1355_williams-vix-fix-fx-h4.md
g0_status: APPROVED
g0_authority: "OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917 (Fable seal, ticket 0f99d9ea-6661-4028-a25e-e2a3b9725a45)"
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
period: H4
target_symbols: [NDX.DWX]
expected_trades_per_year_per_symbol: 8
last_updated: 2026-09-19
---

# QM5_41482 `williams-vix-fix-fx-h4-opt`

> **SEALED — `g0_status: APPROVED`.** This card is the Fable-sealed measurement-only
> optimization sibling of `QM5_1355` under
> `OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917` (scope: QM5_41482 only,
> ticket `0f99d9ea-6661-4028-a25e-e2a3b9725a45`; Fable holds full executive
> authority over Strategy Cards/portfolio candidates per
> `decisions/2026-09-17_owner_fable_full_executive_authority.md` §2 "Research /
> Strategy / Portfolio"). The governed card-of-record at
> `framework/EAs/QM5_41482_williams-vix-fix-fx-h4-opt/docs/strategy_card.md` is
> created by `governed_magic_allocator.py` from this APPROVED card, mirroring
> the verified `QM5_10911 -> QM5_41478` sibling precedent
> (`docs/ops/evidence/2026-09-16_opt_sibling_10911/`).
>
> **Governance classification (binding):** QM5_41482 is an
> **optimization/measurement sibling** of QM5_1355 — **NOT a new edge, NOT
> independent diversification, NOT a new strategy family.** It exists solely to
> run the DL-089 pattern-permission measurement census
> (`decisions/DL-089_pattern_filter_wf_census_v3.md`) against the approved
> parent's NDX book, closing the deferred Q12 declaration for work item
> `ba724ef2-22eb-54fa-b155-a793ef54b5c1` ("expected one approved `_opt` sibling
> for QM5_1355/NDX.DWX, found 0"). The parent (1355), its Q02-Q11 verdicts and
> its evidence are preserved unchanged; the parent source is never edited.

Target symbol: `NDX.DWX`.

## Source derivation

7-hunk mechanical transformation of `QM5_1355_williams-vix-fix-fx-h4.mq5`,
replaying the verified `QM5_13013 -> QM5_41321` template (same recipe already
executed for `QM5_10911 -> QM5_41478`): identity strings, the EA-managed
`QM_PatternPermission.mqh` wiring (`#define QM_PATTERN_PERMISSION_EA_MANAGED`),
`qm_ea_id 1355->41482`, the identity-free pattern-measurement surface (six
`opt_pp_*` inputs + `Pattern_Permission()`/`Opt_AddPattern()`/
`Pattern_AllowsRequest()`, byte-identical to the approved `QM5_41321` block),
fail-closed `OnInit` profile wiring, `PP_CENSUS_SUMMARY` telemetry in
`OnDeinit`, and the `Strategy_EntrySignal(req) && Pattern_AllowsRequest(req)`
entry gate. Parent entry, exit, sizing, news, and Friday-close mechanics
untouched. Derivation script: `docs/ops/evidence/2026-09-19_opt_sibling_1355/derive_sibling_source.py`.

Base setfile: parent's NDX H4 parameterization verbatim (`RISK_FIXED=1000`,
`RISK_PERCENT=0`) plus `qm_ea_id=41482` and six neutral `opt_pp_*=0`.

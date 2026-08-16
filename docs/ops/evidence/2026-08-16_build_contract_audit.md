# Build-contract audit — `qm-build-ea-from-card` (2026-08-16)

OWNER asked, after the Century Suite batch was blocked on a false rule: *correct the
contract and check whether there are more nonsensical paragraphs.* Every factual claim in
`C:\Users\Administrator\.codex\skills\qm\qm-build-ea-from-card\SKILL.md` was checked against
the actual fleet. Six were false. All six are corrected in place, each with its evidence
next to it.

## Findings

| # | Claim in the contract | Reality | Consequence |
|---|---|---|---|
| 1 | Slug ≤16 chars, folder name ≤32 | **948 EA folders exceed 32** (longest 64); `QM5_32003` (slug 31 / folder 41) passed Q02 and produced an economic Q04 verdict | Blocked all 77 clean Century EAs and one build on 2026-07-17. Already removed; see `2026-08-16_stale_slug_length_limit_removed.md` |
| 2 | Framework inputs are `ea_id`, `magic_slot_offset` | Real names are **`qm_ea_id`, `qm_magic_slot_offset`** | An EA built literally from the contract gets input names no setfile binds |
| 3 | News is one input, `news_mode = QM_NEWS_OFF` | FW1 (2026-05-23) split it into **two axes**: `qm_news_temporal` + `qm_news_compliance`, plus `qm_news_stale_max_hours` and `qm_news_min_impact`. The single mode survives only as `qm_news_mode_legacy` | This is not cosmetic: QM5_11388 accumulated **36 consecutive INFRA_FAIL/ONINIT rows** because its card demanded "news off in P2" while the setfiles never sealed the new axes |
| 4 | Friday-close inputs are `friday_close_enabled`, `friday_close_hour_broker` | Real names carry the prefix: **`qm_friday_close_enabled`, `qm_friday_close_hour_broker`** | Same silent-binding failure mode as #2 |
| 5 | Setfile pattern `QM5_<id>_<SYMBOL>_<TF>_<ENV>.set` | Real pattern includes the **slug**: `QM5_1537_aa-vol-sma10_AUDCAD.DWX_D1_backtest.set` | A set authored to the documented pattern is not found by the tooling |
| 6 | Risk-mode mismatch hard-fails as `EA_INPUT_RISK_MODE_MISMATCH` | That code exists **nowhere** in `build_check.ps1`; the real risk check is `EA_RISK_SIZER_UNCONFIGURED` | An agent quoting it reports a failure the tooling cannot emit |
| 7 | Reference `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md` | File does not exist | Dead citation |

Additionally corrected, not a falsehood but a trap: the pre-flight said the card lives at
`strategy-seeds/cards/<slug>_card.md`. That is the **draft** store (508 files). Approved
cards live in `strategy-seeds/cards/approved/` (567) and in the runtime reservoir
`D:/QM/strategy_farm/artifacts/cards_approved/` (3267). Checking only the draft path
produced a false FAIL on 2026-07-17.

An ordering note was added as well: `update_magic_resolver.py` keeps only rows whose EA
**directory** exists, so for a new EA the order is directory → magic rows → resolver
regeneration → verify → build → compile. The contract's "magic rows must already exist"
applies from the build step onward, not before the directory exists.

## Checked and found CORRECT

- `framework/templates/EA_Skeleton.mq5` exists.
- `framework/scripts/compile_one.ps1` exists.
- The five required input groups match `$requiredGroups` in `build_check.ps1` exactly
  (an extra `Stress` group is permitted and is not required).
- `EA_ML_FORBIDDEN` exists in `build_check.ps1`.
- `framework/V5_FRAMEWORK_DESIGN.md`, `docs/ops/DWX_IMPORT_AUTOMATION.md` and
  `decisions/2026-04-26_v5_framework_design.md` all exist.
- The magic formula `ea_id * 10000 + symbol_slot` matches the resolver.

## Why this mattered

Three of today's incidents trace back to this document rather than to the code: the Century
build block (#1), the QM5_11388 news-conformance defect class (#3), and the false 2026-07-17
preflight (#1 and the card path). A build contract that is wrong in its input names is worse
than no contract, because an agent following it produces an EA that compiles and then fails
silently at runtime binding.

## Standing rule adopted

A limit or failure code in a contract must be traceable to tooling that can enforce or emit
it. If a rule cannot be pointed at a line in `build_check.ps1`, a script, or a decision
record, it does not bind a build — and if it is later found to be real, it must be
reintroduced **with the failing evidence attached**, never as an unsourced number.

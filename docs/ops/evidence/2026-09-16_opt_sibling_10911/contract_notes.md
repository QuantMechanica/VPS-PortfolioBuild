# `_opt` measurement-sibling contract — QM5_10911 / GDAXI.DWX — 2026-09-16

**Author:** Kimi agent-16 (mechanical staging under Kimi interim OWNER delegation).
**Authority boundary:** contract analysis + artifact staging only. Card G0 seal, magic
allocation, and compile-receipt creation are governance steps and were NOT executed
(see `RECEIPT.md`).

The 4 pending Q12 rows for `DL089_QM5_10911_GDAXI_DWX_2019_2025`
(`96239586-47c0-5fe2-8ef5-3d29910cc47c`, `5cf3ea75-2fe0-5420-97c6-650678c52b31`,
`897169ba-9b8f-53ef-8c43-3013f3c7f2e8`, `779da760-42c2-50ed-80c3-263ef3366edb`)
are deferred by `tools/strategy_farm/dl089_matrix_service.py` with:

```
expected one approved _opt sibling for QM5_10911/GDAXI.DWX, found 0
```

Every requirement below was extracted from the canonical service code and verified
against the real approved sibling `QM5_41321_grimes-trendday-v2-opt` (and the
Amendment C siblings 41342-41347, built 2026-09-05).

## 1. Sibling discovery — `_measurement_sibling()` (dl089_matrix_service.py:271-359)

Discovery is **purely on-disk + card frontmatter**; no DB state is consulted for the
match itself:

| Check | Code | Exact requirement |
|---|---|---|
| Card path | `eas_root.glob("QM5_*_*-opt/docs/strategy_card.md")` | Card MUST live at `framework/EAs/QM5_<id>_<slug>-opt/docs/strategy_card.md`. The EA directory name itself must match glob `QM5_*_*-opt`. |
| Parent binding | `frontmatter["parent_ea_id"].upper() == subject_ea_id.upper()` | Frontmatter `parent_ea_id: QM5_10911`. |
| Symbol binding | `symbol.upper() in {t.upper() for t in frontmatter["target_symbols"]}` | `target_symbols` list must contain `GDAXI.DWX`. |
| G0 seal | `frontmatter["g0_status"].upper() == "APPROVED"` | **`g0_status: APPROVED` — OWNER-only per `processes/01-ea-lifecycle.md:32` and `processes/13-strategy-research.md:49`. THIS IS THE STOP LINE.** |
| EA id | `re.fullmatch(r"QM5_\d+", ea_id)` | `ea_id: QM5_41478` (verified free: absent from `framework/registry/ea_id_registry.csv`, `framework/registry/magic_numbers.csv`, and `work_items`). |
| Timeframe | `frontmatter["period"]` non-empty | `period: H1` (parent GDAXI book runs H1; base setfile name embeds it). |

Exactly ONE match must survive those filters (`len(matches) != 1` → the refusal
error). Unparseable cards are skipped, so a draft card without the seal cannot
poison discovery — but it also cannot match.

Required on-disk artifacts, paths derived from the EA-dir label
(`QM5_41478_grimes-complex-pb-opt`):

| Artifact | Path | Producer |
|---|---|---|
| Source | `framework/EAs/QM5_41478_grimes-complex-pb-opt/QM5_41478_grimes-complex-pb-opt.mq5` | EA engineering (staged here) |
| Binary | `framework/EAs/QM5_41478_grimes-complex-pb-opt/QM5_41478_grimes-complex-pb-opt.ex5` | governed COMPILE_EA lane (0 errors/0 warnings) |
| Base setfile | `framework/EAs/QM5_41478_grimes-complex-pb-opt/sets/QM5_41478_grimes-complex-pb-opt_GDAXI.DWX_H1_backtest.set` | canonical setfile tooling (staged here) |
| Card | `framework/EAs/QM5_41478_grimes-complex-pb-opt/docs/strategy_card.md` | created as card-of-record by `governed_magic_allocator.py` from the approved card |

## 2. Base-setfile content gate — `_neutral_matrix_setfile()` (dl089_matrix_service.py:166-224)

The service reads the sibling's base setfile, requires:

- keys `qm_ea_id`, `RISK_FIXED`, `RISK_PERCENT` present;
- `qm_ea_id` == sibling ea_id without prefix → **`qm_ea_id=41478`**;
- `RISK_FIXED > 0` and `RISK_PERCENT == 0` (parent GDAXI set ships 1000/0);
- `qm_news_stale_max_hours` (if present) ≤ 336;
- header must declare `; environment:` … `backtest` (case-insensitive);
- no duplicate `census.SET_KEYS` pattern inputs
  (`opt_pp_buy1..3`, `opt_pp_sell1..3` — opt_census.py:45-48).

The parent's own GDAXI setfile (`QM5_10911_grimes-complex-pb_GDAXI.DWX_H1_backtest.set`)
has **no `qm_ea_id` key** (pre-guard vintage) — the sibling setfile must add it.
All six `opt_pp_*` keys must be present (any value; the service rebinds them to 0
for the neutral matrix setfile it writes under
`D:\QM\strategy_farm\artifacts\opt_census\<program_id>\base_setfiles\`).

`census.validate_base_setfile()` (opt_census.py) re-checks the same contract.

## 3. Readiness gate — `_pattern_measurement_readiness()` (optimization_fork_driver.py:143)

Runs against the sibling source + neutral setfile text; `ready` must be true:

- all six `opt_pp_*` declared as `input` in the `.mq5`;
- source contains `QM_PatternPermission` and `QM_PatternPermissionEvaluate`;
- setfile carries the six keys + risk contract + backtest environment declaration.

## 4. Compile receipt — `_compile_receipt()` (dl089_matrix_service.py:362-386)

**DB requirement (governed lane):** latest `work_items` row for the sibling ea_id with
`phase='COMPILE_EA'`, `status='done'`, `verdict='COMPILE_OK'`, whose
`ex5_sha256`/`mq5_sha256` equal the on-disk `.ex5`/`.mq5` SHA-256 (hash drift →
service error). Example of a valid receipt: `07db9119-…` for QM5_41343
(2026-09-05). The receipt is produced by the factory build lane
(`compile_work_items.py` + MetaEditor, 0 errors/0 warnings, evidence path bound) —
currently quota-gated (codex hold to 2026-09-19) per KIMI_INTERIM_HANDOFF line 37.
No direct SQL writes were made or may be made to fabricate this.

## 5. Downstream (after the sibling passes)

1. `_seed_q02` — service seeds the measurement Q02 (2017-2022 native run) from the
   sealed declaration; worker executes it.
2. Q02 `done/PASS` + `_program_binding_guard` → matrix materializes on the next
   service pass (bounded by K/L/G scheduling).
3. Central operator then runs the apply pass (exact command in `RECEIPT.md`).

## 6. Reference sibling anatomy (verified diffs)

`QM5_13013 → QM5_41321` source delta (112 changed lines, 7 hunks — the template for
the staged 41478 source):

1. `#property description` gains ` - DL-089 opt sibling`; strategy-card comment updated;
2. `#define QM_PATTERN_PERMISSION_EA_MANAGED` before, and
   `#include <QM/QM_PatternPermission.mqh>` after, `#include <QM/QM_Common.mqh>`;
3. `input int qm_ea_id = <sibling id>;`
4. pattern measurement surface: six `opt_pp_*` inputs + `QM_PatternProfile` globals +
   `Pattern_Permission()` / `Opt_AddPattern()` / `Pattern_AllowsRequest()` (block is
   identity-free, byte-reusable);
5. `OnInit`: `QM_PP_ProfileInit(...)` + `Opt_AddPattern` chain (fail-closed) before
   `INIT_OK`; log identity updated;
6. `OnDeinit`: `PP_CENSUS_SUMMARY` telemetry log first;
7. entry gate: `if(Strategy_EntrySignal(req) && Pattern_AllowsRequest(req))`.

Amendment C verification evidence: `docs/ops/evidence/2026-09-05_amendment_c_opt_siblings.md`
(all six permission blocks byte-identical after CRLF normalization; RISK_FIXED=1000,
RISK_PERCENT=0; six zero permission inputs).

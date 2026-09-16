# Evidence Receipt — H-FXMR (QM-RESEARCH-2026-0005) → V5 EA build

**STATUS=REVIEW_PENDING** — build complete; independent non-Kimi critique still
required before any pipeline entry (claude disabled until 2026-09-17, codex on
hold until 2026-09-19, agy quota-dead).

**REGISTRY STATUS=PENDING_ALLOCATION** — no `ea_id_registry.csv` /
`magic_numbers.csv` rows exist for ea_id 41477 and `QM_MagicResolver.mqh` has
no 41477 tuples. Planned magic by convention (ea_id * 10000 + slot): slot 0
EURUSD.DWX = **414770000**, slot 1 GBPUSD.DWX = **414770001**, slot 2
USDJPY.DWX = **414770002**. Do not pipeline, backtest, or deploy until the
governed allocator completes (central allocation later; setfiles carry
`build_hash: pending`).

- Date: 2026-09-16 (UTC)
- Authority: interim OWNER_DIRECT_SESSION_DELEGATION to Kimi, 2026-09-16
  (build-only; no pipeline phase, no gate verdict, no live-trading-state changes)
- Worktree: `C:\QM\worktrees\kimi-fxmr-20260916`
- Branch: `agents/kimi-fxmr-20260916` (base commit `c9dcd9b5fa`)
- Main worktree: untouched (all work confined to the worktree)

## Deviation from the delegation brief (governance-forced, documented)

The brief named provenance id `QM-RESEARCH-2026-0004`. That id was **already
minted** by the CAMP-2026-0002-second-chance campaign (ledger mint row
2026-09-16T04:47:39Z, task `CAMP-2026-0002-second-chance`; the canonical
worktree holds that lane's uncommitted store at
`strategy-seeds/sources/QM-RESEARCH-2026-0004/` — a QM5_1354 second-chance
review, actively worked at build time). Per the INTERNAL_RESEARCH_SOURCE_CONTRACT
an id is never reused or re-numbered, so the H-FXMR artifact was minted as the
next free id **`QM-RESEARCH-2026-0005`** via the canonical
`tools/strategy_farm/research_source.py mint`. All card / EA references carry
0005. The briefly-created 0004 content in this worktree was removed again; the
other lane's canonical 0004 files were never touched.

## Branch history (this build)

| Commit | Content |
|---|---|
| `4b56b100fb` | research artifact QM-RESEARCH-2026-0005 (source.md, research.json, lineage.json, preregistration.json v1, H_FXMR_card.md, universe map computed output, PENDING critic scaffold) + formal G0 card QM5_41477 |
| `bf6b729a16` | EA implementation (.mq5 + QM5_41477_FxSessionMrCore.mqh) + SPEC.md + docs (visualization_spec) + 6 setfiles |
| HEAD (this commit) | evidence (this receipt, artifact hashes, setfile/ex5 hashes, preregister driver, prescreen report, research_source verify output, compile log copy) |

## Artifacts

| Item | Value |
|---|---|
| EA | `QM5_41477_fx-session-mean-reversion-m15` |
| Identity | ea_id 41477, slug `fx-session-mean-reversion-m15`, source QM-RESEARCH-2026-0005 (no registry rows — PENDING_ALLOCATION) |
| Magic (planned, by convention) | slot 0 EURUSD.DWX = **414770000**; slot 1 GBPUSD.DWX = **414770001**; slot 2 USDJPY.DWX = **414770002** |
| Card | `artifacts/cards_approved/QM5_41477_fx-session-mean-reversion-m15.md` (sha256 4cc607f3…b2ae) |
| EA dir | `framework/EAs/QM5_41477_fx-session-mean-reversion-m15/` (.mq5, QM5_41477_FxSessionMrCore.mqh, SPEC.md, docs/strategy_card.md, docs/visualization_spec.md, sets/) |
| Research store | `strategy-seeds/sources/QM-RESEARCH-2026-0005/` (source.md sha256 `ba89005b…7f8c` = the card `source_hash`; sealed into the shared research-source ledger with status `preregistered`) |
| Preregistration | `strategy-seeds/sources/QM-RESEARCH-2026-0005/preregistration.json`, record_sha256 **c408f534bc8825783d44487dd51def684227955988b680fbd4228d4578027475** (schema qm.research-preregistration/v1, version 1); mechanical spec H_FXMR_card.md sha256 `9d1c56c2…8583`; `preregister.py --check` → unchanged: true |
| Numeric provenance | every quantitative claim in research.json cites `universe_map_result.json` (deterministic `universe_map.py` projection of farm_state.sqlite, 14,939 pairs; sha256 `7f36343a…c118`) — 128 pairs = 0.86% high-density FTMO-fit, 0 FX FTMO incumbents, 8 session-specified FX intraday/scalp mean-reversion pairs. No LLM-computed figure |

## Critic status (REVIEW_PENDING gate)

`critic_receipt.json` in the store is an **empty mint scaffold with an explicit
PENDING marker** — not a real receipt. `research_source.py verify
--id QM-RESEARCH-2026-0005` passes every check except the eight
`MISSING_FIELD:critic.*` sub-reasons (output in `research_source_verify.json`):
ledger anchored and status admissible, source_hash binding matches, manifest
hashes recompute, numeric claims backed, author authorized. It goes green only
when a real non-Kimi critic run fills the receipt (earliest: claude
2026-09-17). `card_intake_prescreen.py` therefore returns REJECT with the
single reason `INTERNAL_SOURCE_UNRESOLVED:MISSING_FIELD:critic.*`
(`card_prescreen_report.json`) — every non-critic check (DWX symbol matrix,
charter sections, expected_dd 2.0, timeframe M15, risk contract, runtime-ML
boundary) passes.

## Compile

- MetaEditor 64 `D:\QM\mt5\T1\metaeditor64.exe /compile` with `/inc` pointed at
  `artifacts/builds/inc_staging` (worktree `framework/include` staged under
  `Include\` + terminal stdlib from `D:\QM\mt5\T1\MQL5\Include`; the Roaming
  profile include tree was NOT mutated).
- Result: **0 errors, 0 warnings** (8912 ms) — `compile_log_local_wt_includes.txt`.
- `.ex5` sha256 **4e07143ac4e07ed644ba7865a7b1d8a7b262f16696386bb2f7e1248117c1219b** (not committed — EX5_COMMIT_GUARD requires a governed COMPILE_EA receipt; hash recorded in `setfile_and_ex5_sha256.txt`).
- `compile_one.ps1 -Strict` / `build_check.ps1` were not invoked: they are the
  governed-lane wrappers and this is a PENDING_ALLOCATION build (magic rows
  absent by design); substitute checks below mirror the H-CW first-session lane.

## Tests

- `python -m pytest -q tools/strategy_farm/tests/test_governed_magic_allocator.py tools/strategy_farm/tests/test_magic_allocation_precheck.py framework/scripts/tests/test_magic_resolver_strict_default.py` → **21 passed** (registry untouched — 41475 rows unchanged, no 41477 rows written).
- `python framework/scripts/lint_ea_symbol_literals.py --ea-root framework/EAs/QM5_41477_fx-session-mean-reversion-m15` → **OK** (no hardcoded .DWX literals).
- `python tools/strategy_farm/research/preregister.py --check strategy-seeds/sources/QM-RESEARCH-2026-0005/preregistration.json strategy-seeds/sources/QM-RESEARCH-2026-0005/H_FXMR_card.md` → unchanged: true.

## Setfiles

6 × `sets/QM5_41477_fx-session-mean-reversion-m15_<SYMBOL>_M15_<backtest|live>.set`
(EURUSD.DWX slots 0, GBPUSD.DWX slot 1, USDJPY.DWX slot 2; backtest RISK_FIXED /
live RISK_PERCENT per the risk-mode contract; card defaults bound). Header
`build_hash: pending` is the canonical pre-compile state; the governed compile
(build_check set-header update) stamps the real hash after allocation.
Hand-authored here (mirroring the H-CW first session); regenerate canonically
via `framework/scripts/gen_setfile.ps1` once the magic rows exist. Per-file
sha256 in `setfile_and_ex5_sha256.txt`.

## Smoke

**Skipped (documented).** The governed smoke admission
(`custom_history_smoke_admission.py`) is a farm-reservation gate writing
factory state (`terminal_reservations.json`), and terminals T1-class are
factory/live-book busy — the same condition under which H-CW skipped smoke.
**Post-integration acceptance rule (house):** run the governed smoke on the
first card-listed symbol (EURUSD.DWX) after allocation; it must produce ≥1
trade or a documented zero-trade reason.

## Artifact hashes

- `artifact_sha256.txt` — mq5, mqh, preregistration.json, H_FXMR_card.md, source.md, research.json, lineage.json, card.
- `setfile_and_ex5_sha256.txt` — 6 setfiles + ex5.

## Next steps

1. Independent non-Kimi critique of card / preregistration / EA (REVIEW_PENDING gate; fills critic_receipt.json and flips the prescreen to KEEP).
2. Governed magic allocation for ea_id 41477 (3 rows) by the central allocator; regenerate the resolver; recompile in the governed lane (COMPILE_EA → build_check stamps setfile build_hash).
3. Governed smoke on EURUSD.DWX (acceptance rule above).
4. Only after 1-3: Q00/pipeline entry is a separate governance decision.

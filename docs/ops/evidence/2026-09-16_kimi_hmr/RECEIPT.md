# Evidence Receipt — H-MR (QM-RESEARCH-2026-0006) → V5 EA build

**STATUS=REVIEW_PENDING** — build complete AND registry-clean; independent
non-Kimi critique still required before any pipeline entry (claude disabled
until 2026-09-17, codex on hold until 2026-09-19, agy quota-dead).

**REGISTRY STATUS=PENDING_ALLOCATION** — NO `ea_id_registry.csv` /
`magic_numbers.csv` rows exist for 41476 and `QM_MagicResolver.mqh` has no
41476 tuples (verified: 21-test allocator/precheck/resolver suite passes
with the registry untouched). Allocation is centralized after this build.
Planned magic by convention (ea_id*10000 + slot, slots per approved-card
symbol order): slot 0 NDX.DWX = **414760000**, slot 1 GDAXI.DWX =
**414760001**, slot 2 SP500.DWX = **414760002**. Do not pipeline, backtest,
or deploy before allocation completes.

- Date: 2026-09-16 (UTC)
- Authority: OWNER_DIRECT_SESSION_DELEGATION to Kimi, 2026-09-15 (build-only;
  no pipeline phase, no gate verdict, no live-trading-state changes)
- Worktree: `C:\QM\worktrees\kimi-hmr-20260916`
- Branch: `agents/kimi-hmr-20260916` (base commit `c9dcd9b5fa`, current main HEAD)
- Main/canonical worktree: untouched (all work confined to the worktree);
  41475's files: untouched

## Research-source id allocation note (deviation from task text, governed)

The task text referenced `QM-RESEARCH-2026-0003`. That id was already minted
by CAMP-2026-0002-second-chance (canonical repo, uncommitted store), and
during this build a parallel OWNER delegation (`owner-delegation-h-fxmr-
20260916`, an FX mean-reversion sibling) raced for the next id and took
`QM-RESEARCH-2026-0005` (ledger rows mint→preregistered at 04:53–04:54Z).
Per the contract ("never reused, never re-numbered"; allocation only by
`research_source.py mint`), this build used the canonical mint, which
allocated **QM-RESEARCH-2026-0006** (ledger `mint` row 04:57:59Z,
`preregistered` row after the freeze). Ledger appends were performed by the
canonical tooling (append-only; same mechanism the second-chance campaign
used) — the H-CW build skipped them only because its id pre-existed.

## Artifacts

| Item | Value |
|---|---|
| EA | `QM5_41476_cash-open-mean-reversion-h1` |
| Identity | ea_id 41476, slug `cash-open-mean-reversion-h1`, provenance QM-RESEARCH-2026-0006 (PENDING_ALLOCATION) |
| Magic (planned) | slot 0 NDX.DWX 414760000 / slot 1 GDAXI.DWX 414760001 / slot 2 SP500.DWX 414760002 — not yet allocated |
| Research store | `strategy-seeds/sources/QM-RESEARCH-2026-0006/` (source.md sealed, research.json, lineage.json, critic_receipt.json skeleton, H_MR_card.md, mechanization_result.json, h_mr_fire_count.json + deterministic script) |
| Source hash | sha256(source.md) = **1887b25e0fb0597f97a9a9ae9461333bc16d3b2b6e0a8bf96412cea55032bd19** (== ledger sha256 after seal) |
| Preregistration | record_sha256 **8129b0fc617229c40f7898c64a79072ff93019eb08fc7fa7faef69987b140d2d** (schema qm.research-preregistration/v1, version 1); mechanical spec sha256 f722f2df...4b17 (H_MR_card.md); `preregister.py --check` → unchanged: true |
| Mechanization gate | **PASS**, zero findings (`mechanization_result.json`) |
| Pilot computed output | `h_mr_fire_count.json` (deterministic, NDX-class Dukascopy feed 2018-2020): 489 evaluated days, 154 shock-skipped, 135 gross signals, 82 taken, 2.9 trades/month, ~4.7 active days/month, raw PF(R) 1.12 at +0.02R/trade, 30% midpoint hit rate — PILOT_MOTIVATION_NOT_PROOF, below the preregistered success bar by design |
| Card | `artifacts/cards_approved/QM5_41476_cash-open-mean-reversion-h1.md` (sha256 in artifact_sha256.txt) |
| EA dir | `framework/EAs/QM5_41476_cash-open-mean-reversion-h1/` (.mq5, QM5_41476_CashOpenMR.mqh, SPEC.md, docs/strategy_card.md, docs/visualization_spec.md, sets/) |
| Setfiles | 6 × `sets/QM5_41476_cash-open-mean-reversion-h1_<SYMBOL>_H1_<backtest|live>.set`, hand-authored in the canonical `gen_setfile.ps1` output format (identical bytes-shape to H-CW's first-session sets): header `build_hash: pending`, magic_slot per approved-card symbol order, card defaults bound via the card's `| param | default |` table. Canonical regeneration via `gen_setfile.ps1` is DEFERRED until after governed allocation (the generator fail-closes on MAGIC_REGISTRY_ROW_MISSING by design — same two-step flow H-CW used). Per-file sha256 in `setfile_and_ex5_sha256.txt`. |

## Compile

- Canonical gate: `framework/scripts/build_check.ps1 -EALabel QM5_41476_cash-open-mean-reversion-h1` → **build_check.result=PASS, 0 failures**; `compile_one.result=PASS`, **0 errors, 0 warnings** (metaeditor exit 1 = success code). Full output: `build_check_run.txt`.
- First-pass manual MetaEditor 64 compile (`D:\QM\mt5\T1\metaeditor64.exe /compile` with `/inc` at `artifacts/builds/inc_staging`, worktree `framework/include` overlaid on the terminal stdlib) also **0 errors, 0 warnings** (`compile_log_local_wt_includes.txt`).
- `.ex5` sha256 (canonical build_check binary) **89d1107a00ef0365d2a50b7a2a5621c31cba60df9aab39afb131a70d2cf3a702** — NOT committed (EX5_COMMIT_GUARD requires a governed COMPILE_EA receipt; hash recorded in `setfile_and_ex5_sha256.txt`).
- build_check warnings (4, all documented): `EA_EVENT_VOCABULARY_UNKNOWN` for the bespoke `INIT_SLOT_MISMATCH` event (same event name as the H-CW sibling; framework vocabulary registry is out of build scope); `EA_CARD_LOSS_LIMIT_UNDECIDABLE` / `EA_BROKER_TIME_WINDOW_UNDECIDABLE` / `EA_CARD_PENDING_ORDER_UNDECIDABLE` — expected under PENDING_ALLOCATION (no card-of-record in the canonical store yet); they become decidable after allocation/integration.

## Tests

- `python -m pytest -q tools/strategy_farm/tests/test_governed_magic_allocator.py tools/strategy_farm/tests/test_magic_allocation_precheck.py framework/scripts/tests/test_magic_resolver_strict_default.py` → **21 passed** (registry untouched; VERIFICATION_TEST_PASS_COUNT met).
- `lint_ea_symbol_literals.py --ea-root framework/EAs/QM5_41476_cash-open-mean-reversion-h1` → **OK** (no hardcoded .DWX literals in logic; the 3 build_check symbol-literal occurrences are the sanctioned `strategy_symbol_slot*` input defaults, same pattern as H-CW).
- `research_source.py verify --id QM-RESEARCH-2026-0006` → fails closed ONLY on the critic receipt fields (`MISSING_FIELD:critic.*`) — hashes, manifest, numeric provenance, ledger status (preregistered), and trial count all pass. The critic is the single outstanding intake gate.
- `card_intake_prescreen.py --card <card>` → **REJECT with two reasons** (verbatim in `card_prescreen_report.json`):
  1. `INTERNAL_SOURCE_UNRESOLVED:MISSING_FIELD:critic.*` — the true gate: cross-vendor critique pending (REVIEW_PENDING). Resolves when the critic seat runs (claude ≥ 2026-09-17, codex ≥ 2026-09-19).
  2. `NEAR_DUPLICATE:QM5_10140_tv-london-session-break.md:score=1.0000` — analyzed FALSE POSITIVE: the mechanism-term overlap is exactly the bigrams {`opening range`, `range breakout`}, which are QM5_10140's only two mechanism terms; H-MR is the opposite thesis (failed-breakout REVERSION to the range midpoint vs London-session breakout CONTINUATION), different source id/slug/universe-side (GDAXI vs WS30). The lexical score is a bigram-collision artifact, not a duplicate thesis.
- G0 APPROVED under OWNER_DIRECT_SESSION_DELEGATION stands independently of the intake prescreen (same authorization shape as H-CW); governed intake completes after critique + allocation + integration.

## Smoke

**Skipped (documented acceptance rule).** The governed smoke admission
(`custom_history_smoke_admission.py`) is a farm-reservation gate: it connects
to the farm DB, checks active work-item claims, and writes
`terminal_reservations.json` — factory-state writes outside this delegation.
Live terminals are currently running books (T_Live / FTMO Global Markets
terminal64 processes observed alive).
**Post-integration acceptance rule (house):** run the governed smoke on the
first card-listed symbol (NDX.DWX); it must produce ≥1 trade or a documented
zero-trade reason.

## Artifact hashes

- `artifact_sha256.txt` — ex5, sources, research artifact, card.
- `setfile_and_ex5_sha256.txt` — 6 setfiles + ex5.

## Next steps for Fable

1. Independent critique of card / preregistration / EA (REVIEW_PENDING gate; critic receipt replaces the skeleton → `research_source verify` green).
2. Governed magic allocation for ea_id 41476 (3 slots; planned values above), resolver regeneration, then canonical `gen_setfile.ps1` regeneration of the 6 setfiles (stamps real build_hash in the governed lane).
3. Integrate this branch to main (registry/EA files merge cleanly; no factory-file conflicts expected from this scoped branch).
4. Governed lane: COMPILE_EA (governed receipt → .ex5 commit becomes legal) → smoke (acceptance rule above).
5. Only after 1+2+4: Q00/pipeline entry is a separate governance decision.

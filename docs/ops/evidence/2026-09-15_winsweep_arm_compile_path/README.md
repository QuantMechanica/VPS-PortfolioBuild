# Winsweep-arm compile path — governed determination (2026-09-15)

Task `11eff123-53b9-4153-ad40-c1e44b76ac4e` (agent_router, claude/Sonnet lane).
Branch `agents/board-advisor`.

Eleven repaired-but-never-compiled winsweep arms — QM5_41113, 41123, 41135,
41138, 41157, 41160, 41179, 41181, 41187, 41188, 41189 — had their sources freed
of `EA_FRAMEWORK_INPUT_PINNED` and symbol literals in commits `14d548c87a`,
`de88a19e7b`, `d0433c1c1d`. The task asks which **governed, append-only** compile
path applies to each: **(a)** the sweep program's own enqueue, or **(b)** a
card + `build_ea` commission (ROT — card universe, never autonomous).

**Result: path (a) is unavailable by construction; path (b) is the only route and
it is ROT for all 11 arms. Nothing was applied. All 11 arms are OWNER-blocked on a
card-universe decision.** This is a diagnosis-only cycle.

- Plan (deterministic, per-arm content sha): `plan.json`
- **plan_sha256: `ecaa44d2e652684a8b8c9089874549ec0d8dc1b4c4a921249361cc6b3b3677fa`**
- QM5_20042 / QM5_20053 are **out of scope** (DWX-matrix XBRUSD/XCUUSD gap, OWNER
  decision) and were not touched.

## Why path (a) — the sweep program's own enqueue — cannot compile these arms

Investigated `window_sweep.py` and `config_sweep.py` (the two sweep engines) end
to end:

- **`window_sweep.py`** is a *sealed, program-specific* experiment hard-bound to
  `PROGRAM='WINSWEEP_QM5_41398_USDJPY_DWX_2019_2025'` (`EA=QM5_41398`,
  `symbol='USDJPY.DWX'`). It can enqueue nothing for any other EA. None of the 11
  arms is 41398.
- **`config_sweep.py`** is the general declared-sweep engine, but its
  `validate_declaration` (lines 311-361) **requires** `approved_card_path` +
  `approved_card_commit` (verified against the committed blob via
  `_approved_card_commit`) **and** a pre-existing compiled binary identity
  (`artifact_identity.ex5_sha256`, checked against on-disk). Its `enqueue` (line
  635) mints **OPT_CENSUS backtest cells** (`opt_census_pool`, RISK_FIXED,
  per-year/arm setfiles), **not `COMPILE_EA` rows**.

So the payload's premise — that "config_sweep.py / window_sweep declarations
minted the original compile rows" — is **refuted by the code**. These engines
presuppose an already-compiled, already-carded EA and produce optimization cells.
The original `COMPILE_EA` rows for the arms that have them (41113/41123/41179/
41189/41187/41188) came from the normal `build_ea → COMPILE_EA` pipeline, which is
card-gated. There is no append-only, per-arm, compile-only re-issue in either
sweep engine that binds to an existing declaration without a card.

## Live-state disposition (recomputed from DB + on-disk source, not the 09-13 snapshot)

DB: `D:/QM/strategy_farm/state/farm_state.sqlite` (read-only). Cards checked in
`artifacts/cards_approved` (C:, 253 files), `D:/QM/strategy_farm/artifacts/cards_approved`
(3434 files), and `state/artifacts/cards_approved` — by numeric id, by strategy
slug, and via the repair-successor tool's own `has_approved_card`. **Zero of 11
have an approved card.** No `build_ea` `agent_tasks` exist for any arm.

| arm | slug | on-disk mq5 sha | compile rows (live) | card | only path | verdict |
|---|---|---|---|---|---|---|
| 41113 | xauxag-mhalfagree-rv | `20faafb2f1f4…` | pending(void) + COMPILE_OK@old-src | none | (b) | OWNER-blocked |
| 41123 | xauxag-mpath-eff-rv | `69aa644a3837…` | pending(void) + COMPILE_OK@old-src | none | (b) | OWNER-blocked |
| 41135 | xauxag-mdaily-iqrmean-rv | `0c0b17b527ed…` | **none** (never in pipeline) | none | (b) | OWNER-blocked |
| 41138 | xauxag-mdaily-hl-rv | `4be1f5189355…` | **none** | none | (b) | OWNER-blocked |
| 41157 | xauxag-mtheilsen-rv | `9be2f4840d88…` | **none** | none | (b) | OWNER-blocked |
| 41160 | xauxag-mlad-rv | `aa2b54ba4cf9…` | **none** | none | (b) | OWNER-blocked |
| 41179 | xtixng-mcoxstuart-rv | `ed6f54885c94…` | pending + 2× COMPILE_FAIL | none | (b) | OWNER-blocked |
| 41181 | xauxag-mkendall-rv | `cd757bac0be2…` | **none** | none | (b) | OWNER-blocked |
| 41187 | xauxag-mks-rv | `7c21ac9ad730…` | 1× COMPILE_FAIL | none | (b) | OWNER-blocked |
| 41188 | xtixng-mrepmedian-rv | `7fc514b19ad6…` | 1× COMPILE_FAIL | none | (b) | OWNER-blocked |
| 41189 | xtixng-mlad-rv | `b6c0052a0fae…` | 2× pending(stale) + 2× COMPILE_FAIL | none | (b) | OWNER-blocked |

## Every governed append-only lever refuses (dry-runs, this cycle)

- `reissue_stale_compile_rows_0913.py` — plan_sha256 `9d4edf5a9018…`, **30 rows,
  all `skip`**. Our arms: 41113/41123 = `SKIP_NON_ROLLOUT_ORPHAN_NEEDS_SEPARATE_PATH`;
  41179/41189 = `SKIP_PREDECESSOR_ALREADY_SUPERSEDED` (the rollout-reconciliation
  authority is one-shot and exhausted — see the 2026-09-13 README §41189). The
  other 7 arms have no held rollout row to re-issue.
- `repair_successor_stale_compile_rows_0913.py` — plan_sha256 `5430ca9ace01…`,
  **0 eligible**. 41113/41123 = `FLAG_NEEDS_FRESH_BUILD_EA`; 41179/41189 =
  `FLAG_NEEDS_OPEN_BUILD_TASK`; all four `has_approved_card=false`,
  `needs_commission=true`. `enqueue_repair_successor` requires an OPEN,
  identity-matching `build_ea` task — none exists, and none can be commissioned
  without a card.
- `release_compile_wave.py` — **`release_count=0`** (13 held pending, all deferred
  `SOURCE_SHA_STALE_OR_MISSING`). 41189's pending row `81687a5b` is stale
  (pinned `8989d43b…`, on-disk `b6c0052a…`), not wave-ready. No arm is releasable.

## What each arm needs (the ROT boundary)

Every arm's only route is **(b) mint an approved Strategy Card → `build_ea`
task → compile**. Per the Stehende Vollmacht (OWNER 2026-08-20), "candidate-pool
definition & card universes" is **ROT — never autonomous**. Minting a brand-new
card for any of these 11 arms is therefore an explicit OWNER decision. **No card
was created; no `build_ea` task was fabricated; no compile row was written.**

Once OWNER decides the card universe for these arms and an approved card + open
`build_ea` task exist, the existing tooling handles the rest append-only:

- 41179/41189 (and any arm with a terminal `COMPILE_FAIL` at a now-repaired
  source): `repair_successor_stale_compile_rows_0913.py` will plan a governed
  repair-successor automatically; then `release_compile_wave.py --max-items 1
  --apply` per staggered wave.
- 41113/41123/41135/41138/41157/41160/41181/41187/41188: normal factory
  `build_ea → COMPILE_EA → release_compile_wave` once carded.

## Verification commands (all read-only / dry-run this cycle)

```
python -X utf8 tools/strategy_farm/session_tools/reissue_stale_compile_rows_0913.py
python -X utf8 tools/strategy_farm/session_tools/repair_successor_stale_compile_rows_0913.py
python -X utf8 tools/strategy_farm/release_compile_wave.py
```

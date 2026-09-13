# Symbol-fix requalification — five OWNER-priority EAs re-enter the DL-089 chain from Q02

- Recorded at: `2026-09-13T17:45Z`
- OWNER decision: `OWNER_DECISION_2026-09-13_SYMBOL_FIX_PRIORITY_TRACK`
  (`decisions/2026-09-13_owner_symbol_fix_priority_track.md`, commit `e7a97eb835`)
- Source patches: `9359ecaf2b` (symbol inputs + canonical base-name comparison), `e6ad6ee47a` (MAE hook, card
  reference_symbols contract)
- Plan manifest: `docs/ops/evidence/2026-09-13_symbol_fix_requal/2026-09-13_symbol_fix_requal_manifest.json`
  SHA-256 `439713e40ca70b187f288d9910c87f84f353dc843ef98e3a405153250a7089d3`
- Precedent followed: DL-089 wave-1 requal8 (`docs/ops/evidence/2026-08-30_8709bc0f_q09_requal8_manifest.json`,
  serial pair `QM5_12989 -> QM5_41216`)

## Why new identities

A rebuilt EX5 is a new identity from Q02 (identity rule 2026-08-23). Under the old `ea_id` neither the append-only
Q02 rerun (`q02_append_only_rerun_requires_same_exact_source_and_rerun_row`) nor `farmctl intake-first-q02`
(`existing_q02_row`, reproduced read-only on `18ddeaf3-1daf-416a-832d-52d82f008fd4` / `QM5_21505`) can reopen Q02.
The requal8 precedent solves this with a serial pair `<old> -> <new 41xxx>`.

## Serial pairs

| Predecessor | Successor | Symbols (magic slots) | TF | Old-id COMPILE_EA | New-id COMPILE_EA | Q02 row |
|---|---|---|---|---|---|---|
| `QM5_12969_usdjpy-gotobi-nakane-fix` | `QM5_41470_usdjpy-gotobi-nakane-fix-symfix` | USDJPY.DWX (0) | M30 | `f32ddc4a` COMPILE_OK | `624dde76` COMPILE_OK | `7ee74893-fb56-4897-b2ff-89eab5491481` |
| `QM5_12778_edgelab-audusd-eurjpy-cointegration` | `QM5_41471_edgelab-audusd-eurjpy-cointegration-symfix` | AUDUSD.DWX (0), EURJPY.DWX (1) | D1 | `7022358c` COMPILE_OK | `8250ae30` COMPILE_OK | `26aaec94-02ee-4a71-9eed-68b624b45adc` |
| `QM5_13117_eurgbp-audjpy` | `QM5_41472_eurgbp-audjpy-symfix` | EURGBP.DWX (0), AUDJPY.DWX (1) | D1 | `62c3f0de` COMPILE_OK | `f478f59e` COMPILE_OK | `1f8a23d2-6824-4d56-916b-6c76a2b1ed21` |
| `QM5_13054_brent-tom-mom` | `QM5_41473_brent-tom-mom-symfix` | XTIUSD.DWX (0) | D1 | `fde9660b` COMPILE_OK | `1bd628b0` COMPILE_OK | `152523e4-d30b-46d6-b96a-60b669f82a36` |
| `QM5_21505_xag-weekly-lowvol-momentum` | `QM5_41474_xag-weekly-lowvol-momentum-symfix` | XAGUSD.DWX (0) | D1 | `18ddeaf3` COMPILE_OK | `fa0d5533` COMPILE_OK | `b02b0a87-6f7f-4400-ad54-8e1503a84e43` |

Magic numbers follow `ea_id*10000+slot`: `414700000`, `414710000/414710001`, `414720000/414720001`, `414730000`,
`414740000`.

## Governed sequence actually executed

1. **Recovery cards** written into the runtime review store (requal8 precedent — not into `cards_approved`, so the
   card universe is untouched): `D:\QM\strategy_farm\artifacts\cards_review\QM5_4147{0..4}_*-symfix.md`. Each binds
   its mechanics to the predecessor `framework/EAs/<old label>/docs/strategy_card.md`.
2. **Governed allocator** (`tools/strategy_farm/governed_magic_allocator.py --card ... x5`), dry run then apply.
   Receipt: `2026-09-13_symbol_fix_allocator_receipt.json` (dry run: `2026-09-13_symbol_fix_allocator_dry_run.json`).
   5 identity rows, 7 magic rows, resolver regenerated (`18340 -> 18347` rows), zero status-aware collisions,
   zero retired rows touched. Order kept: dirs -> CSV -> regen -> verify -> compile.
3. **Patched sources transferred** (`2026-09-13_symbol_fix_source_transfer.json`). The `.mq5` of each successor is
   **byte-identical to the patched predecessor after replacing only the numeric EA id** (verified: covers
   `#property description`, the `qm_ea_id` input default, `QM5_<id>_*` reason/log tags, and the hard identity guard
   `if(qm_ea_id != 21505 ...)` in QM5_21505). `SPEC.md` carries the new identity header.
4. **Basket manifests** for the two cointegration pairs were copied with an explicit
   `execution_symbols` / `signal_only_symbols` role split (traded legs vs. conversion-history legs), which the Q02
   intake role contract requires; the logical host symbol and its custom history are unchanged
   (`QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`, `QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1`). The hand-authored
   logical host setfile was copied with only `ea_id`/`ea_slug` comments rewritten and `build_hash` reset to `pending`
   (it cannot be produced by `gen_setfile.ps1`, which requires an active magic row per symbol).
5. **Setfiles pre-seeded** with the canonical generator `framework/scripts/gen_setfile.ps1`
   (`-Env backtest -RiskFixed 1000 -RiskPercent 0`). Because no approved card exists for the new labels, the
   generator falls back to the EA input defaults — every generated setfile was verified **parameter-identical to its
   predecessor's `_backtest.set`** (only `qm_ea_id` differs; `strategy_vol_percentile` 33 vs 33.0 is the same value).
   `build_hash: pending` keeps `bound_setfile_hashes` empty so the compile candidate stays plain-eligible.
6. **`farmctl enqueue-compile <new label>`** per identity; each row carried the standard
   `COMPILE_EA_WORKER_ROLLOUT_PENDING` activation hold, released one at a time through
   `farmctl release-hold` (same ceremony and release note used for the old-id rows earlier today).
7. **`farmctl intake-first-q02 --apply`** per COMPILE_OK identity — read-only plan first, `ELIGIBLE` in every case.
8. **Priority track** via `farmctl mark-priority-track` (append-only queue-order mark, `priority_track=true`,
   never touches status/verdict/evidence). Log: `D:\QM\reports\state\priority_track_marks.jsonl`.
   Four of five rows carry `priority_track=true`. `QM5_41470` (`7ee74893`) was claimed by `T6` seconds after
   intake, so the mark refused with `work_item_not_pending:active` — the row is already executing, which is what
   the priority mark would have bought it. No retry, nothing forced.

All five identities reached `COMPILE_OK`; all five hold exactly one `Q02` row. Zero Q02 rows existed for any of the
new identities before this run.

## OWNER priority registry — defect found and repaired

`framework/registry/owner_priority_tracks.json` did **not load at all** before this run:
`strategy_priority.load_owner_priority_registry` returned `load_status=invalid`,
`error=entry_22_decision_source_commit_invalid`, `0` entries. Cause: the two entries added for the 2026-09-13
decision (`QM5_13054`, `QM5_21505`) carried `commit_sha: null`, which the loader rejects — and the loader fails the
**whole file**, so all 24 committed OWNER priority entries were silently inert.

Repair applied in the working tree: `commit_sha` set to `e7a97eb835df85465a9a7f14c877fd9b8903d253` (the commit that
added the decision record) for both entries, plus five new entries for `QM5_41470..41474` bound to the same
decision. The registry now loads with 29 entries
(SHA-256 `7dfbf1e380621c0af627f6cc07ec6caf113cf7fe39e74c788e93444f0a7aafa4` ->
`0dce3a3426f0a62b16d1cbc5f11d34af79992039ed5fbc437d71ef357bc33c07`).

## `set_priority_track.py` — plan produced, apply refused

`docs/ops/evidence/2026-09-13_symbol_fix_requal/2026-09-13_symbol_fix_priority_track_plan.json`
(expectations: `..._priority_track_expectations.json`, SHA-256
`144123ae58d82fa4c007d92e9e7786224a9c2ec837c0ad61b1dcfd970b6459dd`). Status `BLOCKED`, exact blockers:

1. `git provenance: controller/registry source scope is not committed and clean: M framework/registry/owner_priority_tracks.json`
   — the controller refuses while the registry repair is uncommitted. Committing is outside this run's authority.
2. `26aaec94-...: symbol is outside OWNER registry targets` — a basket Q02 row runs on the **logical host symbol**,
   and the registry contract only accepts `.DWX` targets. `set_priority_track.py` can structurally never mark a
   basket Q02 row; `mark-priority-track` is the correct instrument there.

The queue-order effect OWNER asked for is therefore already in place through `mark-priority-track`.
`set_priority_track.py --apply` can be run for the two single-symbol rows after the registry repair is committed.

## No-touch confirmation

`C:\QM\mt5\T_Live` and every live binary untouched; no AutoTrading action. No existing work item, verdict, evidence
row or setfile of `QM5_12969 / 12778 / 13117 / 13054 / 21505` was modified — their COMPILE_EA rows from today stand
as the source-build proof and nothing else about them changed. No worker was restarted. No verdict was asserted:
Q02 onward remains the judge.

# OWNER CEO-MP-#6 — Retro Re-Adjudication Enqueue (Cohorts A & B)

**Date:** 2026-08-21  
**Authority:** OWNER decision `CEO-MP-#6`, ratified 2026-08-21 — *append-only re-runs of two historical cohorts approved; old verdicts stay in place as evidence, nothing overwritten.* Recorded in `D:/QM/reports/state/owner_decisions.json` and vault `12 ToDo/AI ToDos/OWNER.md`.  
**Action class:** Enqueue-only + queue-priority raise (GRÜN). No backtest launched, no terminal64 started, no Factory OFF/ON, no reboot, no T_Live contact.  
**State DB:** `D:/QM/strategy_farm/state/farm_state.sqlite` (`work_items`).

## 1. Cohort definitions (independently confirmed against runner source)

- **Cohort A — retired 15 % DD ceiling.** Q05/Q06 rows that FAILed with `dd_above_ceiling:...:max=15.0` while the ceiling was 15 %. The ceiling was raised to 25 % on 2026-07-15 (`framework/scripts/q05_stress_medium.py:52` `DD_PCT_MAX = 25.0`; decision `decisions/2026-07-15_dd_ceiling_25pct_portfolio_rationale.md`). A row whose recorded `dd_pct` is **≤ 25** would pass the DD gate today. Rows with dd far above 25 (47 %, 61 %, 78 % …) still FAIL under the 25 % ceiling and are **not** candidates — the dd ≤ 25 filter is part of the cohort definition.
- **Cohort B — Q06 PASS_SOFT band (Q06-only).** Q06 rows that FAILed with `pf_below_floor:pf=X:floor=1.0` where PF ∈ **[0.95, 1.00)**. Since commit `47f751d1d` the Q06 runner emits `PASS_SOFT` for exactly that band when `dd_pct ≤ 25` and `trades ≥ MIN_TRADES` (`framework/scripts/q06_stress_harsh.py:218`, `SOFT_PF_FLOOR = 0.95`). Q05 has **no** PASS_SOFT (`q05_stress_medium.py:581` keeps `pf_below_floor` a hard FAIL) — Cohort B is Q06-only.

## 2. Derivation rule (re-derived independently from the DB, not trusting the pre-computed list)

Durable source of truth for cohort membership = `work_items.payload_json → verdict_reason` (the reason string encodes dd_pct for cohort A and pf for cohort B). Per-row `dd_pct` for a `pf_below_floor` row is **not** in the DB and the Q06 `aggregate.json` evidence file is overwritten per run, so the dd < 25 sub-check for band rows relies on the pre-computed live-evidence measurement (see §5).

1. Candidate FAIL rows = `verdict='FAIL'` with a cohort-matching `verdict_reason`; Cohort A additionally filtered to `dd_pct ≤ 25` and phase ∈ {Q05, Q06}; Cohort B to phase = Q06 and pf ∈ [0.95, 1.00).
2. Drop any (phase, ea, symbol) triple that already has a `PASS%` verdict at that phase, or **any** row at a later phase (order Q00→Q10→Q14+) — already through the gate, re-running is waste.
3. Drop band rows measured at dd ≥ 25 % (they stay FAIL under PASS_SOFT anyway).
4. Deduplicate to one re-run per triple = the newest terminal (`done/failed`, verdict set, unclaimed) row for that triple.

**Funnel (distinct triples):** Cohort A 50 raw → 10 (dd ≤ 25) → **3** (not already-through). Cohort B 23 raw → 13 (not already-through) → **11** (−2 dd ≥ 25). **Total = 14 candidates**, identical to the pre-computed set (same 14 `rerun_of` ids).

## 3. Full adjudication table

| # | Cohort | EA | Symbol | Phase | Old row (preserved) | Old reason | Predecessor (Q04/Q05 PASS) | New rerun row | current .ex5 sha256 (12) | Result |
|---|--------|----|--------|-------|---------------------|-----------|-----------------------------|---------------|--------------------------|--------|
| 1 | A | QM5_10916 | GDAXI.DWX | Q05 | `dc66cdca-e08f-4918-b054-a757a03769f6` | `dd_above_ceiling:dd_pct=15.10:max=15.0` | `cdeb1f81-efa6-4cd2-8ac4-cbcb321248fb` | `6e085b6f-0a29-42d2-9494-fe061e0fb236` | `b55ac30bbfaa` | ENQUEUED |
| 2 | A | QM5_11196 | XAUUSD.DWX | Q05 | `0cf2c011-b977-4835-b03d-019c537f5cfa` | `dd_above_ceiling:dd_pct=21.63:max=15.0` | `50306517-85fc-4d8a-8570-7f217325ea56` | `12fdd389-9f71-4c84-afe7-e5ba67b591cb` | `d3b1aef0507d` | ENQUEUED |
| 3 | A | QM5_10375 | NDX.DWX | Q06 | `d1480910-25bc-4149-943d-5b805a6a00d1` | `dd_above_ceiling:dd_pct=16.31:max=15.0` | — | — | `848034b3f7cb` | SKIPPED |
| 4 | B | QM5_10123 | XTIUSD.DWX | Q06 | `e6b47d08-f426-48f0-8335-4897075671df` | `pf_below_floor:pf=0.980:floor=1.0` | `a54981a1-63cc-4a4f-96fb-98d7151d7a93` | `989d531b-1cd0-4a69-8b25-36e2558bfbbc` | `c8be5bc42bb3` | ENQUEUED |
| 5 | B | QM5_10163 | SP500.DWX | Q06 | `45361455-3b34-46bd-82cf-0242749955a2` | `pf_below_floor:pf=0.960:floor=1.0` | `212b25d9-ff17-4a3b-be23-f5c511c3cf4b` | `95e34cbf-ea1d-42ee-8809-f751cbb0ee80` | `c1c213f35136` | ENQUEUED |
| 6 | B | QM5_10714 | XAUUSD.DWX | Q06 | `d0049c13-0245-4851-b036-ca1d266ea026` | `pf_below_floor:pf=0.990:floor=1.0` | `745242de-f0c6-49ad-9e84-82eb29cab111` | `d71aa23f-e6fb-4a9d-8d21-74034f1d26c1` | `d866fd9cece9` | ENQUEUED |
| 7 | B | QM5_11182 | XAUUSD.DWX | Q06 | `94abd92a-d944-4ce8-99bb-0bd5b92be943` | `pf_below_floor:pf=0.970:floor=1.0` | `92ec7331-d599-481b-9534-13b2e769b4f5` | `2f02e3b1-3f19-46aa-a591-d6607239b981` | `754178661367` | ENQUEUED |
| 8 | B | QM5_1230 | USDJPY.DWX | Q06 | `f115942b-d380-4659-8115-f156177cbbe1` | `pf_below_floor:pf=0.970:floor=1.0` | `f6958041-d442-4870-863e-43b1cffe6e81` | `fd85c31e-c21b-4e92-909d-54bfe1085709` | `52e05c77f94a` | ENQUEUED |
| 9 | B | QM5_12918 | USDCAD.DWX | Q06 | `447968f2-8ed8-4a05-b50a-6e6884746be2` | `pf_below_floor:pf=0.960:floor=1.0` | `1d207268-0af6-4ad9-bd87-e957cb8beb1a` | `213d9660-c5f7-4c13-856d-8a7887c2565a` | `4cbf341ded1a` | ENQUEUED |
| 10 | B | QM5_12991 | AUDCAD.DWX | Q06 | `f58f18d5-857d-4fd1-b343-10725d58f38c` | `pf_below_floor:pf=0.970:floor=1.0` | `7ffd42a1-d07e-49e8-b0d7-de8d1e9e3845` | — | `103671351ab0` | SKIPPED |
| 11 | B | QM5_1537 | XNGUSD.DWX | Q06 | `3e43a75f-323d-46b3-aa4f-6e22769271f6` | `pf_below_floor:pf=0.960:floor=1.0` | `3ad1bb4e-7413-4570-a4e5-cde3927e7790` | `151c88ab-5546-4e23-84ed-672ec8824679` | `142a019e773a` | ENQUEUED |
| 12 | B | QM5_1910 | USDCHF.DWX | Q06 | `e7850da0-09a1-47e1-bd54-b423dfb4fd67` | `pf_below_floor:pf=0.980:floor=1.0` | `2cb7f0f2-529f-4ebb-8a4d-ab036a61cc47` | `34099aa6-1fe4-4b14-b911-dcc1920f8c32` | `2e83d7124c89` | ENQUEUED |
| 13 | B | QM5_20082 | AUDUSD.DWX | Q06 | `dd400099-7183-4f7a-bfa3-5ff166a3a42b` | `pf_below_floor:pf=0.980:floor=1.0` | `46f9c2a3-ae2e-4db0-8186-a7baf72709db` | `26767674-5199-4bca-a83b-9f4da7817c80` | `857220555cd1` | ENQUEUED |
| 14 | B | QM5_9641 | SP500.DWX | Q06 | `544a7e0f-213e-46aa-bb44-4e63b9acb8ac` | `pf_below_floor:pf=0.960:floor=1.0` | `926671a4-1518-46d2-9cec-a589648e4f99` | `091c2385-fc89-41f0-80d7-eda0eceb5dcb` | `21eda8527f66` | ENQUEUED |

EA `.ex5` binding source = canonical EA directory `framework/EAs/<label>/<label>.ex5` (resolved by farmctl `_preferred_ea_dir` → `_expected_current_execution_bindings`, which SHA256s that file and refuses on mismatch / non-canonical directory / missing artifact). Full SHA256 values were passed to `--expected-current-ex5-sha256` and are recorded in each new row's `payload_json.expected_current_ex5_sha256`.

## 4. What was skipped and why (2 of 14 — never recompiled; recompile in active inventory is ROT)

- **QM5_10375 / NDX.DWX (Cohort A, Q06, `d1480910`)** — its Q05 predecessor `e73c9085` was a PASS that promoted this Q06 row on 2026-07-02, but was later requeued and its verdict overwritten to **INFRA_FAIL** on 2026-07-29. The cascade append-only path requires a live Q05 `PASS/PASS_SOFT/PASS_LOWFREQ` predecessor; none exists, so farmctl cannot (and did not) enqueue it. The old FAIL row is untouched. To re-adjudicate this triple, the Q05 INFRA_FAIL must first be re-run to a PASS (separate action, out of this task's scope).
- **QM5_12991 / AUDCAD.DWX (Cohort B, Q06, `f58f18d5`)** — farmctl refused with `current_execution_binding_not_in_canonical_ea_directory`: both the terminal row and its Q05 predecessor are bound to a **worktree** setfile (`C:\QM\worktrees\codex-orchestration-1\framework\EAs\QM5_12991_weiss-rsi-ma-v2\sets\...`), not the canonical `C:\QM\repo\framework\EAs\...`. The binding guard fail-closes on non-canonical execution identity. No canonical-dir predecessor exists for this triple, so no valid re-run could be created. Nothing was recompiled or regenerated.

## 5. Two band rows dropped pre-enqueue for dd ≥ 25 % (per pre-computed live-evidence measurement)

My DB-only re-derivation of Cohort B yields 13 not-already-through triples; the two beyond the 11 candidates are exactly the rows the pre-computed measurement dropped for measured dd ≥ 25 %:

- **QM5_10467 / XAUUSD.DWX** (`83410b07`, `pf_below_floor:pf=0.990:floor=1.0`) — measured dd ≈ 29.4 %.
- **QM5_9639 / USDJPY.DWX** (`cbfa681b`, `pf_below_floor:pf=0.980:floor=1.0`) — measured dd ≈ 28.6 %.

Both stay FAIL under Q06 PASS_SOFT (the band requires dd ≤ 25). Because per-row dd for a `pf_below_floor` row is not durably stored in the DB (and the Q06 `aggregate.json` is overwritten per run), the dd ≥ 25 basis comes from the pre-computed live-evidence read, not from durable DB state. Bounded consequence of a misclassification here: at most 2 harmless re-FAILs (if actually dd < 25 they would have been valid re-runs) — no verdict is overwritten either way.

## 6. Priority action (GRÜN — queue-priority, pre-authorized)

No dedicated farmctl priority subcommand exists; the dispatcher selector `pending_claim_order_sql` (farmctl.py:1057) orders pending rows by `priority_track*10 + phase_rank − age_weeks`. The 12 new rows were raised onto the priority track by setting `payload_json.priority_track = true` (JSON boolean, matching `json_type(...,'$.priority_track')='true'`) plus an audit key `priority_boost_authority` = *"OWNER CEO-MP-#6 2026-08-21 retro re-adjudication; GRUEN queue-priority raise"*, via a targeted `json_set` UPDATE on the 12 pending rows only (2 already carried the flag from their predecessor). Effective ordering score dropped 14/15 → 4/5.

**Verified against the live selector:** the 12 rows occupy the very top of 2,160 pending claimable rows — 11 at positions #2–#12, and QM5_10163/SP500 (`95e34cbf`) was already claimed `active` by worker **T8** on its own dispatch cycle (I launched nothing). They will be served in the current/next window.

## 7. Append-only integrity proof (before/after; ≥3 rows incl. one per cohort)

All 14 historical target rows re-read after the enqueue: **0 changed** (status/verdict/updated_at/reason identical). Sample:

| Old row | EA / Symbol | Cohort | Before | After |
|---------|-------------|--------|--------|-------|
| `dc66cdca-e08f-4918-b054-a757a03769f6` | QM5_10916 / GDAXI.DWX | A | done/FAIL/2026-07-14T12:36:23+00:00 | done/FAIL/2026-07-14T12:36:23+00:00 (unchanged) |
| `d1480910-25bc-4149-943d-5b805a6a00d1` | QM5_10375 / NDX.DWX | A | done/FAIL/2026-07-02T06:04:10+00:00 | done/FAIL/2026-07-02T06:04:10+00:00 (unchanged) |
| `e6b47d08-f426-48f0-8335-4897075671df` | QM5_10123 / XTIUSD.DWX | B | done/FAIL/2026-07-15T01:57:53+00:00 | done/FAIL/2026-07-15T01:57:53+00:00 (unchanged) |
| `544a7e0f-213e-46aa-bb44-4e63b9acb8ac` | QM5_9641 / SP500.DWX | B | done/FAIL/2026-08-11T04:45:37+00:00 | done/FAIL/2026-08-11T04:45:37+00:00 (unchanged) |

Each new row carries `append_only_rerun=true`, `append_only_rerun_of_work_item=<old row>`, `historical_work_item_preserved=true`, `rerun_reason`, and `expected_current_ex5_sha256`; status `pending`, verdict `NULL`.

## 8. Expected outcomes (a re-run is a fresh measurement and may land elsewhere)

- **Cohort A (3 candidates, 2 enqueued):** PASS if the fresh dd_pct ≤ 25 (Q05), or PASS / PASS_SOFT (Q06, depending on PF) — the historical dd was 15.1 / 21.6 / 16.3 %.
- **Cohort B (11 candidates, 10 enqueued):** PASS_SOFT if fresh DD < 25 % and trades ≥ 20 with PF still in [0.95, 1.00); full PASS if PF recovers ≥ 1.00; FAIL if PF drops below 0.95 or DD ≥ 25 %.

## 9. Summary

14 candidates independently confirmed (= pre-computed set). **12 enqueued** append-only with SHA binding + audit reason; **2 skipped** (QM5_10375/NDX no live Q05 PASS predecessor; QM5_12991/AUDCAD worktree-bound setfile refused by farmctl) — neither recompiled. All 12 raised to the top of the queue. All 14 historical rows verified unchanged.

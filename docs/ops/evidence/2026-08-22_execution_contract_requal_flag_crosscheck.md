# EXECUTION_CONTRACT self-flag cross-check vs DL-089 requal cohort — 2026-08-22

Router task `8e334e3b-4d2b-4705-a32c-77b0e8e929b8` (claude). **READ-ONLY** against
T_Live — no live binary, chart, setfile, or AutoTrading state was touched. This is a
cross-reference, not a requalification decision; the requal decision per live EA
remains **OWNER's**.

## Question

`docs/ops/evidence/2026-08-22_tlive_ea_warn_classification.md` Finding 2: 7 live EAs
self-declare `"declaration":"DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED"` in their
`EXECUTION_CONTRACT` log payload: `10911, 10919, 10939, 11132, 11421, 12567, 12989`.
Are these already covered by an open requal item, or does any of them need a new one
created?

## Method

- `framework/registry/owner_priority_tracks.json` (22 entries) checked for each of the
  7 EA ids — this is the authoritative priority-track registry that DL-089 Wave 1 batch
  1 confirmed all 21 cohort EAs were entered into.
- `decisions/DL-089_live_book_full_chain_requalification.md` (ADOPTED 2026-08-21) read
  for cohort scope and wave sequencing.
- `docs/ops/evidence/2026-08-21_dl089_wave1_batch1.md` and
  `2026-08-21_dl089_wave1_batch2_partial.md` read for per-EA rebuild progress.
- `D:/QM/strategy_farm/state/farm_state.sqlite` `work_items` table queried directly for
  each EA's most recent Q02/Q08/etc. rows, to date evidence against the DL-089 decision
  timestamp (2026-08-21) and distinguish pre-DL-089 (old binary) evidence from
  post-DL-089 (rebuilt binary) evidence.
- `docs/ops/evidence/2026-08-21_compile_ea_pipeline_251b9724.md` and its candidate CSV
  (`2026-08-21_compile_ea_verified_candidates_251b9724.csv`, 82 rows) checked for
  whether the "unblock" mechanism named in `b2bf2460`'s close-verdict actually contains
  the 6 still-pending EAs.
- Live `.ex5` file mtimes on disk checked for the 6 pending EAs to confirm no rebuild
  has landed since batch 2 stalled.

## Result: all 7 are covered — none needs a new requal item

Every one of the 7 self-flagging EAs is already a member of the DL-089 Wave 1
cohort (`owner_reference: OWNER_DECISION_2026-08-21_DL-089_LIVE_BOOK_REQUALIFICATION`
in `owner_priority_tracks.json`). The `EXECUTION_CONTRACT` self-flag and the DL-089
cohort are naming the same 7 EAs' underlying condition (legacy-book, pre-optimization
live binary) — there is no gap between "flagged" and "tracked."

| EA | Flag source | DL-089 requal status | Missing item |
|---|---|---|---|
| `QM5_10911` | `EXECUTION_CONTRACT` self-declaration | **Wave 1 batch 1 DONE** — rebuilt 2026-08-21, strict build review PASS (1 non-blocking DWX advisory), fresh Q02 `PASS` on the rebuilt binary (`096636c3`, 2026-08-21T17:24:09Z). Q03–Q10 remain, normal progression. | None — in flight through the chain. |
| `QM5_10919` | `EXECUTION_CONTRACT` self-declaration | **Wave 1 batch 2, STALLED.** `.ex5` still dated 2026-08-05 (unrebuilt). Attempted first in batch 2 (`b2bf2460`): `compile_ea.py --ea-id 10919 --force` hit a 120s `compile_one.ps1` timeout, no binary produced. Close-verdict named `COMPILE_EA` (`251b9724`) as the unblock path. | **A live gap, not a missing item**: `251b9724` shipped 2026-08-21 20:05:48Z and enqueued 82 `COMPILE_EA` candidates, but its classifier requires "`.mq5` present AND `.ex5` **absent**" — 10919 already has an `.ex5`, so it was never eligible for that queue (confirmed: 0/82 candidate rows match any of the 16 remaining Wave-1 EAs). No new work item has run against 10919 since the `b2bf2460` timeout. |
| `QM5_10939` | `EXECUTION_CONTRACT` self-declaration | **Wave 1 batch 2, not yet attempted.** `.ex5` still dated 2026-08-05. Listed in the 16-EA batch-2 remainder; batch 2 stalled on the first name (10919) before reaching this one. | Same gap as above — no compile mechanism currently routes to it. |
| `QM5_11132` | `EXECUTION_CONTRACT` self-declaration | **Wave 1 batch 2, not yet attempted.** `.ex5` still dated 2026-08-05. | Same gap as above. |
| `QM5_11421` | `EXECUTION_CONTRACT` self-declaration | **Wave 1 batch 2, not yet attempted.** `.ex5` still dated 2026-08-05. | Same gap as above. |
| `QM5_12567` | `EXECUTION_CONTRACT` self-declaration | **Wave 1 batch 2, not yet attempted.** `.ex5` still dated 2026-08-05. | Same gap as above. |
| `QM5_12989` | `EXECUTION_CONTRACT` self-declaration | **Wave 1 batch 2, not yet attempted.** `.ex5` still dated 2026-08-05. | Same gap as above. |

All pre-2026-08-21 Q02/Q04/Q07/Q08/Q09_NEWS rows found for the 6 pending EAs are
evidence against the **old** (pre-DL-089) binary and do not satisfy DL-089's
full-chain requirement — consistent with the decision's own framing ("an EA without
the complete chain is not book-eligible, regardless of how long it has already
traded").

## The one open item worth OWNER attention

This is a **mechanism gap**, not a missing decision: DL-089 already authorizes and
tracks all 7 (all 21) EAs; nobody needs a new requal item opened. But the specific
unblock path chosen for `b2bf2460`'s BLOCKED closure — routing the 16 remaining Wave-1
EAs through the new `COMPILE_EA` phase — does not actually reach them, because that
phase's candidate classifier only picks up EAs with **no existing `.ex5`**, and every
DL-089 EA (by definition, it is live-deployed) already has one. The 6 pending EAs here
are representative of all 16 remaining Wave-1 EAs having the same block. Forward
progress on DL-089 Wave 1 batch 2 has therefore been at 5/21 since 2026-08-21, with no
individual work item open against any of the 16 remaining names as of this check
(2026-08-22T07:xx UTC).

Recommended next step (not actioned here — read-only pass): either (a) extend the
`COMPILE_EA` classifier with an explicit force-rebuild list for the named DL-089
Wave-1 remainder (bypassing the "no existing `.ex5`" filter, since overwriting is the
entire point of a requalification rebuild), or (b) diagnose why `compile_one.ps1`
timed out at 120s on a live-factory compile and raise/retry that path specifically for
this named cohort. Both are Codex-shaped build/ops work, not something this read-only
pass performs.

## Guardrails observed

No T_Live binary, chart, setfile, AutoTrading state, terminal process, or active
backtest was read, touched, or referenced beyond the already-published
`EXECUTION_CONTRACT` log lines cited in Finding 2. No pipeline verdict was inferred or
created. No requalification decision was made — DL-089 remains the sole authority, and
OWNER remains the decision-maker for any live-book consequence.

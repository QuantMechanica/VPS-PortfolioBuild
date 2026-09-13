# OOS-2026 confirmation campaign — append-only window re-enqueue (2026-09-13)

Prepared by the pipeline lane (dry-run only), applied by the orchestrator
2026-09-13T21:06:00Z. See `## Applied` below for the result and receipt.

## What this fixes

`oos_2026_confirmation_v1` (campaign_id `oos-2026-confirmation-v1`, 55 Q09_NEWS
diagnostic rows, enqueued 2026-09-02) declared the measurement window
**2026-01-01..2026-04-06** but its rows carried **no** `from_date`/`to_date`, so
farmctl's spawn builder fell back to `DEFAULT_RUN_SMOKE_YEAR` 2024
(`_basket_payload_date_window` returns `None` for single symbols). The 15 rows
that ran measured **2024**; the 40 pending rows were contained under holds:

| rows | hold | disposition here |
|-----:|------|------------------|
| 37 | `OOS_WINDOW_MISMATCH` | patch 2026 window into payload + release hold (this task) |
| 3 | `NEWS_CALENDAR_TAINTED` | untouched (window already correct, calendar hold) — out of scope |
| 15 (done) | — (verdict `REVIEW_REQUIRED`, measured 2024) | append-only successor + supersede edge |

Dispatcher repair landed today in `bb3bed68c3` (lane derivation +
`report-misphased-rows`; farmctl `news_lane_mismatch` spawn refusal). The window
repair itself is the module's governed `repair-oos-window` subcommand.

## Window binding (how the 2026 window is set)

Via the **campaign contract**, not a setfile and not a per-row
`farmctl enqueue-backtest --target-setfile`. `repair-oos-window` reads
`campaign_plan.json` (`full_from_utc`/`full_to_utc`), writes
`from_date/to_date/window_from_utc/window_to_utc` into each payload, and stamps
`q09_dispatch_binding_sha256` plus the `campaign_plan_sha256`
(`6ade6b3491dabe74773abc2bfb31d597f48db78f01ece41759667b9b5088dfad`) that the
spawn builder re-verifies. A plain `enqueue-backtest --append-only-rerun-of`
would **reproduce the 2024 fallback** for these single-symbol NEWS rows, so it is
the wrong tool here.

## Procedure (governed, all inside `repair-oos-window`)

1. **Verify (read-only):** `report-misphased-rows` -> `misphased_rows.json`
   (40 rows, all on `Q09_NEWS`); `repair-oos-window` dry-run -> counts
   `pending_to_patch=37, holds_to_release=37, done_to_succeed=15, unchanged=3`.
2. **Apply (`--apply`):** one FactoryMutationLock transaction — pre-mutation state
   backup minted first; unclaimed pending rows patched by primary key with a
   CAS on `(status='pending', claimed_by IS NULL, payload_json)`; holds released
   via CAS on `(hold_code, active=1)` with append-only ledger + event rows
   (`work_items.status` never changes); 15 successors inserted with deterministic
   uuid5 ids + `work_item_supersedes` edges; receipt written atomically only
   after commit. Re-running mints nothing new (deterministic ids, idempotent).
   - Pending rows have **no verdict** (never ran) — patching the unclaimed
     payload in place is the append-only-equivalent re-enqueue (GRUEN: re-enqueue
     rows without a verdict). Done rows have evidence, so they get append-only
     successors, never a mutation.

## The 15 done rows need NO separate retire2 disposition

Their wrong-lane/2024 evidence was **already adjudicated `INVALID_EVIDENCE`**
(`RUN_SMOKE_EVIDENCE_NOT_Q09_NEWS_EXPERIMENT`) by the q09-news-review-lane-closure
on **2026-09-13T16:01Z** — append-only `kind=disposition` ADJUDICATION_RECEIPT
rows + supersede edges (`source_encoding=orchestrator:q09-news-review-lane-closure/v1`),
verified in the DB. `repair-oos-window` adds the corrected 2026-window **reruns**
with its own edge (`source_encoding=repair:oos-2026-window/v1`); the two edges
coexist and are complementary. Running `apply_q09_retire2_dispositions.py` here
would **duplicate** the already-recorded INVALID_EVIDENCE adjudication — do not.

## Blockers — the window repair is necessary but NOT sufficient

1. **`NEWS_LANE_MISMATCH` (hard blocker to execution).** All 37 patched rows and
   the 15 minted successors keep `phase=Q09_NEWS` (the successor inherits the
   source phase). The active NEWS lane is **`Q10_NEWS`**; the NEWS runner binds
   `Q10_NEWS` only. `farmctl._news_lane_spawn_refusal` returns
   `pending_runner / news_lane_mismatch` for any `Q09_NEWS` row and refuses to
   run it (correctly never as `run_smoke`). **=> After the hold is released the
   cohort still cannot execute.** A separate `Q09_NEWS -> Q10_NEWS` lane
   migration is required; `report-misphased-rows` (`misphased_rows.json`) is the
   read-only surface for that disposition. This is a follow-on orchestrator
   ticket, not part of the window re-enqueue.

2. **`NEWS_CALENDAR_TIMESTAMP_DEFECT` (containment interplay).** Standing rule
   (OPEN_ITEMS 2026-09-05): every dispatch tick holds **new** `Q09_NEWS`/
   `Q10_NEWS` rows with `NEWS_CALENDAR_TIMESTAMP_DEFECT` until **E1** (the
   tester-branch DST calendar repair, `QM_NewsFilter.mqh:2022`). As of
   2026-09-13 the defect is still contained (12 active `Q10_NEWS` timestamp-defect
   holds; risk freeze ACTIVE). So even a correctly-windowed, correctly-laned row
   would be re-held under `NEWS_CALENDAR_TIMESTAMP_DEFECT` until E1 lands. The
   live path is unaffected (native MT5 calendar, DL-080).

**Net:** applying the window repair now is safe and correct (it clears the window
defect and releases only `OOS_WINDOW_MISMATCH`), but it will not by itself yield
2026 measurements. The cohort remains gated on (1) the lane migration and (2) E1.

## Files

- `misphased_rows.json` — `report-misphased-rows` output (read-only; 40 rows).
- `plan.json` — per-row plan: 37 pending patches, 15 done successors, 3 tainted
  (out of scope), window binding, downstream blockers, done-row disposition
  finding, and the verified dry-run counts.
- `apply_oos_2026_reenqueue_0913.py` lives in `tools/strategy_farm/session_tools/`.

## The single apply command (orchestrator runs this)

```powershell
cd C:/QM/repo
# dry-run (default, read-only):
python -X utf8 tools/strategy_farm/session_tools/apply_oos_2026_reenqueue_0913.py
# apply:
python -X utf8 tools/strategy_farm/session_tools/apply_oos_2026_reenqueue_0913.py --apply
```

Equivalent native command:

```powershell
python -X utf8 -m tools.strategy_farm.oos_2026_confirmation repair-oos-window --apply \
  --out docs/ops/evidence/2026-09-13_oos_2026_reenqueue/repair_receipt.json
```

Scope to named rows with repeated `--work-item-id <id>` (fail-closed). The apply
path refuses to overwrite an existing receipt.

## Applied (2026-09-13T21:06:00Z)

Ran `apply_oos_2026_reenqueue_0913.py --apply`: 37 pending rows patched to the
2026 window, 37 `OOS_WINDOW_MISMATCH` holds released, 15 append-only successors
minted for the `done`/`REVIEW_REQUIRED` rows, 3 tainted rows left unchanged.
Receipt: `repair_receipt.json`. Pre-mutation state backup:
`D:\QM\strategy_farm\state\backups\farm_state_before_oos_window_repair_20260913T210627Z_cbd641af.sqlite`
(sha256 `58764cfad4a8dde3c38ddcc61c4b348fc0d78ae54236c21cf33b133fdc22d534`).
Verified one minted successor (`8eea2250-4958-5f1c-9a6b-0670091dcc17`) carries
`from_date=2026.01.01 to_date=2026.04.06 window_from_utc=2026-01-01T00:00:00Z
window_to_utc=2026-04-06T23:59:59Z`.

**Acceptance gap (documented, not a defect of this apply):** "first successor
run's tester.ini shows the 2026 window" cannot be observed yet — every patched/
minted row still carries `phase=Q09_NEWS`, and the active NEWS runner binds only
`Q10_NEWS` (`farmctl._news_lane_spawn_refusal` → `news_lane_mismatch`), so none
of these 52 rows can be claimed by a terminal worker until the
`Q09_NEWS -> Q10_NEWS` lane migration lands. Even after that migration, standing
containment re-holds new `Q09_NEWS`/`Q10_NEWS` rows under
`NEWS_CALENDAR_TIMESTAMP_DEFECT` until E1 (tester-branch DST calendar repair)
lands. This ticket's scope (window correctness) is done; the lane migration and
E1 are separate, already-tracked blockers — not re-opened here.

# RECEIPT — OWNER-DEC-REQUEUE-LIFT-20260916 (both parts)

Operator: `kimi-interim` · Date (UTC): 2026-09-16 · Repo: `C:\QM\repo`

## D2A — QM5_11561 — EXECUTED

| Step | Result |
|---|---|
| Exclusion lift | `c08d677e…f84a` → `3f092f0a…f3f3` (only the `QM5_11561` line removed; backup `requeue_excluded_eas.txt.before_D2A_lift`, hash-bound) |
| Enqueue | `enqueued: true`; task `3262b0b1-86f4-4edb-aed8-30bb2ba77584`; work item **`132aca67-b907-4d34-a232-cf972de4fb32`** (USDJPY.DWX D1) |
| Claim | Worker **T8** claimed 3 s after enqueue; worker PID **10960**, tester child PID **21040** |
| Terminal outcome | Q02 **done/PASS** at 06:32:47Z — Model 4 (Every Real Tick), 1 run exit 0, deterministic; evidence `D:\QM\reports\work_items\132aca67-…\summary.json`; recorded economics net −31 256 / PF 0.86 (economic gates come later) |
| History | Zero prior work items; no verdict rewritten |
| Fanout decision | n/a (single-symbol EA; one work item) |
| STOP | none |

## D2B — QM5_11731 — STOP, NO STATE CHANGE

- Exclusion **not** lifted (file hash unchanged at D2A after-hash; `QM5_11731` line intact).
- Nothing enqueued; no factory DB writes.
- Cause: no legitimate single-symbol Q02 scope exists in the tool for this EA's state —
  `--target-symbol` is universe-expansion-only (needs a native Q02 PASS parent);
  `intake-first-q02` (the governed EURUSD canary path) needs a done/`COMPILE_OK`
  `COMPILE_EA` work item that does not exist; the canonical review enqueue would
  fan out all 4 symbols, violating the pilot condition.
- Unblock options documented in `QM5_11731_receipt.md` (compile→intake canary, or OWNER-
  ratified scoped enqueue). Pilot verification (a–e) and fanout were therefore not reached.

## Files

- `QM5_11561_receipt.md` — D2A detail
- `QM5_11731_receipt.md` — D2B STOP detail with code references
- `d2a_lift_hashes.json` — machine-readable lift record
- `d2a_enqueue_result.json` — raw enqueue output
- `requeue_excluded_eas.txt.before_D2A_lift` — backup of prior exclusion-file bytes

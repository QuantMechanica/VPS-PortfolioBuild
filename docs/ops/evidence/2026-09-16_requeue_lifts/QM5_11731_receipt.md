# Receipt — OWNER-DEC-REQUEUE-LIFT-20260916 / D2B — QM5_11731 (EURUSD M5 pilot)

- Owner decision id: `OWNER-DEC-REQUEUE-LIFT-20260916` (D2B, APPROVED WITH CONDITIONS:
  EURUSD.DWX M5 pilot first, fan out only on a clean pilot)
- Operator: `kimi-interim`
- EA: `QM5_11731` (slug `QM5_11731_tc-m5-s20-ema3-bb-macd`; 4-symbol card universe
  EURUSD/GBPUSD/USDCHF/USDJPY .DWX, all M5)
- Date (UTC): 2026-09-16
- **Outcome: STOP before any state change — no legitimate single-symbol Q02 scope exists
  in the tool for this EA's current state. The exclusion was NOT lifted and nothing was
  enqueued.**

## Hash chain note

D2A modified the exclusion file first. Had D2B proceeded, its before-hash would have
been the D2A after-hash `3f092f0a5029f483da2d25086245ecb53ebe1be79c28245b0451d93b6c45f3f3`.
Because D2B stopped before editing, the live file remains at exactly that hash and the
`QM5_11731` line is still present (grep count 1, verified). Exclusion-state continuity
is preserved; the pump skips this EA (`_detect_unenqueued_eas` → `is_q02_requeue_excluded`,
farmctl.py:18415), so no auto-fanout can occur.

## Why each tool path was rejected (code read, farmctl.py)

1. **`enqueue-backtest --target-symbol EURUSD.DWX`** — CLI routes any `--target-symbol`
   to `enqueue_universe_expansion_q02` (farmctl.py:38819-38854). That path is for
   appending one NEW symbol to an EA that already has a native Q02 PASS: it requires
   `native_pass_work_item_id` naming a done/PASS Q02 work item (farmctl.py:26603-26616)
   and `owner_decision == UNIVERSE_EXPANSION_OWNER_DECISION` (farmctl.py:26437), and it
   refuses any (EA, symbol) with a historical work item (farmctl.py:26617-26632).
   QM5_11731 has **zero** work items → would refuse `native_q02_pass_parent_invalid`.
   It is not a narrowing scope.
2. **`intake-first-q02`** — the governed first-Q02 canary mechanism
   (`qm-q02-canary-fanout/v1`, stage-1 max 1 symbol, farmctl.py:34895-34896; EURUSD.DWX
   is rank-0 canary pick per `Q02_CANARY_SYMBOL_PRIORITY`, farmctl.py:34926-34936).
   This is the mechanism that would have satisfied the pilot condition, BUT it requires
   a done/`COMPILE_OK` `COMPILE_EA` work item (`_plan_first_q02_intake`,
   farmctl.py:35582-35590). The DB has **no work item of any kind** for QM5_11731
   (verified by ea_id and payload word-boundary searches) → would refuse
   `compile_work_item_not_found`.
3. **Canonical `enqueue-backtest --review-task-id cbb536e7-f6d3-4542-9254-11e9ca2bbcb7`**
   (review task verified: ea_review/done/APPROVE_FOR_BACKTEST) — fans out per setfile to
   ALL 4 card symbols (`_create_backtest_work_items`, farmctl.py:26248+; all 4 setfiles
   and all 4 active magic rows exist). No symbol filter exists on the review path
   (`surviving_symbols` narrowing is P3+ only). Enqueueing would create 4 pending Q02
   rows, violating the EURUSD-pilot-first condition.
4. **`seed-fresh-q02` / `requalify-q02` / `rebind-q02`** — all require pre-existing Q02
   work-item rows; none exist.

Per the decision's explicit stop rule ("If no legitimate single-symbol scope exists in
the tool, STOP and report rather than improvising"), no rows were hand-created, no
enqueue-wide-then-cancel was attempted, and the exclusion lift was withheld.

## Precondition status (for the record)

- Q01 smoke: latest build_ea `1a17f439-…` (2026-08-04) `smoke_result: "passed"` — the
  smoke gate would be satisfiable at enqueue time.
- Card + registry: approved card present; 4 active magic rows (slots 0-3);
  4 canonical M5 setfiles on disk; EA dir has exactly one .ex5.

## Recommended unblock paths (require OWNER direction; not executed)

- **(a)** `enqueue-compile --ea QM5_11731 --apply` to mint the missing done/`COMPILE_OK`
  `COMPILE_EA` work item via the normal compile lane, then
  `intake-first-q02 --compile-work-item-id <id> --apply` → governed EURUSD.DWX-only
  canary with GBPUSD/USDCHF/USDJPY deferred under `q02_deferred_symbols.json`.
- **(b)** OWNER ratifies a new scoped-enqueue variant (code change) or an alternate
  pilot mechanism.

No factory DB writes were made for D2B. No retry is pending — this is a parked STOP,
not a failure of the EA.

# QM5_10369 (et-magnet-limits) / GDAXI.DWX + NDX.DWX — OnInit root-cause dig

Task: `4216dd75-6430-4ccb-b545-6c6cf6f3fd4b`. Never requeued; no verdict touched.

**SP500.DWX is out of scope here**: `work_items` shows its most recent row
(`f262acc0-ca1a-5bfd-91cf-a4e5d167ed4f`, 2026-08-30) already carries verdict `RETIRE` via
`docs/ops/evidence/2026-08-30_ffc5a16d_q02_split_fix.md` — resolved outside this ticket.
Only GDAXI and NDX are still stranded `INFRA_FAIL`.

## Evidence used (real MT5, REAL_TICKS; no fresh run spawned this cycle)

| Symbol | work_item | evidence_path | ex5_sha256 |
|---|---|---|---|
| GDAXI.DWX | `89875e78-1233-4476-b6b2-46bafcdf6e7d` (2026-09-15 16:43Z) | `D:\QM\reports\work_items\89875e78-...\QM5_10369\20260915_164309\summary.json` | `e954e88b1e6d01b04422bd3f96bb8242f58eca7c3b362aebd0f8f280485e72a1` |
| NDX.DWX | `446e60ca-e0fb-4084-975f-974fc76f5bee` (2026-09-15 13:26Z) | `D:\QM\reports\work_items\446e60ca-...\QM5_10369\20260915_132616\summary.json` | `e954e88b1e6d01b04422bd3f96bb8242f58eca7c3b362aebd0f8f280485e72a1` |

Same `ex5_sha256` for both symbols, and identical to the `NDX.DWX` attempt from
2026-08-08 (`3e5fabab-...`) — a stable build across weeks and both symbols.

`oninit_failure_detected: true` on both. Decisive tester-log lines (raw journals already
purged; these are the durable `tester_log_decisive_lines` from `summary.json`):

```
GDAXI: CS  2  18:43:21.812  Tester  tester stopped because OnInit reports incorrect input parameters
NDX:   CS  2  15:26:29.883  Tester  tester stopped because OnInit reports incorrect input parameters
```

## What this line means — and why it differs from QM5_12582/QM5_10505

This is the **`...incorrect input parameters`** wording, not `...returns non-zero code 1`
(compare `oninit_QM5_12582.md`, `oninit_QM5_10505.md`). `QM5_10369_et-magnet-limits.mq5`'s
`OnInit()` contains exactly one branch: `if(!QM_FrameworkInit(...)) return INIT_FAILED;` — the
EA source can only ever return `INIT_SUCCEEDED` (0) or `INIT_FAILED` (1); it never returns
`INIT_PARAMETERS_INCORRECT` (2) explicitly, and neither does `QM_FrameworkInit`'s call chain
(every internal rejection in `QM_Common.mqh` is a plain `return false`, converted by the EA to
`INIT_FAILED`). MT5 showing the `incorrect input parameters` wording anyway, for a return path
that cannot itself signal that code, is the strongest available signal that **`OnInit()` was
never actually called this run** — the tester's own `.set`-to-`.ex5` parameter binder rejected
before entering EA code. That is consistent with a second, independent observation:

The worker-level log for the GDAXI run
(`D:\QM\strategy_farm\logs\work_item_89875e78-1233-4476-b6b2-46bafcdf6e7d.log`, still on disk)
records: `WARNING: Structured logger capture skipped: expected exactly one growing logger
file, found 0.` `QM_LoggerInit(...)` is the **first statement** executed inside
`QM_FrameworkInitCoreAfterRuntimeStateArmed` — before any of its five validation branches.
Zero logger files means that function body never ran at all, i.e. the rejection happened
above it, either in the outer `QM_FrameworkInit` wrapper's
`QM_RuntimeExecutionBeginLegacyInitialization()` gate, or — more likely given the message
wording — before `OnInit()` was invoked by the tester at all.

## Checked, not assumed — ruled out statically

- **Not a source-level hard input pin**: `grep -n "QM_InputRequire" QM5_10369_et-magnet-limits.mq5`
  → 0 hits.
- **Not a missing/mismatched magic registry row**: `framework/registry/magic_numbers.csv` has
  `10369,et-magnet-limits,3,GDAXI.DWX,103690003,...,active` and
  `10369,et-magnet-limits,1,NDX.DWX,103690001,...,active`, matching the two set files'
  `qm_magic_slot_offset` values exactly.
- **Not an orphaned `.set` key**: every key in both
  `sets/QM5_10369_et-magnet-limits_{GDAXI,NDX}.DWX_M1_backtest.set` corresponds to a
  currently-declared `input` in the current `.mq5` (checked by diff against
  `grep -n "^input" QM5_10369_et-magnet-limits.mq5`) — unlike QM5_10505 (see
  `oninit_QM5_10505.md`), there is no stale-filter-library residue here.
- **Not a source/ex5 build-drift flip mid-window**: `mq5` last edited 2026-06-16
  (`ee85fac1607c34c55eb7162ff8a28ff135af99e1283ccb8f7ed1817e8e3da8c9`), `ex5` last compiled
  2026-07-14 — newer than the last source edit, and unchanged (`sha256` stable) across every
  attempt since 2026-08-08.
- **Not an `ENUM_TIMEFRAMES` set-file literal defect**: `strategy_timeframe=PERIOD_M1` (symbolic
  form) is the same convention already used successfully elsewhere in the repo (e.g.
  `QM5_10126_carver-sma`'s `PERIOD_D1` sets), so it is not inherently rejected by MT5's `.set`
  parser.

## Not yet determined

The precise tester-side rejection reason (which `.set` key/value MT5's parameter binder
actually objects to) cannot be read from any surviving artifact — the raw UTF-16 journal that
would show it is already purged, and no logger sample exists because (per the above) the
rejection happened before the EA's own logger ever armed.

## No fresh reproduction this cycle — why

Same infra constraint as `QM5_12582`/`QM5_10505`: GDAXI.DWX and NDX.DWX are Custom-history
symbols; T11/T12 (the only terminals outside the automated T1–T10 claim fleet) do not carry
their privatized `Bases\Custom` data, and this headless `SYSTEM`-identity session cannot use
`DEV1`/`DEV2`. See `oninit_rootcause_4216dd75.md` for the full reasoning, including why
`farmctl reserve-terminal` on a live T1–T10 slot would not actually be safe (the reservation
is bookkeeping only — `terminal_reservation()` is never consulted by the automated claim
loop in `farmctl.py`, so it does not stop a worker daemon from starting its own `terminal64.exe`
on the same slot concurrently).

## Classification

**Disposition: `UNRESOLVED_REQUIRES_INSTRUMENTED_REBUILD`** — same as QM5_12582, but with the
added, more specific hypothesis that this pair fails at the tester's `.set`/`.ex5` binding step
rather than inside `OnInit()` itself. Confirming that requires either (a) a fresh run captured
before the 2h log purge with the raw journal preserved on purpose, or (b) MetaEditor-side
inspection of the compiled `.ex5`'s actual input signature versus the `.set` file, neither of
which is available from this session. **No requeue performed.**

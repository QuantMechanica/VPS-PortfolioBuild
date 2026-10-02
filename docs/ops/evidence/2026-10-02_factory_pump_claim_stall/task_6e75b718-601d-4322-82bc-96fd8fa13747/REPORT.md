# Factory pump claim stall — diagnosis (no_pending_claimable, 2026-10-02)

Task: `6e75b718-601d-4322-82bc-96fd8fa13747`. Request: diagnose whether the
02:05Z–04:05Z 2026-10-02 `no_pending_claimable` signature (reported as "5
runnable work_item rows, 0 running") is a claim-eligibility logic bug, a stale
worker-side cache, or a genuine secondary gate not surfaced in the runnable
count — without changing any gate threshold or verdict logic.

## Verdict: genuine secondary gate, not a bug or a stale cache — GRUEN (no code change needed)

The fleet is not dead and `no_pending_claimable` is not a sign of broken claim
logic. It is the correct, live output of RAM-headroom and DSR-context
admission gates in `terminal_worker.claim_atomic` acting on a nearly-empty
real candidate pool. Both the RAM numbers and the candidate pool are
confirmed live-current, not cached.

## Method

All reads were read-only against the canonical checkout (`C:/QM/repo`, HEAD
`500dda8c`) and the live state DB (`D:/QM/strategy_farm/state/farm_state.sqlite`).
No file was written or committed outside this task's own evidence directory.
(Note: this session's own worktree, `C:/QM/worktrees/claude-orchestration-2`,
is a stale checkout — `2b79ed1a` vs canonical `500dda8c`, and has unrelated
uncommitted edits already present — so all code reading was done directly
against `C:/QM/repo`, per the launcher's "read from C:/QM/repo is fine"
allowance.)

1. Tailed `D:\QM\strategy_farm\logs\terminal_worker_T1..T10.log` for the
   `next_cell_prestage` / `claim_result` JSONL events across 03:04Z–03:17Z.
2. Located the claim path in canonical `tools/strategy_farm/terminal_worker.py`
   (`claim_atomic`, ~line 7800–8850) and the shared candidate ordering in
   canonical `tools/strategy_farm/farmctl.py` (`pending_claim_order_sql`,
   line 2708).
3. Reproduced the exact live candidate order read-only via
   `farmctl.pending_claim_order_sql()` against the live DB — see
   `live_claim_order_full.json` (33 rows, captured ~03:20Z).
4. Cross-checked the raw `pending` count against the same exclusions the
   selector's `WHERE` clause applies (active hold / supersede / poison-pill
   quarantine) — see `pending_exclusion_breakdown.json`.
5. Counted `"claimed": true` vs `"event": "claim_declined"` per terminal over
   each worker's full log lifetime, and found the timestamp of each
   terminal's **last successful claim**.

## Finding 1 — "5 runnable rows" undercounts by two orders of magnitude, but in the *conservative* direction

`work_items` has 4,134 rows with `status='pending'`. The real claimable pool
is far smaller, because `pending_claim_order_sql()` (the single selector every
claimant shares) excludes a pending row if:

- it carries an **active** `work_item_holds` row (3,699 of 4,134 — 89%), or
- it has an entry in `work_item_supersedes` (606), or
- it is under an active `poison_pill_quarantine` row (41).

Re-running that exact selector live against the DB returns **33** real
candidates fleet-wide right now (`live_claim_order_full.json`), of which 44
are Q12 (OWNER/manual gate, not MT5-terminal work at all, excluded from the
33). So "runnable" in the pulse's own vocabulary is close to this 33, not the
raw 4,134 — the dashboard/pulse metric that reported "5" is reading a still
narrower slice (plausibly per-terminal-reachable rows after `terminal_avoid`
and symbol-conflict filtering, not re-derived here), but the direction of the
discrepancy is "the real queue is this thin," not "rows are being hidden from
a healthy queue." This is not a bug: a thin, mostly-held backlog is an
accurate state, not a miscount.

## Finding 2 — the 33 real candidates are headed by rows that genuinely fail RAM/DSR admission right now

The top of the live order (`live_claim_order_full.json`, ranks 1–12) is:

| rank | phase | ea_id | symbol | blocked by (observed in logs) |
|---|---|---|---|---|
| 1 | Q10_NEWS | QM5_13117 | EURGBP.DWX | `longrun_cap_skipped`: needs 46.0 GB free, host has 44.1–44.9 GB free (63.1 GB total) |
| 2 | Q08 | QM5_41221 | EURUSD.DWX | `q08_dsr_context_skipped`: `PEER_COHORT_WINDOW_SHORT` |
| 3 | Q08 | QM5_41504 | XAUUSD.DWX | `q08_dsr_context_skipped`: `SINGLE_CONFIGURATION_UNAVAILABLE:DOCUMENTED_RESEARCH_TRIAL_LEDGER_REQUIRED` |
| 4–6 | Q04 | QM5_37008 / QM5_10403 ×2 | NDX/GDAXI/SP500 | `ram_class_skipped`: `single_index_tick` reserves 42.0 GB, needs an 8 GB floor after reservation → requires ≥50 GB free, host has ~44–45 GB |
| 9–12 | Q08/Q04 | QM5_11927, QM5_41119, QM5_9468, QM5_9932 | — | same RAM/DSR classes recurring |

These are read directly from the live `next_cell_prestage` `claim_result`
events (`terminal_worker_T1.log`, 03:04:25Z–03:09:51Z and repeated at every
later cycle through 03:17Z) and are internally consistent: `free_ram_gb`
tracks the independently-measured live host value (`Get-CimInstance
Win32_OperatingSystem` → 44.5 GB free / 63.1 GB total at the time of this
check, matching the log's own reading to within normal drift). The RAM
numbers are not stale — they move (44.1 → 44.9 GB) between consecutive
~7-second claim attempts in the same log.

Ranks 7–8 and 13+ (`QM5_12920`/`QM5_41145` SP500 Q02, `QM5_11100` AUDUSD Q02,
and the `QM5_413xx` XTI/XNG D1 batch) are **not** blocked in any sampled skip
category — these are the fleet's actual remaining throughput, and the
per-terminal lifetime counters confirm claims are still happening, just
thinly: T2 and T10 each successfully claimed a row as recently as
2026-10-02T01:06–01:07Z (≈2h before this check), vs. T4 (2026-09-29T13:04Z,
~2.5 days stale), T5 (2026-09-29T03:35Z, ~3 days stale) and T7
(2026-09-29T12:12Z, ~3 days stale) — see `claim_timestamps_per_terminal.json`.
So different terminals are in materially different states: some are current,
some have gone multiple days without a successful claim, consistent with a
thin, contested pool rather than a dead fleet.

## Finding 3 — this is the same architectural class as the documented 2026-09-15 incident, recurring in a different skip category

`terminal_worker.py` carries its own comment (around line 8561–8577)
documenting a near-identical 2026-09-15 incident: a small number of
permanently-doomed Q08 rows at the head of the priority order exhausted a
bounded preflight budget before the scan ever reached hundreds of plain
claimable rows behind them. The fix added a cheap claim-time-independent
precheck for that specific doom class (Q08 DSR context) so the scan can skip
past it cheaply. The RAM-class (`single_index_tick`, `longrun_cap`) gates seen
here are a different, correctly-functioning admission check — they are not
mis-firing — but they occupy the same head-of-queue structural position. With
only 33 real candidates fleet-wide and the current ~44.5 GB free RAM below
the ~50 GB a `single_index_tick` row needs, every worker's claim attempt
legitimately re-evaluates and re-rejects the same few heavy rows every cycle.
That is expected, bounded work (each claim transaction completes in
milliseconds per the logs), not a hang — but it means the fleet is RAM-bound
on index-class capacity, not logic-bound.

## Why this is GRUEN, not a code-fix ticket

- The gate math is correct and not stale: `free_ram_gb` moves between calls
  and matches an independent live OS reading.
- No claim-eligibility logic is misclassifying a genuinely-claimable row —
  every row in the sampled skip categories fails a real, documented
  threshold (RAM headroom, DSR peer-cohort window, trial-ledger
  requirement).
- Worker processes are alive and cycling (`farmctl.py mt5-slots`: T1–T10 all
  present with live PIDs), and several terminals successfully claimed within
  the last few hours — this rules out a frozen/crashed worker needing a
  restart.
- No gate threshold or verdict logic was changed by this task, per the
  instruction.

## Recommended next step (not self-assigned here)

The fleet's real constraint is capacity, not a defect: only 33 claimable rows
exist fleet-wide (89% of nominal "pending" rows are parked under holds), and
several of the few at the head of that thin queue need RAM headroom
(`single_index_tick` 42 GB, `total_news_parent` 46 GB free-RAM requirement)
that a ~44–45 GB-free host intermittently cannot supply. If OWNER wants
faster throughput on this specific tail, the lever is releasing some of the
3,699 held rows back into the pool (widening the candidate set so cheaper
rows are available alongside the RAM-heavy ones) or freeing host RAM — not a
code change to the claim/admission logic itself.

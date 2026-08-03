# Requal-Chain Gate-Walk — 2026-08-03

**Context.** The five calendar-bundle requalification chains (book candidates
11422/13013/13036/20048 + OWNER-ruled 10440) all stalled after their fresh Q02
PASS: `dispatch_tick` auto-enqueues the next phase only when that phase has **no
completed row yet** (see `evidence_cascade_driver.py` docstring), and every one
of these pairs carries old-binary `done PASS` rows in Q03+. The legacy
`evidence_cascade_driver` flips historical rows (pre-append-only doctrine) and
was NOT used; each gate is instead walked with append-only
`farmctl enqueue-backtest` reruns pinned to the current EX5 SHA256.

## Contract lessons (fail-closed refusals observed)

| Refusal | Meaning | Correct invocation |
|---|---|---|
| `q03_predecessor_mismatch_or_not_terminal_pass` | `--from-work-item-id` must be the **fresh Q02 PASS** row, not the old Q03 | predecessor = fresh Q02 |
| `q03_exact_identity_already_exists` | plain Q03 enqueue is pair-level deduped (vintage-blind) | add `--append-only-rerun-of <old Q03>` |
| `q03_rerun_source_evidence_missing` | rerun target's summary purged from disk (tester-cache purge) | pick evidence-backed target — if none identity-matches: contract gap (see ticket) |
| `q03_append_only_target_identity_mismatch_or_not_terminal` | evidence-backed old row fails identity vs. fresh predecessor | contract gap (see ticket) |
| `q02_pair_already_has_current_binary_terminal_result` | INFRA_FAIL counts as current-binary terminal result | no blind re-enqueue; LOG_BOMB poison stays terminal |

## Rows enqueued today (append-only, `--expected-current-ex5-sha256` pinned)

| EA / symbol | Phase | Predecessor (fresh) | Rerun-of (old) | Result |
|---|---|---|---|---|
| QM5_13036 GDAXI.DWX | Q03 | bec45e8f (Q02 PASS) | — (first Q03 ever) | **PASS** 09:02Z, wi 528a41da |
| QM5_11422 USDCAD.DWX | Q03 | 7922733b | 7108a81f | **PASS** 09:08Z, wi fcc592e5 |
| QM5_13013 NDX.DWX | Q03 | 9a725d0c | 47d2c7cc | active 09:08Z, wi 2758ceee |
| QM5_20007 GDAXI.DWX | Q04 | c8d84e97 (Q02 PASS) | cffc4c97 (ACTIVE_TIMEOUT) | active 09:06Z, wi 463815b5 |
| QM5_11422 USDCAD.DWX | Q04 | fcc592e5 (Q03 PASS) | a15b83f2 | enqueued 09:2xZ |
| QM5_13036 GDAXI.DWX | Q04 | 528a41da (Q03 PASS) | 8a363c83 | enqueued 09:2xZ |

Blocked: **QM5_10440 NDX.DWX Q03** — identity-matching old row 9c7700c3 has
purged evidence; evidence-backed row b1adfe17 fails the identity check. Needs a
contract extension (mirror of `seed-fresh-q02`): router ticket **13fcd6a0**
(ops_issue, prio 70). `farmctl.py` is one of the 12 runtime-decision-bound
sources — the fix stays branch-only (DL-065) until a coordinated merge +
decision rebind.

Not requeued: **QM5_20048 XTIUSD.DWX Q02** (`run_smoke_fail:LOG_BOMB;INCOMPLETE_RUNS`,
wi 1c52bfca) — LOG_BOMB is a deliberate poison sentinel; diagnosis ticket
**cc46b848** (pattern: 20007 fix package ec348e2b8).

## Dispositions

- **11592 (both symbols): merit-dead at Q04** — GBPUSD Q04 FAIL 2026-07-31T08:31Z,
  EURUSD Q04 FAIL 2026-08-01T01:14Z, binary unchanged since; the 2026-08-02 Q02
  PASSes were prescreen-sweep rows, the cascade correctly stops at the existing
  Q04 verdicts. No requeue.
- Tickets filed this morning (agent_router, ops_issue): 13fcd6a0 (Q03 rerun
  contract, 70) · 32b500cd (10582 lineage break, 60) · 1b00f708 (FTMO M1
  bootstrap, serial, 55) · 2270a0a5 (Q08 lifecycle harvest V1 fields, 55) ·
  cc46b848 (20048 LOG_BOMB diagnosis, 50).

**Standing note.** Until ticket 13fcd6a0 lands, every further gate of these
chains must be pushed manually with the table's invocation pattern (predecessor
= fresh prior-phase PASS row, rerun-of = newest old same-phase row, SHA pinned).
Claude watches and advances them as verdicts arrive.

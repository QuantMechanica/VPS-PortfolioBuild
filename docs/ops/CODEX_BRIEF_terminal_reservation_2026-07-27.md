# Codex brief — there is no way to reserve a terminal for ad-hoc work

Date: 2026-07-27
Priority: high. This blocked a completed piece of work today.

## The problem, evidenced

A joint-backtest EA (`QM5_20180`) was built, compiled clean and made turnkey today, and
then **could not be run at all** — not because of a defect in it, but because no MT5
terminal could be obtained. Evidence in
`docs/ops/evidence/2026-07-27_joint_backtest_run_results.md` §1.1 and confirmed again in
`docs/ops/evidence/2026-07-27_joint_vs_python_model_validation.md` §1:

- `work_items` `pending` = **2073**, `active` = 8. Roughly 2000 of the pending rows are
  Q02. This is days of backlog, not a lull.
- Every non-dead factory terminal carries a live `terminal_worker.py`.
- Each worker's `run_loop` (`tools/strategy_farm/terminal_worker.py:2902-2965`) claims
  the next queued item whenever the disk/RAM/commit guards allow.

The specific defect:

> `claim_atomic` (`tools/strategy_farm/terminal_worker.py:960-1060`) has **no
> `disabled_terminals` check**. `disabled_terminals.txt` is consulted **only by the
> supervisor at spawn** (`tools/strategy_farm/farmctl.py:285-304`).

So a terminal can be excluded at spawn time, but a worker that is already running will
keep claiming work regardless. There is no supported way to say "hold T6 free for the
next hour" without killing its worker — and killing workers is exactly the operation
that has previously produced the `launch_fault` wedge class requiring a full
`Factory_OFF` / `Factory_ON` cycle.

The result is an operational dead end: ad-hoc evaluation work is either impossible while
the queue is deep, or requires an unsafe intervention.

## What to do

1. **Verify the diagnosis** against the current code before building anything. Cite
   file:line for both the claim path and the supervisor path. If the diagnosis is wrong,
   say so and stop — that is a valid outcome.
2. **Make reservation honoured at claim time**, not only at spawn. A running worker
   should decline to claim new work when its terminal is reserved, finish what it is
   already running, and idle cleanly. It must **not** exit, respawn, or leave a
   half-claimed item — a stuck claim is worse than a busy terminal.
3. **Make it expire.** A reservation with no timeout will eventually be forgotten and
   silently starve the fleet. Design a default expiry and say what happens when it
   lapses.
4. **Make it visible.** A reserved terminal must be obvious in `farmctl mt5-slots` and on
   the cockpit, with who reserved it and until when. An invisible reservation is a
   future outage.
5. **Do not change claim semantics for unreserved terminals.** The claim path is the
   throughput-critical hot path and has a known silent-skip starvation history
   (`claim_atomic` skipping without logging). Any change must not add a new silent skip:
   a declined claim due to reservation must be logged.

## Constraints

- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`.
- Do NOT kill terminal workers or interrupt running backtests to test this. Design a
  test that does not require taking the fleet down; if you genuinely cannot test it
  safely while the factory runs, say so and propose how it should be validated later.
- Never touch `C:/QM/mt5/T_Live`.
- MT5 saturation is the factory's primary throughput metric. A bug here starves the
  queue, so err toward failing open (claim allowed) rather than failing closed.
- Commit with explicit pathspecs. Evidence over claims.

## Deliverable

The fix plus `docs/ops/evidence/2026-07-27_terminal_reservation.md`: the verified
diagnosis, the mechanism, the expiry behaviour, where it surfaces, and how it was
tested without disturbing the fleet.

# Codex brief — repair T5: its tester indicator engine is dead

Date: 2026-07-27
Priority: high. OWNER asked for this directly.

## The fault

Since 2026-07-24, terminal **T5**'s Strategy Tester cannot compute indicators.
`BarsCalculated` returns **-1 forever** — proven with a purpose-built control EA, not
inferred from failing backtests.

Operational consequence: **a T5 FAIL is unattributable.** It may be the strategy or it
may be the terminal, and nothing downstream can tell them apart. Only a T5 PASS carries
information. That is one tenth of the fleet producing evidence that must be discarded,
while the queue stands at ~2073 pending items.

Prior work you should read before starting:

- Router task `61cfbaf3` (closed 2026-07-27 as SAFE_DEFER): established T5 is isolated
  and its binaries match T1, with **no registered rollback path**. That was a decision
  to defer, not a diagnosis. OWNER has now asked for the repair.
- Search `docs/ops/` for the control-EA evidence from 2026-07-24 and any T5 notes.

Related known facts that may or may not be causally connected — verify, do not assume:
`T_Export` has no ticks; `DEV1`/`DEV2` are governed by a QMDev1 SID guard; the fleet was
de-junctioned across T2-T10 on 2026-07-14 (rollback exists at
`fleet_dejunction.ps1 -Rollback`).

## What to do

1. **Reproduce first.** Confirm `BarsCalculated = -1` on T5 today with the control EA,
   and confirm the same EA works on a healthy terminal. If it no longer reproduces, that
   is the most valuable possible finding — say so and stop.
2. **Diagnose against a working terminal.** T5's binaries reportedly match T1, so the
   difference is elsewhere: profile/config, `MQL5` directory contents, custom symbol
   registration, history/cache state, `origin.txt` or junction layout, terminal data
   path, permissions, or a corrupt `bases/` tree. Compare T5 against a healthy terminal
   systematically and report where they diverge. **Name the divergence before proposing
   a fix.**
3. **Prefer the least destructive repair that the diagnosis supports.** Rank the options
   you find by blast radius. A full T5 rebuild is acceptable if the evidence supports it,
   but only after the diagnosis, never as a first move — a rebuild that does not address
   the cause will silently reintroduce it.
4. **Verify with the control EA**, then with one real backtest that previously failed on
   T5, and confirm the result matches a healthy terminal's result for the same work item.
5. **Record the rollback path.** The prior review flagged that none exists. Whatever you
   change, document how to undo it.

## Constraints

- **Reserve T5 before touching it**: `python tools/strategy_farm/farmctl.py
  reserve-terminal T5 --by codex --minutes <n> --reason "T5 repair"`. This is honoured
  at claim time (`terminal_worker.py:1056`), so no worker will take it from you.
  Release it when done — the queue is deep.
- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`.
- Do NOT touch any terminal other than T5. **T9 is reserved for a joint backtest** and
  must not be disturbed. Never `C:/QM/mt5/T_Live`.
- Do NOT re-import `.DWX` history, and do NOT run `CustomTicksReplace` headless — that
  has a known cache trap requiring a Factory OFF/ON cycle you are not permitted to run.
- Do not reboot, log off, or run `tscon`. Live trading is running.
- Commit with explicit pathspecs. Evidence over claims: `BarsCalculated` output, file
  diffs, and log paths, never "it looks fine now".

## Deliverable

`docs/ops/evidence/2026-07-27_t5_repair.md`: the reproduction, the named divergence
against a healthy terminal, the repair, the verification (control EA plus one real
backtest matching a healthy terminal), and the rollback path. If the cause cannot be
established, report the elimination you performed and stop rather than rebuilding blind.

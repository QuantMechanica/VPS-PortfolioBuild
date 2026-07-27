# Codex brief — execute the QM5_20180 joint backtest. T9 is reserved for you.

Date: 2026-07-27
Priority: highest. OWNER prioritised this explicitly.

## The block is gone — it was never real

Yesterday's workflow reported that this run was impossible because "no terminal could
be reserved": it found that `claim_atomic` does not consult `disabled_terminals.txt`
and concluded no claim-time reservation exists.

**That diagnosis was wrong.** Terminal reservation is fully implemented and honoured at
claim time:

- `tools/strategy_farm/terminal_worker.py:1056` calls
  `farmctl.terminal_reservation(root, terminal)` inside the claim path and returns
  `{"claimed": False, "reason": "terminal_reserved"}`, logging
  `terminal_reservation_claim_declined`.
- `tools/strategy_farm/farmctl.py:303-341` expires reservations via `until_utc` and
  fails open on malformed entries.
- `tools/strategy_farm/render_cockpit.py:1939` surfaces them.
- CLI: `farmctl.py reserve-terminal <T> --by <who> --minutes <n> --reason <text>` and
  `release-terminal <T>`.

`disabled_terminals.txt` is a spawn-time mechanism and a different thing entirely.

**T9 IS ALREADY RESERVED FOR YOU** by `claude` until **2026-07-27T15:45:23Z**
(4 hours). Verify with `farmctl.py mt5-slots`. No worker will claim queue work on it.

## What to run

Execute the protocol in
`docs/ops/evidence/2026-07-27_joint_backtest_run_results.md` §3 exactly as written. It
is turnkey: exact window, commission parity proof, deploy steps, `tester.ini`, run
order, and diff commands are all recorded there. Do not redesign it.

Summary of the run order:

1. `replay_s0.set` -> harvest `q08_trades/20180_USDJPY_DWX.jsonl` -> copy to
   `20180_s0.jsonl` -> `python tools/strategy_farm/compare_joint_replay.py --joint
   20180_s0.jsonl --gated <9936 stream>`.
2. `replay_s1.set` -> same against the 13213 stream.
3. **Admission gate: admit a sleeve only at `match_rate == 1.0`.** A low match rate is
   a FINDING TO REPORT, never something to tune away. If sleeve 0 is not bit-identical
   to standalone 9936, stop and report — the build doc predicts byte-identity, so a
   mismatch means the joint EA is not trading the gated strategy and the whole
   instrument is invalid.
4. `backtest.set` (both sleeves) -> harvest the trade stream, the equity stream
   (`q08_equity/20180_USDJPY_DWX.jsonl`, `EQUITY_BAR` per H1 bar plus `EQUITY_LOW` per
   new intraday low) and the `.htm` report.

Each run truncates the shared output file, so **harvest before launching the next
config**. Do not run two configs concurrently.

## The measurements that matter

From the joint streams compute and report:

- Realised daily-P&L correlation between the two sleeves on this single joint run.
  Context: they are already known to be near-collinear (r=0.905 on shared days, 269
  bit-identical trades), so treat a high number as confirmation, not discovery.
- The **true account-equity path**, and from it the observed maximum daily loss and
  maximum drawdown against FTMO's -5% and -10%.
- **The count of -5% daily-limit breaches from OBSERVED intraday equity (`EQUITY_LOW`),
  compared against the pessimistic MAE proxy the Python models use.** This is the
  primary scientific output: it tells us whether every pass rate we have reported for
  two days was too low or too high, and by how much. Report direction and magnitude.
- Wall-clock and peak RAM per run, so we know whether this is repeatable.

## Constraints

- Use **T9 only**. It is reserved for you. Do NOT touch any other terminal, do NOT use
  T5 (its tester indicator engine is dead), never `C:/QM/mt5/T_Live`.
- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`.
- Do NOT re-import `.DWX` history. A first-attempt `NO_HISTORY` is a known cold-cache
  transient — retry once.
- If you finish early, run `farmctl.py release-terminal T9` so the fleet gets it back;
  2073 items are queued behind you.
- If the reservation expires mid-run, do not re-reserve silently — report it.
- Do not invent commission, swap or DST values.
- Commit with explicit pathspecs. Evidence over claims: every number needs a path.

## Deliverable

`docs/ops/evidence/2026-07-27_joint_backtest_run_EXECUTED.md` with the fidelity match
rates, all four measurements, every artifact path, and the run cost. If the fidelity
gate fails, that document reports the failure and the measurements are not produced —
that is a complete and acceptable outcome.

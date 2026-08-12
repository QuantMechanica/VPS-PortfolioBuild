# Codex brief — clear the two blockers between us and the book measurement

Date: 2026-07-28
Priority: highest. One build pass clears the chain.

## Context

The step-2 joint run COMPLETED through the governed queue (staged EX5, 24 minutes on
T1, satellite traded 149 XAUUSD fills) but failed admission for a structural reason,
fully diagnosed in docs/ops/evidence/2026-07-28_multisym_steps23_EXECUTED.md section
3.1 and docs/ops/evidence/2026-07-28_ftmo_book_answer.md section 2b.

## Task 1 — the ownership contradiction in QM_Common.mqh

The q08 emitter keeps only deals whose opening magic is owned per
QM_FrameworkOwnsMagicSymbol (QM_Common.mqh:400-429). For a foreign-symbol satellite
magic that returns true ONLY in basket mode (:414-415). The joint EA deliberately
avoids basket mode to keep the runner byte-identical, and QM_MagicChecked registers
no (magic,symbol) context. Result: the satellite's closing deals are silently
excluded and its stream never exists.

Fix as specified in the EXECUTED doc section 3.1: a targeted, opt-in (magic,symbol)
context registration that does NOT flip basket mode and does NOT alter any existing
path - e.g. an explicit registration call the joint EA makes per satellite at init.
Default behaviour for every existing EA must be bit-identical; prove it the way the
prop-firm section did (a non-opting EA's path untouched, compile 0/0, and say so
with file:line).

## Task 2 — wire slot 2 (13108) in QM5_20181

The EA wires exactly one satellite (g_sat_count = s1_enabled ? 1 : 0, mq5:284; only
QM20181_Run10145 exists). Add the s2 input group and QM20181_Run13108, bound
faithfully from the gated QM5_13108 sources (TIMER-SAFE, decided in
goal_blocker_chain.md B3 as the deployable replacement for per-tick-trailing 13301,
OOS FUND_SCORE 0.527). Same discipline as slot 1: own magic, own state, symbol_slot,
persistent once-per-bar idempotence.

NOTE: slot-2 = 13108 is pending a one-line OWNER confirmation. Build it now so
nothing blocks when the confirmation arrives; do not enqueue the 3-sleeve run until
the confirmation is recorded.

## Task 3 — diagnose the 0.999125

Runner invariance with the satellite on: one shifted exit (2020-08-11), 1142/1143.
Find the mechanism before the rerun - one trade is either a genuine coupling (order
of operations on a shared account at the same timestamp?) or an artifact. Do not
hand-wave it; at 1,143 trades a single coupling can hide a class.

## Then

Recompile, stage, enqueue the step-2 rerun (2 sleeves) through the governed queue.
Gates unchanged: satellite fidelity 1.0 vs fresh standalone 10145 (enqueue that
standalone alongside if no fresh reference exists), runner invariance 1.0.

## Constraints

- Serial compiles; SHA256 recorded; staged-EX5 items only; explicit pathspecs.
- Do NOT run Factory_OFF/ON; never T5, never T_Live; no re-imports; no mass-requeues.
- QM_Common change: default path bit-identical for non-opting EAs, proven not asserted.

## Deliverable

docs/ops/evidence/2026-07-28_ownership_fix_and_slot2.md plus the enqueued rerun ids.

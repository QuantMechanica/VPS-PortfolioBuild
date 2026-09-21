# OWNER request: FTMO Break & Retest / NNFX research intake

ID: `OWNER-REQUEST-FTMO-BR-NNFX-20260921`
Recorded by: Codex, 2026-09-21. Source: current interactive OWNER instruction.

## Verbatim instruction

> Gibts gute Forex Break & Retest Strategien, die wir noch nicht getestet haben? Indizes, FX, Metals, etc.? Gibts noch ungetestete No Nonsense Forex Strategien? Wir suchen konkret Strategien um eine FTMO Challenge (2-step) inkl Auszahlung so schnell wie möglich zu bestehen. Wir gehen dabei das Risiko ein, dass wir nur in 80% der Fälle bis zur Auszahlung kommen und in 20% der Fälle scheitern. Dafür fehlen uns aber schnelle und erfolgreiche Strategien. Du kennst die Factory, kannst diese Strategien also alle in die Fabrik einplanen! Leg los!

## Execution interpretation

Research, inventory deduplication, candidate recovery and Factory planning are authorised.
The speed objective applies to the entire two-step-to-first-payout chain, with an 80%
success / 20% failure tolerance. This is a desired outcome, not existing empirical evidence.

The implementation records seven bounded research/recovery/evaluation packets and links
existing work rather than creating duplicate builds. Suitable survivors proceed through
the ordinary source, review, build and Q-gate process. This record does not represent
source-specific G0 approval, an EA success verdict, a purchase order or a live risk change.
Existing production admission contracts remain in force. The 80% lower-bound diagnostic
and calendar horizons in the plan are the analyst's conservative operationalisation, not
extra words attributed to OWNER. Account size and initial reward amount are assumptions
until specified; the plan evaluates several sizes of first reward.

Deliverable: `docs/research/ftmo_intake/2026-09-21_br_nnfx/PLAN.md`.
Runtime authority: `D:/QM/strategy_farm/state/farm_state.sqlite`, `agent_tasks`.
Receipt: `docs/research/ftmo_intake/2026-09-21_br_nnfx/scheduling_receipt.json`.

## Orchestrator integration (Fable, 2026-09-21 ~21:00Z)

Recorded by Codex from a direct OWNER instruction; integrated by the orchestrator under OWNER-DEC-FTMO-DUAL-TRACK-20260921 as
follows (router truth is `agent_tasks`; this note is the disposition record):

- `e5cc5e95` PAYOUT80 (Codex, 80) — KEPT, IN_PROGRESS: the full-chain payout-by-day diagnostic (days 30/45/60/90, earliest day at
  which the payout lower bound reaches 0.80, or NOT_REACHED) becomes a KPI-contract diagnostic next to P_FIRST_NET_FTMO_PAYOUT_LCB.
- `9ace7476` N-GAPS (Antigravity, 70) — KEPT, IN_PROGRESS (NNFX state-machine coverage gaps; research writing on an otherwise idle lane).
- `a42aa6f7` BR1, `2eba7ef7` BR2, `ff6826f5` BR3 (Codex research_strategy) — BACKLOG: the three hypotheses are pre-registered and
  prescreened by Fable as **Track B family B3** in the shared conservative closed-bar engine
  (`tools/strategy_farm/session_tools/velocity_family_f3_break_retest_0921.py`, PLAN rules verbatim, 16 cells, 0 factory hours) —
  the tickets themselves gate on harness v2 (`7088da77`) and venue cost (`73434cab`) and would only prepare until then. They are
  reopened for mechanisation/build if a B3 cell reaches WORTH_MT5_TEST.
- `cd3b761c` N-RECOVERY, `df1cae9b` R-RECOVERY (Codex ops, 72/74) — BACKLOG until after the Sunday 2026-09-27 launch: legacy D1
  NNFX/retest identities with UNVERIFIED card claims and no velocity role; OWNER §O ranks such recovery 9-10 and the dual-track
  correction protects Codex capacity for launch + shadow research. Re-route 2026-09-28.
- The intake directory and this record were committed to the canonical branch by cherry-pick (ed3eef5a0d, Codex authorship kept).
- Role note: research direction, decision records and router scheduling are the orchestrator's; a direct OWNER-Codex session is
  the OWNER's prerogative, but its outputs enter the board through this integration, never as a second scheduler.


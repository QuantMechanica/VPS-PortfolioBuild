# QUA-344 Child-Issue Split (Unblock Execution)

Date: 2026-04-28
Parent: QUA-344
Purpose: Replace repeated probe-only loops with assignable unblock work.

## Child Issue 1 — Bind Strategy Identity
Owner: Dev

Scope:
- Assign `ea_id` in strategy card header.
- Move card status out of `DRAFT` to the next executable lifecycle state.
- Commit any required metadata updates.

Done when:
- `strategy-seeds/cards/lien-inside-day-breakout_card.md` no longer contains `ea_id: TBD`.
- Status line is no longer `status: DRAFT`.

## Child Issue 2 — Compile Binding
Owner: Dev

Scope:
- Implement/confirm EA source path and compile pipeline.
- Produce compile-pass `.ex5` artifact for assigned `ea_id`.
- Record reproducible compile command.

Done when:
- Compile command succeeds from clean workspace.
- `.ex5` output path is documented and reproducible.

## Child Issue 3 — Dispatch + Baseline Binding
Owner: CTO

Scope:
- Define terminal/profile target.
- Define symbol/timeframe baseline (minimum D1 target set).
- Define baseline date window and spread/model assumptions.
- Select initial risk mode (`risk_mode_single` or `risk_mode_dual`).

Done when:
- A single executable pipeline run command exists with no missing fields.

## Child Issue 4 — First Executable Run
Owner: Dev (with CTO validation)

Scope:
- Execute the bound pipeline command.
- Persist run outputs and update heartbeat with transitioned signature.

Done when:
- Heartbeat signature is no longer `blocked|DRAFT|TBD|TBD`.

## Immediate Next Step
Create these four child issues in the tracker and link them to QUA-344 parent.

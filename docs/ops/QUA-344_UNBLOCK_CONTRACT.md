# QUA-344 Unblock Contract (Executable Binding Fields)

Date: 2026-04-28
Issue: QUA-344 SRC04_S05 — lien-inside-day-breakout
Current signature: blocked|DRAFT|TBD|TBD

## Why this exists
Repeated heartbeat runs show no transition because required execution bindings are still missing.
This file defines the minimum fields required to move from `DRAFT`/`TBD` into executable pipeline work.

## Required unblock fields (owner: Dev + CTO)
1. `ea_id` assigned in the strategy card header (replace `TBD`).
2. EA implementation path committed in repo (source file path and build config).
3. Compile output path for `.ex5` confirmed and reproducible.
4. Dispatch target defined:
   - terminal/profile identifier
   - symbol set
   - timeframe (`D1` baseline at minimum)
5. Baseline backtest window defined:
   - start/end dates
   - modeling assumptions/spread policy
6. Risk mode binding chosen for first executable pass:
   - `risk_mode_single` or `risk_mode_dual` (P3 variant)
7. Pipeline entrypoint confirmed:
   - next runnable phase command (single canonical command line)

## Acceptance criteria to clear blocked state
- Card header no longer contains `ea_id: TBD`.
- Card/header status is moved from `DRAFT` to the next executable state expected by pipeline.
- A compile-pass artifact exists for the assigned `ea_id`.
- A single run command exists that another agent can execute without guessing missing fields.

## Next action after unblock
Run:
- `infra/scripts/Invoke-QUA344Heartbeat.ps1`
- then execute the bound pipeline command from this contract.

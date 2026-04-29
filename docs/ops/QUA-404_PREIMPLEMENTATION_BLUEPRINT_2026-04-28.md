# QUA-404 Pre-Implementation Blueprint (SRC04_S05)

Date: 2026-04-28
Issue: QUA-404
Strategy: SRC04_S05 (`lien-inside-day-breakout`)

## Purpose

Implementation-ready mapping from card rules to V5 EA code modules. This does not start EA coding; it prepares the first unblock heartbeat.

## Preconditions (must be true before coding)

1. Card `strategy-seeds/cards/lien-inside-day-breakout_card.md` is `status: APPROVED`.
2. Card `ea_id` is concrete (not `TBD`).
3. `framework/registry/ea_id_registry.csv` has matching row for `SRC04_S05`.

## Target EA Path (after `ea_id` allocation)

- `framework/EAs/QM5_<ea_id>_lien_inside_day_breakout/QM5_<ea_id>_lien_inside_day_breakout.mq5`

## Required Input Groups

- QuantMechanica V5 Framework
- Risk
- News
- Friday Close
- Strategy

## Strategy Inputs (card-aligned)

- `input int    INP_InsideDaysMin = 2;`             // Card §4, Lien Ch12 rule 1
- `input double INP_BreakoutOffsetPips = 10.0;`     // Card §4, Lien Ch12 rule 2
- `input double INP_ReverseOffsetPips = 10.0;`      // Card §4, Lien Ch12 rule 3
- `input double INP_TP1_RR = 2.0;`                  // Card §5, Lien Ch12 rule 4
- `input bool   INP_EnableStopReverse = true;`      // Card §5 false-breakout protection
- `input int    INP_ReverseLotsMode = 1;`           // Card §5/§8: default 1, sweep 2
- `input bool   INP_EnableDirectionalBias = false;` // Card §4 optional optimization

## Module Responsibilities

### 1) No-Trade / Framework Hooks

- Use `<QM/QM_Common.mqh>`.
- Use `QM_Magic(ea_id, slot)` only.
- Keep Friday close enabled by default.
- Use framework news filter/kill-switch/risk sizing.

### 2) `Strategy_EntrySignal`

- Evaluate on new D1 bar only (Card §3/§4).
- Detect consecutive inside-day cluster (Card §4 definition).
- Require count `>= INP_InsideDaysMin`.
- Derive "previous inside day" and "nearest inside day" levels per Card §4.
- Emit long/short breakout trigger levels:
  - long: `prev_inside_high + breakout_offset`
  - short: `prev_inside_low - breakout_offset`

### 3) `Strategy_ManageOpenPosition`

- For active primary position, compute initial risk from reverse trigger (Card §5).
- At `TP1_RR`:
  - partial close behavior per existing V5 conventions
  - move stop to BE / start trail per card-managed defaults.
- If stop-and-reverse enabled and reverse trigger hit:
  - close current direction
  - open reverse direction with configured lot mode (default 1, optional 2).

### 4) `Strategy_ExitSignal`

- Support hard stop, TP1 logic, and trailing continuation (Card §5).
- Respect framework Friday close flatten.
- Keep symmetric long/short behavior (Card header `symmetric-long-short`).

## Compile/Handoff Checklist (first unblock heartbeat)

1. Implement `.mq5` with inline card citations in non-obvious rule blocks.
2. Compile with project compile script; zero errors/warnings.
3. Produce CTO review handoff note (EA vs card traceability).
4. Do not run pipeline/backtests from Development.

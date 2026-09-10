# QM5_41140 diverse-FX source repair

## Scope

This paced-fleet unit advances the approved, structural D1 NZDJPY carry-unwind
sleeve in place. It does not alter the portfolio gate, any live manifest,
AutoTrading, or `T_Live`.

Farm coordination:

- Pipeline build task: `5f69b208-6e8b-4900-a8c2-020c779eb030`
- Paced-agent claim: `d0fadd70-d416-43fb-a963-c49b61b6c7e2`
- Historical successful compile: `c791b8f6-7474-495a-abab-2469b610f332`
- Existing pending logical-basket Q02: `381b2608-c3f1-4493-88f8-9ed119e61d69`

## Repair

- Replaced the file-scope completed-bar latch and raw `iTime` exit cadence with
  framework-owned calendar-period and bar readers.
- Replaced the raw holding-period lookup with
  `QM_TM_HeldPeriodsForMagic`.
- Declared every broker symbol and strategy control as a `strategy_*` input so
  Q02 intake can bind the actual strategy configuration and the EA contains no
  non-input broker-symbol literals.
- Preserved the card mechanics and values: four-cross JPY breadth, prior
  20-session low, 10-versus-60-session volatility gate, two-ATR stop, and
  ten-session maximum hold.
- Set both fixed-risk backtest presets to a pending build identity for the
  repaired binary (`RISK_FIXED=1000`, `RISK_PERCENT=0`).
- Added a runtime `ArraySize` proof for the volatility sample buffer.

The locked-input guard compares only `qm_ea_id`, `qm_magic_slot_offset`,
`strategy_*` inputs, and fixed-risk mode. Stress probability is checked only
for finiteness and the inclusive `0..1` range. It does not pin RNG, news, or
Friday-close inputs.

## Validation and compile admission

- `validate_spec_doc.py`: PASS
- `validate_build_guardrails.py`: PASS, no findings
- Required framework-input pin audit: PASS, `hit_count=0`
- Source SHA-256 presented to the compiler queue:
  `b25ad6366f2dfabb7610170babe56c7d5aaaf57bea44c2b2825778a6686ccff4`

The governed compiler admitted the exact build-task binding but refused the
replacement compile with these exact findings:

`EX5_ALREADY_PRESENT`, `WORK_ITEMS_EXIST`, `BOUND_SETFILE_HASH_EXISTS`.

The response also reported `source_repair_authorized=false` and no registered
source-repair artifact binding. Therefore no compile or Q02 successor was
enqueued. Replacing the historical successful binary requires an exact
source-repair authority bound to `QM5_41140`, the repaired source hash, and
predecessor `c791b8f6-7474-495a-abab-2469b610f332`.

The pre-existing pending Q02 row was then made unclaimable with governed hold
`SOURCE_REPAIR_AUTHORITY_REQUIRED`; its status and history were not rewritten.
The hold can be released only after a `COMPILE_OK` successor is bound to the
source hash above and Q02 is append-only rebound to that EX5. Hold evidence is
`D:/QM/strategy_farm/artifacts/holds/qm5_41140_source_repair_hold_20260910.json`;
the pre-mutation database backup is
`D:/QM/strategy_farm/state/backups/farm_state_before_governed_hold_20260910T130226Z.sqlite`
with SHA-256
`b1189a3affae11e169e98293e3cd109c2eb665dab9dd81cb80bdcebc35b86b0a`.

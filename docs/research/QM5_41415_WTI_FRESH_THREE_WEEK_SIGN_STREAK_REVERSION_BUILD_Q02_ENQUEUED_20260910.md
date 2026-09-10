# QM5_41415 WTI Fresh Three-Week Sign-Streak Reversion — Build and Q02 Enqueue

Date: 2026-09-10  
Branch: `agents/board-advisor`

## Outcome

`QM5_41415_wti-wstreak3-fade` is a new low-frequency WTI energy build. At a
Monday broker-week boundary it reconstructs five completed week-ending closes
and four adjacent weekly returns. It admits only a fresh three-week same-sign
streak after one opposite week, then trades opposite that streak for one week.

This is not a parameter copy. `QM5_41074` follows the identical state and is
the expected direction sibling; direction is the entire economic hypothesis.
`QM5_41412` fades exact three-week alternation, whose state is disjoint.
Reputable-source lineage comes from academic commodity-reversal research and
the governed complete peer-reviewed time-series-momentum record with explicit
WTI membership. The exact weekly fade is disclosed as untested.

The source approval, source packet, G0-approved card, governed ID and magic,
V5 source, fixed-risk preset, reference tests, and compiled binary are
committed. The reference suite passed 11/11.

## PACER And Compile Evidence

After source generation and before compile enqueue, the binding framework-
input pin audit exited zero with no `EA_FRAMEWORK_INPUT_PINNED` finding. After
replacing the symbol literal default with input-only binding, it again passed
with zero findings. The guard pins only strategy inputs, identity/magic, and
fixed-risk mode. It never equality-compares RNG, news, Friday-close, or stress;
stress rejection is checked only for finiteness and inclusive `0..1` range.

Governed compile work item `369e8fdd-9f63-4b41-8e79-f8dca4ab1eeb` completed
`COMPILE_OK`: zero compiler errors, zero warnings, strict build-check PASS, no
failure classes, and no source symbol literals. Binary SHA-256 is
`d54663b264d171aae09421ed78fc01fc57c1eaf4838f19581c0c4d557b560fe8`.

## Q02 Enqueue

The read-only first-Q02 intake validated the sole XTI preset, registered magic,
compiled binary, nonempty strategy binding, and fixed-risk mode. The five
one-second CPU samples were 79.6%, 61.6%, 51.8%, 45.0%, and 54.3%; the maximum
79.6% stayed below the exclusive 97% ceiling.

The apply created pending Q02 work item
`4e47caf3-c306-4ce4-b979-3bb11d2bfcea` for `XTIUSD.DWX` D1. Setfile SHA-256 is
`a89643ba5267e57e2c25b0ad3cc3217d73154a4a754d4a40280287742ae30c22`.
The append-only receipt is
`D:/QM/strategy_farm/artifacts/receipts/first_q02_intake/369e8fdd-9f63-4b41-8e79-f8dca4ab1eeb_4e47caf3-c306-4ce4-b979-3bb11d2bfcea.json`.

No manual backtest, terminal control, live action, portfolio-gate change,
`T_Live` edit, AutoTrading action, or live-manifest change occurred.

## Verification

- canonical dedup: no exact identity; one expected direction sibling resolved
- reputable-source criteria: R1–R4 PASS with translation/CFD risks disclosed
- card schema and ML lint: PASS
- governed ID/magic/resolver: PASS
- deterministic reference suite: PASS, 11/11
- PACER framework-input pin audit: PASS, zero findings
- governed compile: `COMPILE_OK`, 0 errors, 0 warnings
- strict framework build check: PASS
- first-Q02 dry run: ELIGIBLE
- CPU admission: PASS, max 79.6% < 97%
- Q02: ENQUEUED, pending

Machine-readable evidence is
`artifacts/qm5_41415_q02_enqueued_20260910.json`.

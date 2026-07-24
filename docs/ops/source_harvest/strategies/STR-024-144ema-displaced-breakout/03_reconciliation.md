# STR-024 — Reconciliation (2026-07-24)

Convergent: baseline = OP variant 1 (displaced-EMA breach entry, EMA144
SL, 17-pip TP); variant 2 (hold-until-opposite) = separate unbuilt
candidate; displaced read = unshifted EMA34 handle at shift 1+16; strict
cross (close(2) on/inside, close(1) beyond); one position; skip on invalid
SL geometry. Conflicts: (1) Cohort (source-silent): claude 2 pairs, codex 3
(EURUSD/GBPUSD/USDJPY) — RESOLVED → codex (broader falsification; includes
QM5_9944's failed symbols for comparability; explicitly test-design, not
source). (2) SL semantics — both read "144 ema for the stop loss" as the
EMA144 PRICE at signal time, server-side static (no trailing-EMA exit
invention). Prior build QM5_9944 (Q02-FAIL EURUSD / Q04-FAIL USDJPY) used
the same family; differences documented in card. Hook placement per fleet
convention.

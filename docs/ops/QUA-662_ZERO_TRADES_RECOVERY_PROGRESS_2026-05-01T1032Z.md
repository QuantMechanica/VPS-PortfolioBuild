# QUA-662 zero-trades recovery progress (2026-05-01T10:32Z)

## Root-cause trace update

Tester log confirms the dominant blocker in prior runs:
- `EA_MAGIC_NOT_REGISTERED: ea_id=1003 slot=0 magic=10030000`

This invalidated prior P2 PASS claims (strategy never initialized correctly on many runs).

## Fix-forward action executed

1. Patched `framework/include/QM/QM_MagicResolver.mqh` to include `ea_id=1003` baked row.
2. Added temporary hard override in `QM_MagicRegistered` for `ea_id=1003, slot=0` to unblock while registry-bake pipeline is repaired.
3. Recompiled `QM5_1003` and deployed fresh `.ex5` to T1..T5 (hash-converged).

## Current verification state

- Fresh targeted rerun was launched (`EURUSD.DWX`, T1) under `P2_postfix2` report root.
- Wrapper invocation timed out; artifact/log inspection required to classify run result and confirm whether `EA_MAGIC_NOT_REGISTERED` is cleared.

## Next action

- Complete post-timeout artifact check and, if needed, run single-symbol verification with tighter timeout + explicit tester-log capture, then resume full P2 rerun with non-zero-trade guard.

# QM5_41144 EURUSD Quarter-End Fix Flow - Source Build CPU Stop

**Date:** 2026-09-06  
**Branch:** `agents/board-advisor`  
**Outcome:** one non-duplicate structural FX candidate was claimed, allocated,
implemented, and committed. Its governed compile was enqueued, but the
canonical rollout hold was not released and Q02 was not enqueued because the
binding host-CPU ceiling was hit.

## Unit delivered

`QM5_41144_eurusd-quarter-end-benchmark-fix-hedge-flow` implements the
OWNER-approved Melvin-Prins London-fix mechanism on `EURUSD.DWX / M15`, using
`GDAXI.DWX` only as a signal carrier. On the last London business day of March,
June, September, and December, the completed index month-to-date return at
14:00 London determines the contrarian EURUSD direction. The position uses a
fixed H1 ATR(14) stop and is flattened by 16:00 London. There is no re-entry,
grid, martingale, averaging, ML, or banned indicator logic.

Both physical and logical-basket backtest sets pin `RISK_FIXED=1000` and
`RISK_PERCENT=0`. Magic `411440000` is registered for the traded EURUSD leg;
the signal-only GDAXI carrier correctly receives no magic allocation.

Source build commit: `8d5c1616a9`.

## Verification

- prebuild gate: PASS, no errors or schema failures;
- spec validation: PASS;
- independent reference suite: 6/6 PASS;
- build-gate hardening: PASS, zero failures and zero warnings;
- resolver regeneration: 18,138 rows retained, zero dropped;
- MQ5 SHA-256:
  `936EDAD7222D5B5E762E5D5EECF39EC1671D900F927B8FF46EB3F136EAE13323`;
- approved-card SHA-256:
  `9321533CE1A9194B3BC7B7A79FE602E6012E348DECCE9BB4483609BFF3DC700D`;
- physical set SHA-256:
  `C650B083FC23255C4C0DA0224F5F5F4D2E8FBE04EEF461844AD7174F6A59EFEF`;
- logical set SHA-256:
  `340B6BFC5E653C7AA1E51810A92ED3DB18C887F1962E7FAC5061A6081D25960F`.

## Farm coordination and compile state

Paced-fleet claim `4b622f5c-2c7a-4822-a2f4-ec98ae73d86b` and bound build task
`56e0de46-1828-4bff-bfff-7b304e8c5d69` prevent a duplicate build. Governed
compile work item `4ae532e0-6b3c-4e4e-bc56-013aff653f28` is pending, unclaimed,
attempt zero, and verdict-free under `COMPILE_EA_WORKER_ROLLOUT_PENDING`.

The exact-item rollout dry-run accepted it: current and enqueued source hashes
both equal `936edad7...eae13323`. The hold was not released. No EX5, compile
PASS, smoke result, or Q02 row is claimed.

## Binding CPU stop

The fresh five-sample total-CPU window was:

```text
97.58, 97.76, 96.39, 89.07, 93.16 percent
average = 94.79 percent
maximum = 97.76 percent
binding ceiling = 97 percent
```

Because the maximum exceeded 97%, the mission stopped before compile release,
smoke, or tester dispatch. Existing T4, T9, and T10 factory activity was left
untouched.

## Funnel caveat and safe continuation

The approved card frontmatter claims 100 expected trades per year, but its
literal quarter-end-only, one-entry-per-date mechanics cap this implementation
at four entries per year before news/session skips. That is below the current
Q02 five-trades-per-year floor. This mismatch was not flagged by prebuild.
Research/OWNER should reconcile the approved frequency claim and mechanics
before scarce Q02 capacity is spent; no strategy mechanics were invented to
manufacture frequency.

Do not enqueue another compile row. If the approved mechanics remain unchanged,
reuse work item `4ae532e0-6b3c-4e4e-bc56-013aff653f28` only for build
verification, and treat Q02 retirement on frequency as deterministic rather
than a candidate for parameter repair.

No portfolio gate, T_Live manifest, deploy manifest, live setfile, T_Live,
AutoTrading, terminal control, or live state was touched.

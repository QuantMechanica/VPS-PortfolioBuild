# QM5_41243 governed magic precondition

- Router task: `c682e360-2ac3-4b1b-bc02-443ac51e4678`
- EA: `QM5_41243_wti-eia-lag2-fade-m5`
- Approved card: `strategy-seeds/cards/approved/QM5_41243_wti-eia-lag2-fade-m5_card.md`
- Allocator receipt: `docs/ops/evidence/2026-08-31_qm5_41243_governed_magic_precondition.json`
- Allocator receipt SHA-256: `3edfb37787652b1ea081615fb84b288eab2abf18967cdeedee9929e9ed160aa3`

## Verdict

`PASS_ALREADY_ALLOCATED`. The governed allocator ran against the exact approved
card after the router spawn lease expired. It made no registry allocation because
the tuple was already present, and it completed with zero status-aware magic
collisions and no retired-row deletion or revival.

## Exact precondition proof

| Control | Observed value | Result |
|---|---|---|
| EA directory | `framework/EAs/QM5_41243_wti-eia-lag2-fade-m5/` exists | PASS |
| Approved card | `g0_status: APPROVED`; declared symbol `XTIUSD.DWX` | PASS |
| Active identity | `41243,wti-eia-lag2-fade-m5,YE-KARALI-EIA-WTI-LAG2-FADE-M5-2026_S01,active` | PASS |
| Active magic row | `41243,wti-eia-lag2-fade-m5,0,XTIUSD.DWX,412430000,...,active` | PASS |
| Deterministic formula | `41243 * 10000 + 0 = 412430000` | PASS |
| Generated resolver tuple | `(41243, 0, XTIUSD.DWX, 412430000)` | PASS |
| EA-scoped identity rows | exactly 1 active row; no retired row | PASS |
| EA-scoped magic rows | exactly 1 active row; no retired row | PASS |

The resolver proof used the governed allocator's parallel-array parser against
`framework/include/QM/QM_MagicResolver.mqh`, rather than independent token
searches, so slot, symbol, EA ID, and magic were verified as one aligned tuple.

## Idempotence and safety

The allocator receipt records:

- discovery mode `exact_card`, one candidate, and zero findings;
- decision `skip/already_allocated`, one existing row, and registered identity;
- `planned_eas=0`, `planned_identity_rows=0`, and `planned_rows=0`;
- identity registry rows unchanged at 4,743;
- magic registry rows unchanged at 18,147;
- resolver rows unchanged at 18,009;
- zero identity rows added, zero magic rows added, and zero retired rows deleted;
- zero status-aware magic collisions before and after.

This task did not compile or enqueue the EA, run a pipeline phase, start a
terminal, or change live-trading state. Subsequent build progression remains
subject to its own governed review and pipeline evidence.

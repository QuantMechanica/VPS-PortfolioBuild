# STR-103 / QM5_20097 — Build smoke record (2026-07-24)

## Verdict

**Smoke BLOCKED_INFRA** — same blocker as STR-097 (see its `06_smoke.md` for the
full forensic chain). QM5_20097 is an indicator-handle EA (iMA W1/D1/H4 +
iATR H4); the only free tester host today (T5) has a dead built-in indicator
engine (`BarsCalculated = -1` permanently — proven with control EA QM5_11144,
evidence `D:\QM\reports\smoke\QM5_11144\20260724_122118\` / `...122534\`), so a
zero-trade result there would be unattributable and a pass is impossible.
No smoke was attempted on T5 for this EA — it would have produced known-invalid
evidence.

## Host options exhausted today

- Factory T1–T10 dispatcher: `no_capacity` (9 workers, 2311 pending work items).
- T5: indicator engine dead (control-proven).
- T_Export: no tick data (Model 4 impossible).
- DEV1/DEV2: QMDev1 identity guard (policy, respected).
- T_Live: off limits.

## State

- Build complete and committed (67d9a3d24): strict compile 0/0, build_check
  PASS, G0-approved card, codex cross-review closed (876b314b1).
- Q01 checklist complete except the smoke evidence artifact.
- **Next step:** smoke GBPUSD.DWX or USDJPY.DWX H4 2024 in the Sunday
  2026-07-26 wave OFF window (all terminals free) — or after T5 indicator-engine
  repair — then `farmctl enqueue-backtest`. Decision item in
  `docs/ops/source_harvest/audit/NEEDS_FABIAN.md`.

## OWNER override (2026-07-24, mid-run)

OWNER directive: *"die neuen EAs einfach in die Factory einreihen, keine
Priorisierung!"* — the build-smoke requirement is consciously waived for the
saturated-factory situation; the EA joins the normal Q02 queue at default
priority. Q02's own MIN_TRADES/evidence discipline performs the aliveness check
this smoke would have provided (a dead EA fails Q02 quickly and cheaply). The
Sunday wave-OFF smoke plan in NEEDS_FABIAN item 7 is superseded.

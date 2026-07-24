# QM5_20098 — Gate log (build-run close, 2026-07-24)

- Q00/G0: card APPROVED by codex (reciprocal approval; cards_approved store).
- Q01: build complete — strict compile 0/0, build_check PASS, magic rows
  verified (2:XAUUSD/XAGUSD-M15 symbols), sets generated, SPEC.md validated.
- Q02: work items pending in the normal factory queue (default priority per
  OWNER directive 2026-07-24). From here Q02-Q10 run automatically on T1-T10;
  no further build-run involvement. Track via:
  `python tools/strategy_farm/farmctl.py ea-metrics --gate Q02 --latest`

Note: XAGUSD ran Q02 PASS / Q04 FAIL with the pre-fix binary (superseded,
old-binary evidence); XAGUSD Q02 requeued 12:55Z after fix commit 1331c827f —
see docs/ops/evidence/2026-07-24_qm5_20098_xagusd_q02_requeue_tp_fix.md.

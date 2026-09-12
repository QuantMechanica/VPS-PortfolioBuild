# OWNER decision request — recurring monthly tick-refresh pause

Status: **OPEN — no pause or scheduler activation authorized by this card**

The monthly Dukascopy design needs a bounded Factory-OFF window after scratch
P1/P2/P3 completes and only when P3 is 37/37 PASS. The window is required for
the governed T1 import and mutable-year distribution to T2–T10, followed by two
full Variant-A isolation audits. Estimated duration remains 30–60 minutes.

Requested decision for each execution (a standing approval is not assumed):

- exact refresh month and mutable archive year;
- exact start/end UTC window and reviewed implementation commit;
- P3 summary and manifest-update SHA-256 values;
- current `FACTORY_OFF.flag` SHA-256 after clean drain;
- OWNER signature and Claude APPROVED review task/timestamp;
- authority to acquire the shared archive-year writer lock and run only the
  governed T1 import/distribution steps; and
- rollback authority bound to the per-symbol splice/import sidecars.

Until such a receipt exists, keep
`QM_Dukascopy_MonthlyCustomHistoryRefresh` Disabled and
`QM_DUKASCOPY_MONTHLY_REFRESH_ENABLED` unset. The current 2026-09-12 P3 result
is 0/24 and is independently blocking regardless of this card.

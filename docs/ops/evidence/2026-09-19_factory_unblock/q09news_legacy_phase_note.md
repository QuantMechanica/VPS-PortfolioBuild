# Q09_NEWS crash class (2026-09-19 09:35-09:37Z) — legacy storage phase, not a runner bug

Rows with storage phase `Q09_NEWS` (v3 naming, `avoid_terminals` T6-T10) are NOT the v4 NEWS storage phase
(`farmctl.ACTIVE_GATE_MANIFEST.storage_phase_for_role("NEWS","NEWS")`, see the probe in the session log).
They became claimable only because the index reservation lowering (commit cadfb48731) made their RAM class
winnable; the v4 worker then reached the terminal write without evidence (`IntegrityError: terminal work_item
requires evidence_path or EVIDENCE_UNAVAILABLE sentinel`) -> INFRA_FAIL for 13301/10911/13128/10440/11294.
Disposition: the six remaining rows are parked (`Q09_NEWS_RUNNER_CRASH_NO_EVIDENCE_20260919`); ticket c73ed341
should migrate/supersede them with v4 news rows (`q09_news_migration.py` path) instead of "fixing" a runner,
and mark the five INFRA_FAIL rows as legacy-phase evidence (no requeue under the old phase).

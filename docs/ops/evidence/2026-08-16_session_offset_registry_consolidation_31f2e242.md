# Session-offset registry consolidation (task 31f2e242) — data landed, gate does not exist

Date: 2026-08-16

Router task: `31f2e242-45cb-49e4-a720-f40573f7c381` (claude, priority 79),
source: `docs/ops/evidence/2026-08-16_session_offset_registry_measurement_and_xau_reconciliation.md`
(router task `ee0922a7`, APPROVED).

Verdict: `REVIEW — DATA CONSOLIDATED; GATE-ARMING BLOCKED (gate code does not exist)`

## What this task asked for

1. Merge the measured table from `ee0922a7` into a single authoritative
   registry file (two competing draft filenames existed:
   `session_offset_minutes.csv` and `session_entry_offset_minutes.csv`).
2. Flag the 11 unmeasured FX crosses as `INFERRED`, not measured.
3. "Only then arm the relationship gate: refuse a build when declared entry
   grace < symbol offset + margin."
4. Regression: a `grace=5` XAUUSD card must be `REFUSED`.

## What was found before landing anything

Before merging data, I checked the premise of item 3 — that a gate exists
and only needs to be pointed at correct data ("armed"). It does not:

- `tools/strategy_farm/validate_build_guardrails.py` contains no
  `_scan_entry_grace_vs_session_offset`, no `_scan_session_offset_grace`, and
  no `SESSION_OFFSET_REGISTRY_PATH` (checked the current file directly).
- `git grep` for those three names across every commit in the repository's
  full history (`git rev-list --all`) returns zero hits — this code was
  never committed at any point, on any branch, not just missing from HEAD.
- `tools/strategy_farm/tests/test_build_guardrails.py` has no test
  referencing entry-grace or session-offset at all (read in full).
- The design doc cited by both the v1 CSV header and the `ee0922a7` doc,
  `docs/ops/evidence/2026-08-16_entry_grace_session_offset_guardrail.md`,
  does not exist on disk.
- A repo-wide search (`.py`/`.ps1`) for the literal filenames
  `session_offset_minutes.csv` / `session_entry_offset_minutes.csv` matches
  nothing outside the CSV file itself — no code path reads either registry
  file today.

So the `ee0922a7` doc's section-4 claim ("the build-preflight gate code
itself ... already exist[s] on main, commit `905c6c100`") is incorrect.
Commit `905c6c100` is a real commit, but it is the unrelated June 2026
news-staleness/backtest-risk guardrail (`qm_news_stale_max_hours`,
`RISK_FIXED`/`RISK_PERCENT`) — it does not touch entry grace or session
offsets. Two independent prior agent sessions each drafted a registry CSV
that assumes a gate function exists, under two different guessed names,
without either having actually written or found that function. That is the
concrete "hazard" this task itself warned about, just one layer further
back: not only was the registry data wrong, the thing it was meant to feed
was never built.

## What was landed (data only, item 1 + 2 + the applicable part of the
`ee0922a7` merge)

`framework/registry/session_offset_minutes.csv` (chosen as the single
canonical filename — it is the file that already exists on disk; the
alternate name is not referenced by any code, so inventing a second file
would only re-create the "two competing drafts" problem this task exists to
resolve):

- `XAUUSD.DWX` / `XAGUSD.DWX`: corrected from `default_continuous_unverified`
  / `offset=0` to `measured` / `offset=60.0` min, per `ee0922a7` section 2
  (archive-bar modal offset, 99.5%/99.8% consistency) and section 3 (the
  `QM5_20019`/`QM5_20095` H1-anchor precedent does not actually test the
  D1-label defect and is not valid counter-evidence).
- 17 FX pairs with a local intraday export: `default_continuous_unverified`
  → `measured`, `offset=0.0`.
- 11 FX crosses without a local export (`CADJPY`, `CHFJPY`, `EURCAD`,
  `EURCHF`, `EURNZD`, `GBPAUD`, `GBPCAD`, `GBPCHF`, `GBPNZD`, `NZDCHF`,
  `NZDJPY`): `default_continuous_unverified` → `inferred_fx_continuous`,
  `offset=0.0`, explicitly marked not measured (item 2).
- 5 indices (`GDAXI`, `NDX`, `SP500`, `UK100`, `WS30`): filled in from
  `unmeasured_session_break_risk` (blank offset) to `measured` with their
  real archive-bar values (`GDAXI`=210.0 min, others=60.0 min) — outside
  this task's literal ask but part of "the measured table" from `ee0922a7`,
  and leaving known-wrong blanks in a registry file serves no one.
- `XCUUSD.DWX`: left as `unmeasured_session_break_risk` (unchanged; not in
  `dwx_symbol_matrix.csv`, cannot be measured — see the 2026-08-16 XCU
  coverage-trip memory).
- Added a prominent header block stating the gate does not exist yet and
  naming exactly what was checked, so the next reader does not repeat the
  "just needs arming" assumption.

No card, work-item, setfile, or any file outside
`framework/registry/session_offset_minutes.csv` and this evidence doc was
touched. No build was triggered.

## What was NOT done, and why

Item 3 (arm the gate) and item 4 (grace=5 XAUUSD regression) were **not**
attempted. Writing a fail-closed build-refusal function from scratch,
unreviewed, inside an unattended single-pass cycle is not appropriate for a
safety gate that sits in front of the entire build pipeline (currently 809
approved-but-unbuilt cards per `farmctl health`) — a wrong margin/threshold
or a wrong wiring point could silently block or silently fail-open the
entire factory. This needs to be scoped as its own implementation task
(implement `_scan_session_offset_grace`-equivalent in
`validate_build_guardrails.py`, wire into `validate_path`, add the 1 required
+ additional regression cases, get it reviewed) rather than improvised here.

## Recommended next step

Route a new `build_ea`/`infra_repair`-class task (capability: `code`) to
implement the actual gate function against the now-corrected
`framework/registry/session_offset_minutes.csv`, using the rule already
documented in the CSV header (`refuse when declared_grace_minutes <
offset_minutes + margin`, margin TBD by whoever implements it), with the
`grace=5` XAUUSD-refused case as a required regression test. Until that
lands, the registry file is reference data only and provides no actual
build-time protection.

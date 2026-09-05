# Public strategy archive v3: review delivery

Task: `0b895b78-02fe-439d-b5f2-29c121eabf5e`. Disposition: REVIEW. No deployment or publication was performed.

The additive `named_gate_journey_without_metrics` contract supplies public names, deterministic detail slugs, short mechanism descriptions, market/timeframe cells, dates and public Q gate results. The hourly snapshot export, staging and publication path includes `strategy-archive-v3.json`; the existing v2 contract remains available. Website integration remains a separate review task.

The dry run contains **3,399 card revisions**, with **3,368 weak names** and 31 strong names. Revisions are the existing public card identity unit, not distinct EAs, qualified pairs or live approvals. Nine revisions reach the research frontier; this does not contradict the eight-pair release-status projection. Names and stripped descriptions need editorial review before the site switches. Unavailable historical timeframe evidence is explicitly `UNKNOWN`, rather than inferred from a current card.

The producer uses the canonical Q chain and gate-scoped verdict interpretation, including the recorded Q08 Option D policy. It publishes only concluded PASS/FAIL cells; pending states are not turned into results. Backtests describe the public per-symbol/timeframe gate projection, not every private optimization trial. Historical existence of a passing gate is not a release decision or an assertion of current exact-source binding.

The whitelist rejects additional fields, private locators, account and internal identifiers, input names, code expressions, parameters and numeric performance statistics. Summary text is restricted to the public card summary or the first paragraph of SPEC section 1, bounded to sixty words; section 2 is never used. Generic descriptions are used when scrubbing removes all usable copy. Numeric fields are limited to typed public identity/date/timeframe/schema metadata, not strategy metrics.

Verification: **89 focused tests passed** across archive contracts and publication paths. PowerShell parsed all three changed scripts. The complete output passed the production `Test-Json` schema validator and the forbidden-metrics fixture was rejected. The optional Python jsonschema package was absent; no dependency installation was needed.

Review files:

- [Dry-run archive](2026-09-05_archive_v3_dryrun/strategy-archive-v3.json)
- [Twenty samples: five passed, ten failed, five advancing](2026-09-05_archive_v3_dryrun/sample_20.md)
- [Counts and output hash](2026-09-05_archive_v3_dryrun/verification.json)
- [Schema and PowerShell verification](2026-09-05_archive_v3_dryrun/powershell_verification.json)

Implementation: `tools/strategy_farm/website_archive_v3.py`, the existing archive bundle wrapper, the v3 schema, and the three public snapshot scripts. Only canonical board-advisor paths are committed. No source card, verdict, terminal or account setting was changed.

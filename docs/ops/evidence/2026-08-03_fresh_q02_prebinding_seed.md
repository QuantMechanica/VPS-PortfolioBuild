# Governed fresh-Q02 seed for pre-binding rows

**Date:** 2026-08-03

**Router task:** `07f42d86-c6cd-42a5-81a0-f603ac7f472a`

**Authority:** OWNER 2026-08-03, “10440 Requalifikation”

**Reviewer:** Claude

**Disposition:** REVIEW only; no production enqueue was performed by this task.

## Result

`farmctl seed-fresh-q02` now provides the missing append-only entry point for
an exact terminal Q02 row that predates execution-binding capture. It is not a
bypass for binding-era rows: if any historical execution-binding field is
present, the command refuses and directs the operator to the existing guarded
stale-PASS rerun path.

The seed command:

- requires `--expected-current-ex5-sha256` and verifies it against the EX5 in
  the canonical EA directory under `C:/QM/repo`;
- resolves symbol, timeframe and setfile from one exact old work-item ID,
  seals current MQ5, EX5 and setfile hashes into the new payload, and rechecks
  the complete seal immediately before runner spawn;
- requires `RISK_FIXED > 0` and `RISK_PERCENT = 0` in the sealed setfile;
- refuses if the same EA/symbol pair has an open Q02 row, already has a
  terminal result for the current EX5, or was already seeded from the cited
  old row;
- records the requalification reason, old-row ID/status/verdict/update time,
  old-payload hash, and sealed setfile identity; and
- inserts one new pending row under `BEGIN IMMEDIATE`. It never updates the
  cited historical row.

An open Q02 row for another symbol does not block the exact target pair. This
matters here: `QM5_10440/XAUUSD.DWX` has an unrelated pending ablation row,
while `QM5_10440/NDX.DWX` has no open Q02 row.

## QM5_10440 / NDX binding

| Identity | Value |
|---|---|
| Old Q02 row | `5cb043ef-53c3-49b7-ba55-c748b32b9331` (`done/PASS`, unclaimed) |
| Old binding fields present | none of `expected_mq5_sha256`, `expected_ex5_sha256`, `expected_setfile_sha256`, `expected_symbol`, `expected_period`, `expected_expert` |
| Symbol / timeframe | `NDX.DWX` / `H1` |
| Canonical setfile | `C:/QM/repo/framework/EAs/QM5_10440_mql5-ohlc-mtf/sets/QM5_10440_mql5-ohlc-mtf_NDX.DWX_H1_backtest.set` |
| Setfile SHA-256 | `9f85efc8e4c518d47b5fc9a1ed0e51aecff86f814ca3cb8a73b766fb1246c057` |
| MQ5 SHA-256 | `0f22973a0e89166d76c39a5ef3bdaede5f6063ca37166ab9e18c69179a4d513b` |
| Current repo EX5 SHA-256 | `d9e7d5cdc1998aadf649287af6a5c13a854e42cddbda28c5732d03b34b8b70db` |
| Fixed-risk contract | `RISK_FIXED=1000`, `RISK_PERCENT=0` |

The old row's referenced summary is no longer on disk. The new command does
not inherit or authenticate that historical PASS: the row is used only as the
OWNER-cited immutable identity/provenance anchor. The new pending row must
produce fresh pipeline evidence on the sealed current artifacts.

## Exact command for Claude

Run from `C:/QM/repo` after review:

```powershell
python tools/strategy_farm/farmctl.py seed-fresh-q02 `
  --ea QM5_10440 `
  --old-work-item-id 5cb043ef-53c3-49b7-ba55-c748b32b9331 `
  --requal-reason "OWNER 2026-08-03: 10440 Requalifikation on the new calendar-bundle binary" `
  --expected-current-ex5-sha256 d9e7d5cdc1998aadf649287af6a5c13a854e42cddbda28c5732d03b34b8b70db
```

Expected creation identity is exactly `QM5_10440 / NDX.DWX / H1`, using the
setfile and three hashes above. The ordinary governed worker may claim the new
pending row after the command; no terminal is started by the seed command.

## Focused verification

- `python -m py_compile tools/strategy_farm/farmctl.py` — PASS.
- `python -m pytest -q tools/strategy_farm/tests/test_candidate_repair_enqueue.py`
  — `15 passed`.
- `python -m pytest -q tools/strategy_farm/tests/test_farmctl_cascade.py` —
  `22 passed, 4 subtests passed`.
- `python tools/strategy_farm/validate_build_guardrails.py framework/EAs/QM5_10440_mql5-ohlc-mtf`
  — PASS, 208 files checked, no findings, maximum stale-news allowance 336
  hours.
- The exact command above was exercised against a SQLite online-backup copy of
  the live farm state. It created one pending NDX row with the exact bindings,
  fixed-risk values and provenance above; the copied old row was unchanged.
- A final read-only production query found zero fresh-seed rows for the old
  ID, zero `QM5_10440/NDX.DWX` Q02 rows bound to `d9e7...`, and no open NDX
  Q02 row. Production was not mutated.

No pipeline verdict is inferred. No T_Live or AutoTrading state was touched,
no terminal was started manually, and no active T1–T10 run was interrupted.

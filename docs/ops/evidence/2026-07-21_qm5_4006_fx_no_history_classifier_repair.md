# QM5_4006 FX Q02 NO_HISTORY classifier repair

## Scope

- EA: `QM5_4006_fx-session-flow`
- Instrument: `EURUSD.DWX`, M15
- Failed work item: `89e2b33b-b22f-41e8-aafa-6d7f700f0e93`
- Replacement pending work item: `1ec70bea-9ff7-4186-beb5-81b11ade0de1`
- No T_Live or deployment state was touched.

## Diagnosis

The failed work item exhausted generic `summary_missing` retries even though the
T2 tester log recorded the exact run identity and then:

```text
EURUSD.DWX: history synchronization error
```

MT5 build 5833 exported no HTML report for this failure form. The report-missing
branch copied the tester log but did not apply the existing current-run history
classifier, and that classifier only recognized the older `no history data ...
stop testing` form. The result was an avoidable generic retry loop rather than a
deterministic `NO_HISTORY` classification.

## Repair

`run_smoke.ps1` now recognizes `history synchronization error` only when it is
within five log lines of a marker matching the expected symbol and requested
date window. The report-missing path adds `NO_HISTORY_LOG` to both failure hints
and reason classes. Foreign-symbol and wrong-window regression cases remain
rejected.

## Verification

```text
pwsh -NoProfile -File framework/scripts/tests/Test-RunSmokeNoHistoryScope.ps1
PASS Test-RunSmokeNoHistoryScope
```

The distinct replacement Q02 work item was already pending and unclaimed in the
farm DB at repair time, so no duplicate row was inserted.

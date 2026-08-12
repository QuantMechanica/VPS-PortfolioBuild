# QM5_11906 Q02 FX infrastructure recovery — 2026-07-23

## Scope

- EA: `QM5_11906_watthana-candlestick-rsi-stoch-ea-h1`
- Farm repair task: `2b275cc6-da68-407c-ae92-975e602598af`
- Diverse target: `NZDUSD.DWX`
- Failed Q02 work item: `bf0d4fe8-cf98-49e0-ae97-df8139656c5a`

## Diagnosis

The failed Q02 cohort is classified `INFRA_FAIL` with
`summary_missing_retries_exhausted`; it has no strategy verdict or usable MT5
summary. The same failure affected the registered FX basket. This is an
infrastructure/evidence failure, not evidence that the strategy failed Q02.

## Repair and verification

- Refreshed the checked-in EX5 from the current MQ5 source.
- `compile_one.ps1 -Strict`: `PASS`, 0 errors, 0 warnings.
- MQ5 SHA-256:
  `37F58E9B7F4878703AC7C157BFFF31F7933B4B521B077B30C44527261E3F9928`
- Refreshed EX5 SHA-256:
  `2288214B3A9BA1BBA5C29938E414D38F83525EC83C8BAEEBD5E5EBD8E77F72EF`

## Dispatch disposition

At verification time the farm had 9 active backtests. Per the paced-fleet CPU
ceiling, no smoke, Q02 re-enqueue, or dispatch was started. The refreshed,
strict-clean artifact is ready for a later Q02 enqueue when capacity is
available.

No live files, AutoTrading state, portfolio gate, or T_Live manifest were
changed.

# QM5_10999 EURJPY Q02 infrastructure recovery

- UTC date: 2026-07-25
- EA: `QM5_10999_the5ers-outside-bollinger`
- Instrument: `EURJPY.DWX`
- Phase: Q02
- Coordination task: `4fbe0d79-90c1-4511-999d-e1a017c24c2b`
- Source work item: `1bf7f9f1-0035-48cd-b10d-b17b60e06621`
- Replacement work item: `28c67baf-9d3d-47e2-a839-8c40587867ff`

## Diagnosis

The source work item ended `INFRA_FAIL` with
`run_smoke_fail:BARS_ZERO;INCOMPLETE_RUNS`. This was not an EA binary or setfile
binding defect:

- its Q02 prescreen passed;
- the queued EX5, MQ5, and EURJPY setfile hashes still match the current files;
- the prior strict build check was `PASS` with zero failures and zero warnings;
- the full run's terminal log shows three incomplete reports with zero bars, not a
  strategy rejection.

After that run, all factory terminals T1-T10 contained the same refreshed
`EURJPY.DWX` custom-history corpus: 12 files and 195,721,744 bytes per terminal,
with newest write time 2026-07-25 11:21:46Z. The failed work item completed at
2026-07-25 06:24:39Z, so the history refresh post-dates the failure.

## Recovery

One fresh evidence-bound Q02 work item was inserted as `pending`, after a
transactional collision check confirmed there was no pending, active, or launching
Q02 row for this EA and symbol.

Expected hashes:

- EX5: `5994607e2babe0eb76253896309846805fef06e2d7dab29f9c3e5eee54cffacf`
- MQ5: `f95624e27107ce3ef674f338f80c07c057db1cd193caae50e1ef6a8effb333f7`
- setfile: `857e960ddab814ba5c709390bf39b46692ff77fef1e11870ca2ddc7e396bab02`

The replacement retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, H1, and the
2018-07-02 through 2022-12-31 Q02 window. No manual backtest was started.

DB backup immediately before the successful mutation:
`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10999_eurjpy_q02_requeue_20260725T133210Z.sqlite`.

## Safety boundary

No strategy mechanics, live setfiles, T_Live files, AutoTrading state, portfolio
gate, deploy manifest, or live configuration were changed.

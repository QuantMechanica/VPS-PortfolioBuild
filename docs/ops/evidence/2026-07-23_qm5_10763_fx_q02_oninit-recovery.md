# QM5_10763 Q02 infrastructure recovery

- UTC date: 2026-07-23
- EA: `QM5_10763_fx-month-end-rebal`
- Target: `EURUSD.DWX`, H1, Q02
- Farm repair claim: `44b96776-5f7c-4c2f-9c7e-4ece17d0b592`
- Failed work item: `d1306df2-3174-4dab-9f83-2c70d84d6094`

## Diagnosis

The bound Q02 summary classified the run as `ONINIT_FAILED;INCOMPLETE_RUNS`.
Its report was empty (`EMPTY_EXPERT`, `EMPTY_SYMBOL`, `M0_1970_PERIOD`,
`BARS_ZERO`) and no tester log was captured. Execution identity was stable:
the repository and T9 binaries matched SHA-256
`a275b9ad098e874a3d0dc05e80a080f822472cc43221c26a51b66263f3c65374`,
and the source/setfile identities also matched. The EA source carries the
correct `qm_ea_id=10763`, and registry slot 0 maps `EURUSD.DWX` to magic
`107630000`. This is an infrastructure/stale-binary recovery, not a strategy
change.

## Repair

Recompiled the unchanged source against the current V5 includes:

```text
compile_one.result=PASS
compile_one.reason_class=OK
compile_one.errors=0
compile_one.warnings=0
```

Resulting identities:

- MQ5 SHA-256: `897817b88f4ec38dec93ac58068e1b0f24a9cdff7217e2ccf013744431555744`
- refreshed EX5 SHA-256: `541e3c94bc3f37ddc5c2c4bacc201295c3bb5efaafb69ef2920472624a2666c8`
- EURUSD setfile SHA-256: `1caa41991436ac81383221f3b59a012aa36f1762932bcac567b5741075fc9966`

The replacement Q02 work item is evidence-bound to these identities. Dispatch
was intentionally left to the farm because eight backtests were already active,
at the paced-fleet CPU ceiling.

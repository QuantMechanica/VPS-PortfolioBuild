# QM5_41249 WTI Welch Mean-Shift Q02 Enqueue

Date: 2026-08-31

Branch: `agents/board-advisor`

## Outcome

The OWNER commodity/energy mission produced one new, source-approved,
non-duplicate direct-WTI structural sleeve.
`QM5_41249_wti-mwelch-shift-tr` passed source-fresh Q01 compilation and was
enqueued exactly once into Q02 as pending work item
`61aa2e78-4f80-49f3-b4a0-437d013e40d7` for
`XTIUSD.DWX / D1`.

No manual backtest, dispatch tick, live action, portfolio-gate change,
certification claim, or correlation claim was made. Q09 remains the only
authority for realized portfolio overlap.

## Edge and non-duplicate boundary

At the first eligible broker-month transition, the EA reconstructs thirteen
consecutive completed WTI month-end closes and derives twelve adjacent log
returns. The first six form a fixed older sample and the last six a fixed
recent sample. It computes separate unbiased sample variances, then follows
the recent regime only when the unequal-variance standardized mean shift
crosses the inclusive absolute `0.75` boundary and agrees with the sign of
the recent mean.

This is mechanically distinct from the certified long-only two-day XNG
oscillator pullback (`QM5_12567`) and nearby WTI families based on price
ranks, fixed ECDF gaps, label runs, a daily price median, or an endogenous
centered-CUSUM split. The fail-closed preallocation scan found no exact
identity across 4,748 registry rows, 1,386 cards, and 45 Strategy Wiki nodes.

Canonical dedup receipt:
`artifacts/qm5_wti_mwelch_shift_tr_preallocation_dedup_20260831.json`,
SHA-256
`418F80E037B15060AA00B11736783446818B7AAA892B49EF9C9F9A95B0777D67`.

## Source and governance

- Source approval: commit `de569f5f74`.
- EA identity reservation: commit `4a36345998`.
- G0-approved Strategy Card: commit `9ebf96643a`.
- Deterministic slot-zero magic allocation: commit `df3b107660`.
- EA, SPEC, reference fixtures, and fixed-risk preset: commit
  `46d5db73d4`.
- Strict R3 gate-token normalization, with CFD risks retained in reasoning:
  commit `74bb3d6e65`.
- Source-fresh binary and sealed setfile: commit `d130eedab2`.
- Q01 SPEC schema alignment: commit `79c4dcfd1d`.

The bounded source packet combines peer-reviewed WTI time-series-momentum
evidence, Welch's peer-reviewed unequal-variance method record, and complete
official SciPy method documentation. The exact fixed-six-by-six trading
conjunction remains an explicitly pre-result QM translation.

## Q01 evidence

- Governed compile work item:
  `98599793-6a0c-4cd8-b7fd-49e66ed619d0` on T7.
- MetaEditor: PASS, 0 errors, 0 warnings.
- Strict build check: PASS; failure classes empty.
- MQ5 SHA-256:
  `906A3DB918ED7E1E04F8381EF7B1B943557C7458412FA9B803CFE54091D21F9E`.
- EX5 SHA-256:
  `CA62369B54E1559F3FE658ACFBD9D56ADF7A44FDBF94F9B975B5A3DBB7C22905`.
- Compile-evidence SHA-256:
  `39D0B641C332634F84D35F610717F914772892359DED0C6038562F7C2C8EF64F`.
- Final setfile SHA-256:
  `287C95DD5622AA884FCFE35B1C9F01DE6F6081C6AE088D19AB724F42945356F0`.
- P1 artifact validation and SPEC validation: PASS.
- Independent deterministic reference suite: 10/10 PASS.
- Canonical and local cards: schema PASS and byte-identical.

The only backtest preset locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

## Paced Q02 enqueue

The canonical build recorder appended exactly one Q02 row. Immediately after
that atomic auto-enqueue and before any dispatch, the five-sample whole-host
CPU window was `53.4696%`, `51.0615%`, `52.9818%`, `46.1973%`, and
`49.9829%` (average `50.7386%`, maximum `53.4696%`). Every sample was
below the 97% hard ceiling.

Readback:

- work item: `61aa2e78-4f80-49f3-b4a0-437d013e40d7`;
- pending, attempt 0, unclaimed, no verdict;
- symbol / timeframe: `XTIUSD.DWX / D1`;
- setfile:
  `QM5_41249_wti-mwelch-shift-tr_XTIUSD.DWX_D1_backtest.set`;
- one-EA Q02 cohort with priority track enabled;
- custom-history archive admission: ACTIVE, 108 selected rows; and
- no manual dispatch or execution in this session.

## Safety boundary

AutoTrading was not toggled. `T_Live`, its manifest, deploy manifests, the
portfolio gate, portfolio admission, and certification state were untouched.
The artifact establishes a testable crude-oil sleeve, not performance or
realized decorrelation.

Machine-readable receipts:
`artifacts/qm5_41249_build_result_20260831.json` and
`artifacts/qm5_41249_wti_mwelch_shift_tr_q02_enqueue_20260831.json`.

# Q09 REQUAL-8 frequency stop-check and pair 3 governed compile handoff

- Recorded: `2026-08-31`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- Approved manifest: `docs/ops/evidence/2026-08-30_8709bc0f_q09_requal8_manifest.json`
- Manifest SHA-256: `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Canonical branch: `agents/board-advisor`
- Stop-check verdict: **PARENT LINEAGES ARE GENUINELY LOW-FREQUENCY; NO PORT-FIDELITY COLLAPSE; SERIAL PAIR 3 MAY CONTINUE**

## Why the stop-check fired

The first two new-identity Q02 runs both ended with the authentic strategy verdict
`FAIL / MIN_TRADES_NOT_MET`. Each produced four trades in the bounded
`2022-07-01` through `2022-12-31` window against a five-trade floor. This note
does not alter, soften, overwrite, or re-run either verdict. It answers only the
router's required question: whether the repeated one-trade shortfall indicates a
shared port-recipe defect before pair 3 is built.

## Authenticated frequency comparison

| Lineage | Evidence | Window / gate | Trades / floor | Approx. annual rate | Evidence SHA-256 |
|---|---|---|---:|---:|---|
| Port `QM5_41215 / NDX.DWX` | Q02 `3a1feed2-2d5c-4b21-82f8-815e62aa1bc2` | 2022-07-01..2022-12-31 | 4 / 5 | 7.9/year | `e6670b9eca8cf002ddee8320765b4eea096e3e2e6d0589e71a9e929d89dfa9da` |
| Parent `QM5_13128 / NDX.DWX` | Q02 `3eca18b2-de00-417e-bf65-9b782da06593` | 2021-01-01..2022-12-31 | 16 / 10 | 8.0/year | `f0bfd09c2f95bb1ab4e46bdc0ddaebce2f86af18f3be4218ff293ee8289d17e3` |
| Parent `QM5_13128 / NDX.DWX` | Q08 `91a6f7bc-75dc-4e57-82ef-566c6904deb2` | authenticated Q08 baseline | 57 | low-sample classification | `a5ad157cbbd86814533da467dfb765e27d14e15de090184f6d2e581f0c7a7007` |
| Port `QM5_41216 / XAUUSD.DWX` | Q02 `d27038b7-2110-45e0-8a36-ecf116c697d2` | 2022-07-01..2022-12-31 | 4 / 5 | 7.9/year | `cf390f21ccfdba67d875f0a28cf5488d5e6b12e0f9397fe7fe6d385420fe8c2f` |
| Parent `QM5_12989 / XAUUSD.DWX` | Q02 `b0bad5d4-29a1-4b86-873a-38a43112b25a` | 2018-07-02..2022-12-31 | 23 / 25 | 5.1/year | `685b4eae4abd076307134741030a4948b23d8c2fef00b8fd729408a008b62282` |
| Parent `QM5_12989 / XAUUSD.DWX` | Q08 `86abcee3-1e53-4b6d-a576-80fea6e02219` | authenticated Q08 baseline | 43 | structurally low-frequency | `df779904cd9479ee020c663cb3a6109cc68916b2ed1f03ed31d26d22edac3337` |

The pair-1 port reproduces its parent's observed frequency almost exactly:
about eight trades per year in both windows. The pair-2 port's bounded rate is
higher than its parent's later Q02 rate, and that parent itself missed the
then-applicable 25-trade floor with 23 trades. Its authenticated Q08 aggregate
also explicitly classifies multiple sub-gates as low-sample/structurally
low-frequency.

Therefore the repeated `4 versus 5` outcome is consistent with the two selected
parents' genuine low frequency and the bounded half-year Q02 window. It is not
evidence that the common requalification port recipe reduced entries toward
zero. No entry, timeframe, session, or filter repair is authorized by this
diagnosis. The two existing Q02 failures remain pipeline truth.

## Pair 3 preflight

The serial continuation is manifest row 3:

- parent: `QM5_10815_tv-post-vwap`, `GDAXI.DWX`, `H1`;
- authentic anchor: `c7845c62-6c35-49eb-8e9f-056af2c6c14e` (`Q09 PASS`);
- reserved successor: `QM5_41217_tv-post-vwap-requal8`;
- build task: `b958b565-e847-49e1-8ec9-6575f67b0d7f`, read-only verified `pending`;
- recovery card: `D:/QM/strategy_farm/artifacts/cards_review/QM5_41217_tv-post-vwap-requal8.md`, `g0_status: APPROVED`;
- active EA registry row: `41217,tv-post-vwap-requal8`;
- active magic row: slot `0`, `GDAXI.DWX`, magic `412170000`;
- `GDAXI.DWX` is an exact member of `dwx_symbol_matrix.csv`.

The pair-3 source is a faithful H1 port of the approved parent mechanics. The
strategy inputs, absorption/reclaim rules, VWAP target, ATR-buffered/capped stop,
session filter, no-pyramiding rule, opposite-signal exit, and 12-H1-bar time stop
are preserved. Framework-only hardening is explicit:

- `QM_FrameworkTrackOpenPositionMae()` is the first `OnTick` statement;
- Friday close, open-position management, and strategy exits execute before the
  entry-only news gate;
- `QM_EntryRequest` is zero-initialized;
- the bounded H1 `CopyRates` path proves every dynamic array index against
  `ArraySize` and remains behind the single framework new-bar gate;
- zero `.DWX` spread is not rejected;
- `qm_news_stale_max_hours` remains exactly `336`;
- backtest risk remains `RISK_FIXED=1000`, `RISK_PERCENT=0`.

Task-local artifacts before governed compile:

| Artifact | SHA-256 |
|---|---|
| `framework/EAs/QM5_41217_tv-post-vwap-requal8/QM5_41217_tv-post-vwap-requal8.mq5` | `7ce436082f36df9924ec2d50bb39b05261507e52203bf255a3cbe10522e5c07e` |
| `framework/EAs/QM5_41217_tv-post-vwap-requal8/SPEC.md` | `98a8d12f5a535977c18b9c409da993c4fd7ebc3a796567cde7bf712f299bbe6c` |
| `framework/EAs/QM5_41217_tv-post-vwap-requal8/sets/QM5_41217_tv-post-vwap-requal8_GDAXI.DWX_H1_backtest.set` | `edfe8d78934f266240964df997514f9e6d5b2fee9ae6e318f9dd01b73d9d311d` |

## Focused static verification

- `validate_spec_doc.py`: `PASS`, one pass and zero failures.
- `validate_build_guardrails.py`: `PASS` for both MQ5 and setfile, zero
  findings, maximum news staleness `336`.
- `build_gate_hardening.py`: zero failures. The three warnings are the normal
  card-discovery undecidable warnings because the approved recovery card lives
  in the runtime `cards_review` reservoir rather than the canonical EA folder.
- Parent-to-port diff: all strategy defaults and executable trade mechanics are
  preserved; differences are identity, H1 binding, local series bounds, and
  current framework safety wiring.
- `git diff --check`: clean for the pair-3 path.

`build_check.ps1`, `compile_one.ps1`, and `run_smoke.ps1` were deliberately not
invoked. Under this OWNER task, compile is permitted only through the governed
`COMPILE_EA` queue, and no terminal may be started or tester work interrupted.

## Governed compile boundary

The first enqueue attempt supplied the ops source-repair authority. It was
correctly refused with `SIBLING_REBIND_CURRENT_SETFILE_MISSING` because that
flag selects the append-only repair-sibling contract; the refusal created zero
work items and changed no artifact. Pair 3 is a first compile, not a source-hash
repair successor.

The ordinary new-build enqueue, explicitly bound to build task
`b958b565-e847-49e1-8ec9-6575f67b0d7f`, then created exactly one governed row:

| Field | Value |
|---|---|
| Compile work item | `24ab1d53-bff1-493c-a59b-eef83ab732f7` |
| Utility | `COMPILE_EA` |
| Status / attempt | `pending` / `0` |
| Activation hold | `COMPILE_EA_WORKER_ROLLOUT_PENDING` |
| Compiled / failed | `false` / `false` |
| Verdict / evidence | `NULL` / `NULL` |
| Build-task binding | `b958b565-e847-49e1-8ec9-6575f67b0d7f` |

`farmctl.py compile-status QM5_41217_tv-post-vwap-requal8` immediately
reconfirmed one pending, activation-held row and zero active, compiled, or
failed rows. Source, SPEC, and setfile hashes were unchanged by enqueue. The
scheduled pump had already committed those exact bytes in `d127fef4cc`; this
receipt was committed independently with an explicit evidence-file pathspec.

No EX5, compile verdict, smoke result, build-review verdict, Q02 seed, pair-3
hold release, or pipeline verdict is claimed by this compile-queue checkpoint.
Pairs 4-8 remain untouched. The protected `QM5_41162 OPT_CENSUS` program and
all T1-T10 activity remain untouched.

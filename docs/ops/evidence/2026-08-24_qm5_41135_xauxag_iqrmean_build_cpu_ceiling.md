# QM5_41135 XAU/XAG interquartile-mean build and CPU-ceiling handoff

Date: 2026-08-24

Branch: `agents/board-advisor`

Verdict: `SOURCE_READY_COMPILE_NOT_ENQUEUED_CPU_CEILING`

## Delivered commodity sleeve

`QM5_41135_xauxag-mdaily-iqrmean-rv` is a new two-leg XAU/XAG D1
market-neutral-style sleeve under strategy ID
`SCHWEIKERT-CME-XAUXAG-MDAILY-IQRMEAN-RV-2026_S01`. It is mechanically
distinct from the certified directional XAU/SP500/NDX/XNG book and from
existing fitted ratio/OLS/MAD crossings, sign breadth, fixed calendar blocks,
path quotients, daily persistence, outright WTI robust-location momentum, and
`QM5_12567` XNG cumulative-RSI logic.

At the first synchronized executable D1 bar of a broker month, the EA rebuilds
the immediately completed 17-23-session month plus one older boundary pair.
It forms every chronological gold-minus-silver log-ratio return ending in the
month, verifies endpoint identity, sorts the full sample, removes
`floor(n/4)` returns from each tail, and fades the arithmetic mean of the
exact 9-13 retained observations. The raw endpoint is diagnostic only.

The implementation is low-frequency and fixed-risk:

- exact `XAUUSD.DWX` host and `XAGUSD.DWX` companion on D1;
- one consumed attempt and at most one atomic two-leg package per broker month;
- equal target absolute notionals with no more than 20% realized mismatch;
- aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`;
- frozen `3.5*ATR(20,D1)` stops, no targets, and first-later-month exit;
- news axes and Friday close OFF;
- no optimization, ML, banned signal indicator, external feed, live, demo,
  shadow, or stress preset.

The bounded source packet preserves Schweikert (2018), *Journal of Banking &
Finance* 88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, plus the official
CME gold/silver intermarket-spread carrier. The central-band estimator and
contrarian direction are explicitly untested QM translations; no source
performance or neutrality result is imported.

## Identity and commits

- EA ID: `41135`
- slug: `xauxag-mdaily-iqrmean-rv`
- host magic: `411350000`
- companion magic: `411350001`
- source approval: `2afaad159`
- bounded source packet: `c488b9c07`
- identity reservation: `c56a69aa0`
- G0-approved card: `dc11f98a4`
- EA, spec, reference suite, card copy, manifest, and fixed-risk setfiles:
  `51fbbfd190b545588336b5e26cdc8f9736c141bb`
- canonical pending set-binding correction:
  `889d248cd6bb299ce7c69c45053be60ae2059ff9`
- MQ5 SHA-256:
  `4AB2F54163C06B57C130D7E067C3BFBA02F6B057A4683A4B832266BB7D5D17DE`

The EA-ID and both magic rows are active, and the generated resolver contains
`411350000` and `411350001`.

## Verification completed

- approved-card schema lint: PASS, no missing sections and no ML hits;
- deterministic Python reference suite: PASS, 9/9;
- `validate_spec_doc.py`: PASS, 1/1;
- `validate_build_guardrails.py`: PASS for MQ5 and logical setfile;
- `validate_symbol_scope.py --fail-on-leak`: `BASKET_OK`, zero violations;
- governed build preflight: registry row, two magic rows, and EA directory PASS;
- package whitespace audit: PASS;
- local build card copy matches the approved card modulo terminal newline.

## Compile and Q02 boundary

The direct strict build check stopped at
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because factory terminals were alive and
correctly directed this build to the governed compile queue. No bypass or
manual compile was attempted.

The first governed queue preflight treated 64 zeroes in the provisional
`build_hash` headers as sealed bindings and refused before mutation with
`BOUND_SETFILE_HASH_EXISTS`. The headers were corrected to the canonical
`pending` marker and committed. Subsequent exact enqueue attempts encountered
the live farm writer's SQLite lock. The lock was not bypassed; a read-only
exact EA query remained empty. No compile work item or EX5 exists.

A fresh five-sample host observation then returned
`94.6, 93.4, 86.0, 98.2, 100.0` percent CPU (average 94.4%, maximum 100.0%).
The maximum breached `CPU_MAX_LOAD_PERCENT=97.0`; the configured resume
threshold is 90.0%. The mission explicitly requires stopping at the backtest
CPU ceiling, so compile retries and Q02 enqueue stopped.

Machine-readable evidence:
`artifacts/qm5_41135_cpu_ceiling_20260824.json`.

## Governed continuation

After sustained recovery below the configured 90% resume threshold, enqueue
one source-fresh governed compile for the exact EA. Only strict `COMPILE_OK`
with a bound EX5 hash permits build review and one logical Q02 enqueue using
`QM5_41135_XAU_XAG_MDAILY_IQRMEAN_RV_D1` and the committed D1
`RISK_FIXED` preset.

No portfolio gate, `T_Live` manifest, `T_Live` file, AutoTrading state, live
preset, gate threshold, existing EA, terminal process, or verdict was changed.

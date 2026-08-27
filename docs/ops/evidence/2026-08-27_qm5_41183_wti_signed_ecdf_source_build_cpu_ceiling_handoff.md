# QM5_41183 WTI Signed-ECDF Source Build — CPU-Ceiling Handoff

Date: 2026-08-27

Branch: `agents/board-advisor`

EA: `QM5_41183_wti-mks-shift-tr`

Verdict: `SOURCE_BUILD_COMMITTED_Q01_DEFERRED_CPU_CEILING`

Q02: `NOT_ENQUEUED_CPU_CEILING`

## Outcome

One new direct-WTI structural edge was sourced, approved, registered, and
mechanized as an MQL5 source build. The rule compares fixed older/newer blocks
of six completed monthly closes and continues only a dominant signed ECDF
count gap of at least three. It is distinct from the adjacent Mann-Whitney,
Pettitt, Mann-Kendall, Spearman, median-runs, and certified XNG pullback
mechanics documented by the approved card and dedup receipt.

The exact `XTIUSD.DWX` D1 slot-zero identity is active at magic `411830000`.
The only preset is a fixed-risk backtest preset with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No live/demo/shadow/stress or
optimization preset exists.

## Deterministic Validation Completed

- Card schema/prohibited-token lint: `PASS`; zero ML hits and zero missing
  sections.
- Pure reference suite: `PASS`, 10/10 tests.
- Exact assignment enumeration: 924 total states, 218 BUY, 218 SELL, 488 flat.
- Boundary checks: inclusive gap three, reflected SELL symmetry, tied maximum
  flat, strict ties fail closed.
- Non-duplicate fixtures: one KS BUY at `(3,2)` with Mann-Whitney `U_new=23`,
  and one KS flat at `(2,0)` with Mann-Whitney `U_new=26`.
- Card copy, setfile locks, active magic row, and single resolver occurrence:
  verified by the reference suite.

Relevant hashes:

- EA source: `CE733FD5F37CFF2EA19FB88758FDBDBFF16142C4CAFEF4F9D10684B430C24FD1`
- backtest set: `CFB478C2537C3045C7F1A9D39AE11EDF56BB47CC4ABF548AC130CF82C46DD38A`
- reference suite: `A9D6AFE8F8E07193C8CC17D14B61363203216CF8471DFEA2F33F9F7C1D972DFD`
- magic registry/resolver binding:
  `CD79B8FB581F86896C2873ABDFF043919E89DE26953A82244263CE597FA3F1E3`

## Strict Compile Boundary

The requested strict wrapper was invoked once:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File \
  framework/scripts/compile_one.ps1 \
  -EAPath framework/EAs/QM5_41183_wti-mks-shift-tr/QM5_41183_wti-mks-shift-tr.mq5 \
  -Strict
```

It returned `INCLUDE_MIRROR_REFUSED` /
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because `terminal64` processes were
alive. This was a pre-compiler governance refusal: MetaEditor did not compile
the EA, no retry occurred, and this is not represented as an MQL compile
failure or Q01 pass.

## Explicit CPU Stop

The immediately following governed fleet snapshot at
`2026-08-27T13:19:55Z` showed:

- host processor load: **100%** across 16 logical processors;
- active governed tester terminals: `T3`, `T6`, `T7`, and `T10`;
- six `terminal64` processes in total, including the two non-pipeline
  terminals reported by `farmctl mt5-slots`.

That meets the OWNER instruction to stop at the backtest CPU ceiling. No
governed compile item and no Q02 item were enqueued. No tester, terminal,
AutoTrading state, `T_Live`, live manifest, or portfolio gate was touched.

Machine-readable receipt:
`artifacts/qm5_41183_q01_cpu_ceiling_handoff_20260827.json`.

## Safe Resume

After host load falls below the governed ceiling:

1. enqueue exactly one governed compile for
   `QM5_41183_wti-mks-shift-tr`;
2. require strict zero-error/zero-warning Q01 and framework build-check PASS;
3. re-check tester and host CPU capacity; and
4. enqueue exactly one Q02 baseline only if both ceilings allow it.

Q02 remains the first market-data result. Q09 alone may establish realized
portfolio decorrelation; this handoff claims neither certification nor
portfolio admission.

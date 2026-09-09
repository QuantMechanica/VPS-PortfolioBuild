# QM5_41389 XAU/XAG Block-Median Reversion — Build And Q02 CPU Stop

## Outcome

`QM5_41389_xauxag-blockmed-rv` is a new approved and committed low-frequency
market-neutral-style commodity sleeve. It forms twelve synchronized completed
monthly gold/silver log-ratio changes, partitions four chronological blocks of
three, and fades the even median of the four block means with opposed XAU/XAG
legs. The source/card, deterministic two-slot allocation, EA, logical basket
manifest, fixed-risk presets, and reference fixtures are committed.

The mandatory PACER audit passed with zero findings. Nine independent
reference tests passed. A governed compile row was enqueued and its exact
source-fresh activation hold was released, but at stop readback it remained
pending and unclaimed with no EX5, build-check result, or verdict.

## Source And Non-Duplicate Boundary

The reputable-source chain binds Schweikert (2018), *Journal of Banking &
Finance* 88, DOI `10.1016/j.jbankfin.2017.11.010`; CME Group's Gold & Silver
Ratio Spread; and the complete-read Moskowitz/Ooi/Pedersen monthly/block
arithmetic lineage. No source efficacy transfers to this exact conjunction.

Search and manual review found no prior XAU/XAG four-by-three chronological
block-median identity. `QM5_20287` trades the statistic as outright WTI
continuation; existing XAU/XAG systems use different state functionals. The
ratio-change carrier, opposed legs, contrarian direction, fixed blocks, and
even median are jointly load-bearing. Q09 alone owns realized correlation.

## Build And Guard Evidence

- Source/card commit: `12966387a6`.
- Allocation commit: `2f9b4c76e8`.
- EA source auto-commit: `041bc8167a`.
- Build artifact commit: `661bd67ab7`.
- EA ID/magics: `QM5_41389`; XAU slot 0 `413890000`; XAG slot 1 `413890001`.
- Source SHA-256:
  `0e8a7dbc6cc02578fc74a475c49649345c563fb9c57c6ef58c6be562c241a9df`.
- PACER audit: exit 0, `ok=true`, `hit_count=0`, empty findings.
- Reference vectors: 9 tests, PASS.
- Card schema lint and G0 lint: PASS; prohibited-ML hits 0.
- Backtest presets: D1, `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The guard does not compare RNG, news, or Friday inputs. Stress probability is
checked only for finiteness and inclusive 0..1 range.

## Governed Compile State

- Work item: `48408a93-4f2d-4615-9b54-fb8738721ab8`.
- Current state at stop: pending, unclaimed, activation hold released.
- Current/queued source hashes matched at release.
- No `.ex5`, compile verdict, evidence path, or setfile binding exists.
- The direct compiler and direct build-check paths were refused by the live
  factory guard; no manual terminal action occurred.

## Binding CPU Stop

Five one-second whole-host samples at `2026-09-09T03:22:07.8389084Z` were
`100.0%`, `99.9%`, `97.8%`, `99.8%`, and `99.9%`. Average CPU was `99.5%` and
maximum CPU was `100.0%`. Admission requires both values strictly below 97%,
so Q02 was not enqueued and no backtest was launched.

A later paced wake must first resolve the pending compile row to a source-
matched `COMPILE_OK`, then obtain a fresh passing CPU window before invoking
canonical first-Q02 intake exactly once.

Machine-readable evidence:
`artifacts/qm5_41389_compile_q02_cpu_stop_20260909.json`,
`artifacts/qm5_41389_compile_release_dry_run_20260909.json`, and
`artifacts/qm5_41389_compile_release_apply_20260909.json`.

## Safety Boundary

No Q02 work item was created. The portfolio gate, `T_Live`, live manifest,
AutoTrading, deployment state, and live-use surfaces were not touched.


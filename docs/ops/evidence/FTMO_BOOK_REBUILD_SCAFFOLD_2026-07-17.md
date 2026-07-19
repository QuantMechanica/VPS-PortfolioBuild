# FTMO Book Rebuild Scaffold - 2026-07-17

## Status

**RESEARCH ONLY / NO GO.** A new fail-closed FTMO candidate-book scaffold now
exists, but no paid Challenge, Free Trial, preset generation, terminal change, or
deployment is authorized. The old Round25 twelve-sleeve composition is not carried
forward.

The current strict inventory contains 144 candidates and zero
`CHALLENGE_READY` candidates. The new book therefore has one research anchor and
zero admitted sleeves:

- research anchor: `QM5_12969 / USDJPY.DWX / M30`
- admitted/ready sleeves: `0`
- nominal research risk recorded by the readiness gate: `$250` (`0.25%` of a
  `$100,000` account)
- readiness verdict: `NO_GO`

Primary machine-readable artifacts:

- `artifacts/ftmo_rebuild_2026-07-17/qualification_inventory.json`
- `artifacts/ftmo_rebuild_2026-07-17/candidate_book_manifest.json`
- `artifacts/ftmo_rebuild_2026-07-17/candidate_book_readiness.json`

## What was built

### Candidate-manifest-aware readiness gate

`tools/strategy_farm/portfolio/ftmo_book_readiness.py` now accepts
`--book-manifest`. This prevents a candidate rebuild from silently evaluating the
installed Round25 presets through `ftmo_phase1_mae.load_ftmo_book()`.

The default remains backwards-compatible: when `--book-manifest` is omitted, the
installed Round25 preset inventory is evaluated. Candidate manifests are validated
fail-closed for:

- a top-level `sleeves` list;
- valid EA id and non-empty symbol;
- positive `risk_fixed` or `base_risk_fixed`;
- duplicate `(ea_id, symbol)` rejection;
- an empty scaffold remaining `NO_GO` rather than vacuously `READY`.

The exact candidate check was:

```powershell
python tools/strategy_farm/portfolio/ftmo_book_readiness.py `
  --qualification artifacts/ftmo_rebuild_2026-07-17/qualification_inventory.json `
  --reconciliation artifacts/ftmo_12969_current_q08_stream_reconciliation_2026-07-13.json `
  --book-manifest artifacts/ftmo_rebuild_2026-07-17/candidate_book_manifest.json `
  --out artifacts/ftmo_rebuild_2026-07-17/candidate_book_readiness.json
```

Expected result: exit `2`, `status=NO_GO`, `ready_count=0/1`, stream
reconciliation `PASS=1/1`.

### Research anchor

`QM5_12969` is the strongest existing lead, not an admitted sleeve. Evidence:

- current FTMO-cost reconstruction: 331 trades, PF `1.414946`, net `$8,689.94`,
  close-to-close DD `$1,603.00`;
- exact Q08 report/stream reconciliation: `PASS`, 331/331 trades, net delta `0`;
- isolated external Q10 artifact: `PASS`, PF `1.54`, DD `2.016%`;
- Q08 remains `FAIL_SOFT`: seasonal October loss, PBO evidence missing/invalid,
  and negative low-volatility regime;
- the strict inventory additionally rejects older phase evidence after the current
  binary build and does not treat the external Q10 artifact as an ingested DB pass.

Therefore its manifest role is `RESEARCH_ANCHOR_ONLY`, with `deployment_allowed=false`.

### New structural build seed

`QM5_20004_turn-of-month-index-long` is the first new structural seed for the
rebuild: a D1 DE40/NDX turn-of-month calendar-flow strategy. The Strategy Card is
`APPROVED`, its EA id is registered, and build task
`9ceb802d-1d43-4140-ae45-1874dfb79b16` is pending in the canonical factory queue.

No duplicate manual build was started. At this snapshot the EA directory, magic
rows, `.mq5`, `.ex5`, setfiles, and pipeline evidence do not yet exist. The normal
build order must create the directory first, append and regenerate the magic
registry, compile strictly, and only then let the factory enqueue Q02. It cannot
enter the book before the complete hard gate chain passes.

## Candidate disposition

| Candidate | Current disposition | Primary blocker |
|---|---|---|
| `12969 USDJPY M30` | research anchor | Q08 `FAIL_SOFT`; current-evidence rebind incomplete |
| `20004 DE40/NDX D1` | build queue | card only; no EA or pipeline evidence yet |
| `10377 XAU D1` | requalification queue | Q08 soft/invalid plus incomplete D1 lineage |
| `12567 XAU D1` | requalification queue | Q08/PBO plus current identity repair open |
| `12474 GBPUSD M1` | requalification queue | chopping PF `0.832` after top-trade removal |
| `10939 GBPUSD H4` | requalification queue | current-cost annual-frequency failure |
| `13301 GDAXI M5` | excluded | Q08 chop/regime failures, Q09 reject, excessive DD |

The Round25 live-trial loss leaders `10911`, `10848`, and `10847` are explicitly
excluded from carry-forward. All twelve old sleeves require a complete fresh
qualification before reconsideration.

## Risk contract

The scaffold records the FTMO audit's survival-first design ranges, not deployment
approvals:

- `0.25-0.50%` initial risk per genuinely independent idea;
- `1.0%` universal hard cap per idea; the old multiplier-25 frontier is not
  eligible for promotion because individual sleeves exceeded this newer cap;
- `1.5-2.0%` internal daily stop;
- `6-7%` internal total stop;
- correlated-exposure caps derived from synchronized joint MAE before release;
- no risk increase while any admission gate is incomplete.

No portfolio simulation was run on the one-sleeve scaffold. A one-sleeve anchor
with Q08 `FAIL_SOFT` is not a book and is not allowed to open a sealed optimization
or holdout gate.

## Remaining decision-grade blockers

1. The current farm has zero Q08 `PASS` candidates. `FAIL_SOFT`, invalid PBO, or
   research-rescue states cannot become FTMO admissions.
2. The joint-equity capture specification is not yet implemented end-to-end in the
   MQL framework. The existing evaluator and the specification use different raw
   timestamp/anchor contracts, and a capture-to-normalize/combine runner is absent.
3. Existing M15 bar simulation remains research decision support; it cannot prove
   tick ordering or exact FTMO broker co-movement. H1-forward-filled proxies must
   not feed a paid-quality decision.
4. The historical 2024-2025 segment has already been opened repeatedly during the
   prior frontier work. For a new book it is selection-contaminated confirmation,
   not an untouched holdout. The final independent gate must be a predeclared fresh
   forward/Free-Trial burn-in.
5. The persistent, book-scoped FTMO kill switch and exact CE(S)T day anchor still
   require end-to-end proof before any Free Trial or paid Challenge.
6. The generic farm Q02 contract and the stricter FTMO current-binary Q02 binding
   are not yet one phase contract. Until that drift is resolved, a generic DB
   `Q02=PASS` is insufficient; the FTMO-specific two-run binding remains mandatory.

## Verification

Focused and downstream FTMO unit suite:

```text
87 passed
```

The suite covers stream reconciliation, current-binary binding, strict
qualification, candidate-book readiness, joint equity, joint-bar simulation,
governor simulation/policy, and governor wiring. One stale test expectation was
corrected from 100 trades to the fixture's explicit 201-trade Q02 contract.

All three generated JSON artifacts parse successfully. The readiness command
returns the expected fail-closed exit code `2`.

## Operational boundary

- installed FTMO terminal touched: **no**
- T_Live touched: **no**
- AutoTrading changed: **no**
- FTMO presets/setfiles created: **no**
- deploy manifest created: **no**
- live or trial positions changed: **no**

## Next gate

1. Let the canonical queue build and strictly compile `QM5_20004`; do not duplicate
   its existing task.
2. Complete the active Q08 neighborhood/PBO tooling repair, then rerun and fully
   rebind `QM5_12969` against the current binary. Q08 must become a real `PASS`.
3. Re-run the candidate readiness artifact. No joint optimization starts before at
   least two independently qualified sleeves exist.
4. Implement and review the joint-capture/normalization chain before normal/adverse
   governor evidence can become decision-grade.
5. Only after a complete `READY` book: generate staging presets, prove the book-wide
   kill switch, and run a fresh predeclared Free Trial. Paid Challenge remains a
   separate OWNER-signed decision.

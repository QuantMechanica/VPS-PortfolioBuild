# DXZ-Q6 qualification book design — 2026-07-16

Status: **DESIGN LOCK / NOT YET QUALIFIED / ZERO ACTIVE RISK / NO DEPLOYMENT**

Expansion note: Q6 is now the frozen comparison benchmark, not the intended
return-book endpoint. The governed Q8 repair path is defined in
`docs/ops/DXZ_Q8_EXPANSION_REPAIR_WORKORDER_2026-07-16.md`; neither proposed
extension is admitted yet.

Machine-readable contract:
`docs/ops/evidence/dxz_q6_qualification_design_20260716.json`

## Decision

The proposed replacement for the undifferentiated DXZ-23 draft is a six-sleeve
qualification book:

| Sleeve | Driver | Current diagnostic evidence | Open decision or repair |
|---|---|---:|---|
| `10476 USDCAD H1` | oscillator/regime | 299 trades, PF 1.260 | continuous-segment rebase, full identity, Friday contract, five cost axes |
| `10513 XAUUSD D1` | Ichimoku trend | 104 trades, PF 1.958 | approve and bind the `18/6/18/68` variant, then requalify |
| `10706 GBPUSD H1` | weekly Monday long/short | 367 trades, PF 1.329 | percent-risk/EUR reference, runtime ordering, session flattening, full identity and costs |
| `11708 EURUSD D1` | daily squeeze | 178 trades, PF 1.320 | repair the contradictory/incomplete approved Card and Friday contract |
| `12969 USDJPY M30` | Gotobi/Nakane calendar | 331 trades, PF 1.545 | decide Card no-stop versus the exercised 120-pip stop, then requalify |
| `13128 NDX H1` | pre-FOMC event drift | 56 trades, PF 2.260 | synchronize the 2025/2026 calendar across Card, source and binary |

These are not six live approvals. They are the exact six rows that the new
qualification attempt must either prove together or reject. Today every row has
active risk zero.

## Why these six

The selection starts with the already frozen earlier-window rule, not the later
results:

1. Training window `2018-07-01` through `2022-12-31`.
2. At least 20 completed round trips.
3. Conservative commission-adjusted training PF at least 1.10.
4. Absolute monthly zero-filled correlation at most 0.30 on that locked window.
5. No known economic reject, missing native report or unresolved basket identity.
6. One economically distinct mechanism per seat.

All six passed the earlier-window selector. Their largest diagnostic pairwise
absolute training correlation is approximately 0.277. The six current native
reports contain 1,335 standalone trades. Those figures are triage evidence, not
qualification receipts.

The already viewed 2023-2025 period is now development/validation evidence. It
cannot be advertised as untouched confirmation after this redesign. The final
gate therefore requires newly sealed continuous-segment tests and a prospective
shadow period.

## What is deliberately not in the book

- `10939 GBPUSD H4` is an alternative to `10706`, not an additional seat: their
  locked-window absolute correlation is approximately 0.325, above the existing
  0.30 gate.
- `12567 XNGUSD D1` is the first growth candidate after its entry threshold 30 is
  approved and qualified as a named Card variant. It is not silently inherited.
- `1556 XAUUSD D1` is the XAU alternative if its Friday close versus monthly source
  exit is resolved by a predeclared ablation.
- `12567 XAUUSD D1` failed the locked training selector at PF 0.90. Its strong later
  period cannot be used for ex-post promotion.
- `10919 XTIUSD H4` has only 30 native trades over the available long history and
  does not satisfy the ratified five-trades-per-year floor.
- The known economic/technical reject rows (`10440`, `10692`, `10715`, `10911`,
  `11165 EURUSD`) receive no portfolio-compensation exception.
- `10403`, `11132`, `12778` and the remaining semantic/lineage cases stay outside
  until their strategy identity is unambiguous; high PF alone is irrelevant.

No reserve is substituted automatically. Losing one seat means a new frozen book,
new portfolio computation and new OWNER review.

## Risk contract

The historical 19.62% sum-risk table is not carried forward. It was computed from
the superseded 23-sleeve evidence and is explicitly non-reproduced under the new
freeze-gated resize path.

The qualification design uses two stages:

| Stage | Per sleeve | Total | Status |
|---|---:|---:|---|
| today | 0% | 0% | mandatory; nothing is qualified |
| qualification harness | 0.3333% | 2.0% | proposed sealed test contract |
| conditional initial book | at most 0.50% | at most 3.0% | proposal; only after synchronized MTM/margin/gap/cost PASS and OWNER review |

The 3.0% ceiling does not replace the OWNER-ratified universal 1% cap; it is more
conservative. A later resize may target the OWNER's just-under-10% historical DD
objective only from qualified synchronized mark-to-market streams. It may never
raise a sleeve, EA, strategy or symbol above 1%.

Every preset and manifest uses exactly:

```text
RISK_PERCENT      = absolute allocated account-risk percentage
PORTFOLIO_WEIGHT  = 1.0
RISK_FIXED        = 0 for live/as-live percentage-risk qualification
```

Development backtests continue to use `RISK_FIXED`; the explicit as-live
qualification run additionally proves percent-risk behavior, lot rounding and
minimum-lot effects.

No missing sleeve's risk is redistributed. A failed or unresolved row stays at
zero and invalidates the six-row book candidate.

### Diagnostic scale check only

Linear normalization of the current commission-adjusted 2023-2025 exit events to
equal commanded risk gives:

| Sum risk | Exit-only net | Exit-event DD | Worst close day |
|---:|---:|---:|---:|
| 2.0% | +19.58% | 6.87% | -1.84% |
| 3.0% | +29.38% | 10.30% | -2.76% |

This is not a portfolio PASS. It omits floating P&L, simultaneous MAE, margin,
gaps, current spread/swap parity, slippage and Risk Engine intervention. It merely
shows why blindly restoring 19.62% is indefensible and why 3.0% is an upper bound,
not an automatic allocation.

## Qualification contract

### Q0 — Close strategy semantics

Before any book run:

- approve a complete Card-v2 for every exact variant;
- make mandatory no-weekend risk reduction execute before any news/entry return;
- use a session-aware holiday/early-close cutoff and prohibit post-cutoff entry;
- resolve the `12969` stop and `13128` calendar contradictions;
- remove ineffective legacy preset keys rather than treating them as controls;
- make every `(EA, symbol)` execution contract `ELIGIBLE`.

The contract must be sleeve-specific. An EA-level record may not let one symbol's
open issue silently block or clear another symbol's variant.

### Q1 — Freeze the exact source book

Create a new six-row source manifest binding:

- APPROVED Card, MQ5, include closure and clean EX5 hashes;
- exact magic, `.DWX` test symbol and broker routing;
- exact live preset hash and the risk contract above;
- sealed continuous-segment reference streams;
- commission, historical tester spread, current broker spread parity, current
  broker swap parity and adverse-slippage stress evidence.

The source manifest is sealed before testing and must not carry any KPI from the
old draft.

### Q2 — Reproduce twice

Run two independent complete schema-v2 `AS_LIVE_REQUAL` sweeps in isolated
`DXZ_Truth_*` roots. Both must finish:

```text
scope                 = FULL
status                = PASS
qualification_mode    = AS_LIVE_REQUAL
qualification_status  = QUALIFIED
counts                 = PASS: 6
execution costs        = CERTIFIED on all five axes
```

Signal identity and outcome-sign identity must both be non-empty. Segment warmup
is rebuilt after every data gap; no indicator state or open position crosses a gap.
The two runs must reproduce identical bound streams and hashes.

### Q3 — Bind the decision chain

Required order:

```text
FULL/PASS requalification
  -> Adjudicator PASS, every sleeve KEEP
  -> BOUND_CANDIDATE_COMPLETE
  -> Truth Chain PASS, every sleeve CLOSED
  -> Admission/Resize Freeze Gate PASS
```

`KEEP_CANDIDATE`, `REPAIR`, partial runs or degraded costs never populate this book.

### Q4 — Qualify the portfolio, not only the files

The final portfolio evidence must reconstruct synchronized mark-to-market equity,
shared capital, dynamic lot sizing, overlapping exposure, margin and stressed gaps.
It must pass all of the following:

- all six individually qualified and frequency at least five trades/year;
- locked-window absolute correlation at most 0.30;
- current/previous-month entry cadence sufficient for DarwinIA participation;
- historical synchronized mark-to-market DD at most 9.5%;
- stressed broker-day loss at most 4.0%, leaving a full point below the 5% kill;
- hard 1% cap per sleeve/EA/strategy/symbol;
- declared spread, swap, commission and adverse slippage all included;
- 45-exposed-day VaR and holding-duration/D-Leverage proxy reported;
- no official DARWIN quote, Rs, Ra or rating claim made from a closed-trade proxy.

The existing `portfolio_resize.py` output is only `ANALYSIS_ONLY_OWNER_REVIEW`.
A new hash-bound post-resize artifact must be the sole object allowed to say
`BOOK_QUALIFIED`; it binds the synchronized equity evidence, thresholds,
implementation hashes and final OWNER signature.

### Q5 — Deploy and scale separately

Qualification does not toggle AutoTrading. Deployment still needs an OWNER-signed
deploy manifest and the normal binary/preset/magic/news verification. Initial live
risk does not increase merely because a historical proxy looks good. The burn-in
first tests execution conformance, cadence, risk stability and Risk Engine
intervention; it is not a short-window Sharpe proof.

## What is different from the old book

1. Six explicit strategies replace 23 inherited rows.
2. Selection, semantic repair, economic proof and sizing are separate gates.
3. No losing sleeve is rescued by aggregate portfolio metrics.
4. Live parameter variants need their own approved Cards and fresh evidence.
5. Data gaps create independent continuous segments instead of one pooled curve.
6. Current spread, swap and slippage are certified rather than inferred from a
   `100% real ticks` label.
7. Risk is applied once: absolute `RISK_PERCENT`, `PORTFOLIO_WEIGHT=1`.
8. Open mark-to-market and common margin replace exit-only P&L as book truth.
9. A missing sleeve means zero risk and a full rerun, not automatic redistribution.
10. The book gets the word “qualified” only after a machine-bound economic/risk gate
    and OWNER signature.

## External objective alignment

Darwinex Zero's Risk Engine sizes and may adjust the DARWIN independently, targets
3.25%-6.5% monthly VaR, uses the last 45 exposed days for strategy VaR and applies
holding-duration D-Leverage limits. DarwinIA SILVER currently gives most rating
weight to the cumulative current-plus-prior-five-month return and separately uses
six-month maximum drawdown. These are reasons to prioritize stable combined risk,
cadence and rolling behavior over standalone PF.

Official references:

- https://www.darwinexzero.com/docs/en/risk-engine
- https://www.darwinexzero.com/docs/rating

## Evidence basis

- `docs/ops/evidence/DXZ23_AS_LIVE_REQUALIFICATION_2026-07-16.md`
- `docs/ops/evidence/DXZ23_REFERENCE_HORIZON_AND_DATA_GAPS_2026-07-16.md`
- `docs/ops/evidence/DXZ23_CARD_EA_PRESET_REPORT_LINEAGE_AUDIT_2026-07-16.md`
- `docs/ops/evidence/DXZ23_RISK_APPLICATION_CONTRACT_AUDIT_2026-07-16.md`
- `docs/ops/evidence/DXZ23_DARWINIA_BOOK_PROXY_2026-07-16.md`
- `docs/ops/DXZ_PORTFOLIO_RESIZE_REMEDIATION.md`
- `decisions/2026-07-15_book_resize_to_10pct_dd_1pct_cap.md`

This design changes no T_Live preset, binary, chart, position, risk setting or
AutoTrading state.

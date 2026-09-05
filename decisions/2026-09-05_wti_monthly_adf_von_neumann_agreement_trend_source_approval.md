# WTI Monthly ADF and Raw von Neumann Agreement Trend - Source Approval

- Date: 2026-09-05
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural WTI hypothesis, one Strategy Card,
  deterministic allocation, one branch-only non-live build, strict Q01, and
  one paced Q02 enqueue while the CPU ceiling remains clear
- Proposed slug: `wti-adf-vn-agree-tr`
- Proposed strategy ID:
  `AI-CODEX-WTI-ADF-VN-AGREE-TREND-20260905_S01`
- Source ID: `AI-CODEX-WTI-ADF-VN-AGREE-TREND-20260905`

## Authority and ordering

The current explicit OWNER mission authorizes exactly one new reputable-
source, structural, low-frequency commodity/energy sleeve outside the
certified XAU/SP500/NDX/XNG book. It permits direct WTI logic, requires
`RISK_FIXED` backtests, and directs Codex to select and mechanize one concrete
edge. This durable record approves the bounded source composition before card
extraction. It is approval for falsification, not an efficacy or portfolio
verdict.

## Approved evidence and complete read

The governed source is
`strategy-seeds/sources/AI-CODEX-WTI-ADF-VN-AGREE-TREND-20260905/source.md`,
pre-approval SHA-256
`6F90D10BAC2E1C9B52979899A6BA066C03488F4F387581D19915FEF10E29521B`.
Its local-only retrieval receipt has SHA-256
`E846CF8B8A1F89E01610EA1EAC35AE2E59CF39EAD4BD251264CC0CF349E4A6A7`
and binds these complete approved records:

1. lag-one ADF source packet, SHA-256
   `576505363DE9DCA4F8E0CB4047D30DE630FB76CBC754F3F9FE3805CDA33507EC`;
2. official NIST/original peer-reviewed raw von Neumann packet, SHA-256
   `C30EAC1402E532BEB68AC95B408A7559A355710914AD3E46991821B508529797`;
3. peer-reviewed WTI continuation packet, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

No new or deferred public URL is used.

## Approved mechanic

At the first executable `XTIUSD.DWX` D1 tick of each genuine broker month,
use sixty consecutive completed broker-month-end log closes.

```text
ADF: lag-one, intercept/no-time-trend regression over all 60 levels;
     qualify iff adf_t >= -2.594.
Raw von Neumann: newest 20 adjacent log returns; eta equals the sum of 19
     squared successive differences divided by centered sum of squares;
     qualify iff V > 1e-18 and eta < 2.0.
mom12 = x[59]-x[47].

BUY  iff both states qualify and mom12 > +1e-12
SELL iff both states qualify and mom12 < -1e-12
FLAT otherwise
```

The ADF comparison is inclusive and the eta comparison is strict. Only
momentum sign chooses side. Consume the month before every fallible gate. Use
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, frozen
`3.5*ATR(20,D1)` stop, no target, 1,500-point spread ceiling, next-month exit,
and forty-day stale repair. News, Friday close, and stress are off.

## Reputable-source findings

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE` | Approved complete ADF, official NIST/original peer-reviewed von Neumann, and peer-reviewed WTI continuation records with exact hashes and claim boundaries. |
| R2 | `PASS` | Shared sample, both arithmetic paths, inclusive/strict boundaries, conjunction, side, attempt, fixed risk, stop, spread, and lifecycle are locked. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XTIUSD.DWX` D1 history and MT5 state supply every runtime input. |
| R4 | `PASS` | Bounded deterministic prices, OLS, raw finite sums, comparisons, ATR risk, and native execution only; no ML, banned signal indicator, external runtime feed, grid, or martingale. |

## Non-duplicate decision

The corrected-root receipt, SHA-256
`AEF190EFD33100A1BEE62B598613320B6F1B77F5D64B7E620216DF22B2A31695`,
found no exact identity across 4,818 registry rows and 1,437 cards. It returned
the expected fuzzy neighbors `QM5_41336`, `QM5_41337`, `QM5_41310`,
`QM5_41320`, and `QM5_41319`. The configured Strategy Wiki root was absent;
this decision does not misstate that missing root as a clean scan.

Manual resolution: `QM5_41319` has only ADF; `QM5_41310` has only raw von
Neumann; `QM5_41336` uses KPSS partial-sum/long-run-variance geometry;
`QM5_41337` uses spectral-frequency geometry; and `QM5_41320` uses a lag-zero
Phillips-Perron construction. Pinned fixtures must include both one-gate
disagreement paths and executable up/down agreement paths. Verdict:
`DISTINCT_PRICE_LEVEL_ERROR_CORRECTION_AND_RETURN_ADJACENCY_CONJUNCTION`.

Shared WTI continuation may still correlate. Only Q09 may accept or reject
realized portfolio fit.

## Kill and safety boundary

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, formula/fixture mismatch,
current-month leakage, invalid fixed risk, missing stop, malformed lifecycle,
nondeterminism, or downstream hard failure. Do not rescue failure by changing
the sample, lags, transform, thresholds, side, stop, hold, spread, or retry
rule.

Authorized after G0 and clean allocation: branch-only non-live build,
independent reference tests, strict Q01, and one paced fixed-risk Q02 item if
CPU admission remains below the binding ceiling. Excluded: manual backtests;
live/demo/shadow/stress/optimization presets; portfolio-gate edits;
correlation waivers; portfolio admission; deploy/live manifests; `T_Live`;
AutoTrading; terminal control; and live use.

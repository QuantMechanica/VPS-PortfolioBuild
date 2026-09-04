# WTI Monthly ADF-KPSS Agreement Trend - Source Approval

- Date: 2026-09-04
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural WTI hypothesis, one Strategy Card,
  deterministic allocation, one branch-only non-live build, strict Q01, and
  one paced Q02 enqueue while the CPU ceiling remains clear
- Proposed slug: `wti-adf-kpss-agree-tr`
- Proposed strategy ID: `AI-CODEX-WTI-ADF-KPSS-AGREE-TREND-20260904_S01`
- Source ID: `AI-CODEX-WTI-ADF-KPSS-AGREE-TREND-20260904`

## Authority and ordering

The current explicit OWNER mission authorizes exactly one new reputable-
source, structural, low-frequency commodity/energy sleeve outside the
certified XAU/SP500/NDX/XNG book, permits direct WTI logic, requires
`RISK_FIXED` backtests, and requests one paced Q02 enqueue. The OWNER directed
Codex to select one concrete edge; this durable record approves the bounded
local-source composition before Strategy Card extraction.

Approval is for falsification only. It establishes no unit root,
nonstationarity, activity, economics, robustness, decorrelation, portfolio
admission, deployment, or live safety. The deterministic allocator owns the
numeric EA identity; this decision does not hand-allocate one.

## Approved evidence and complete read

The single governed source is
`strategy-seeds/sources/AI-CODEX-WTI-ADF-KPSS-AGREE-TREND-20260904/source.md`,
pre-approval SHA-256
`72F37DA736B9DB088C5D43932C1DCD6B05F2013E73B6990AD04363A84DA09870`.
Its local-only retrieval receipt has SHA-256
`C9E54F1DDF49B4E21C53AE384D63DAA5347C78AF95AF9CD19369266B1B92A678`
and binds three already approved complete repository records:

1. the lag-one ADF source packet, SHA-256
   `576505363DE9DCA4F8E0CB4047D30DE630FB76CBC754F3F9FE3805CDA33507EC`;
2. the constant-only KPSS source packet, SHA-256
   `484F927088FCA0A01E4332B289A6A195A29152FDDE3BF08D7FD47CD8D86BEAD9`;
3. the peer-reviewed Moskowitz-Ooi-Pedersen WTI continuation packet,
   SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

No deferred public URL is used. The attempted new DFA source route was
classified `DEFERRED:SOURCE_POLICY` and discarded before source approval.

## Approved mechanic

At the first executable `XTIUSD.DWX` D1 tick of each genuine broker month,
use exactly sixty consecutive completed broker-month-end log closes.

```text
ADF: 58-row constant/no-time-trend lag-one first-difference regression,
     residual dof 55, qualify iff adf_t >= -2.594.
KPSS: constant-only demeaned log levels, 60 partial sums, fixed lag-four
      Bartlett/Newey-West denominator, qualify iff kpss >= 0.347.
mom12 = x[59]-x[47].

BUY  iff both tests qualify and mom12 > +1e-12
SELL iff both tests qualify and mom12 < -1e-12
FLAT otherwise
```

Both comparisons are inclusive. The tests are agreement classifiers, not
p-value claims or independent votes. Only the twelve-month return selects
side. Consume the month before every fallible gate. Use
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, 1,500-point spread ceiling,
next-month exit, and forty-day stale repair. News, Friday close, and stress
are off.

## Reputable-source findings

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE` | Previously approved complete ADF, KPSS, and peer-reviewed WTI continuation records, exact hashes, read scopes, and non-transfer boundaries. |
| R2 | `PASS` | Sample, ADF and KPSS arithmetic, inclusive boundaries, conjunction, side, attempt, fixed risk, stop, spread, and lifecycle are locked. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XTIUSD.DWX` D1 history and MT5 state supply every runtime input. |
| R4 | `PASS` | Completed prices, bounded OLS/partial-sum/HAC arithmetic, comparisons, ATR risk plumbing, and native execution only; no trained output, banned signal indicator, external runtime feed, grid, martingale, or random path. |

## Non-duplicate decision

The corrected-root receipt, SHA-256
`2AC5689C28945B26F133058B7C60D631A2BB28582D15CD41BF0150570F0ACCA1`,
found no exact identity across 4,816 registry rows, 1,435 cards, and 45 Wiki
nodes. It returned the expected fuzzy neighbors `QM5_41319` (ADF, 0.70) and
`QM5_41320` (Phillips-Perron, 0.67).

Manual review resolves the identity as distinct. `QM5_41319` has no KPSS
gate; `QM5_41317` has no ADF gate; `QM5_41320` uses a lag-zero AR(1) plus an
eleven-lag Phillips-Perron correction. The pinned fixture includes an ADF-only
qualifier rejected by KPSS and a KPSS-only qualifier rejected by ADF, proving
the conjunction is not functionally identical to either parent. Verdict:
`DISTINCT_DUAL_NULL_AGREEMENT_STATE_FROM_EITHER_SINGLE_TEST_OR_PP_STATE`.

Shared WTI continuation can still create high economic correlation. Only Q09
may accept or reject realized portfolio fit.

## Kill and safety boundary

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, formula/fixture mismatch,
current-month leakage, invalid fixed risk, missing stop, malformed lifecycle,
nondeterminism, or downstream hard failure. Do not rescue failure by changing
the sample, lags, thresholds, side, stop, hold, spread, or retry rule.

Authorized after G0 and clean registries: branch-only non-live build,
independent reference tests, strict Q01, one fixed-risk backtest preset, and
one paced Q02 item while a fresh CPU window is below the ceiling. Excluded:
manual backtests; live/demo/shadow/stress/optimization presets; portfolio-gate
edits; correlation waivers; portfolio admission; deploy/live manifests;
`T_Live`; AutoTrading; terminal control; and live use.

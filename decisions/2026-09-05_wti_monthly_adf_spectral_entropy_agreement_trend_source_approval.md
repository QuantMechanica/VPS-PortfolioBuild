# WTI Monthly ADF and Spectral-Entropy Agreement Trend - Source Approval

- Date: 2026-09-05
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural WTI hypothesis, one Strategy Card,
  deterministic allocation, one branch-only non-live build, strict Q01, and
  one paced Q02 enqueue while the CPU ceiling remains clear
- Proposed slug: `wti-adf-specent-agree-tr`
- Proposed strategy ID:
  `AI-CODEX-WTI-ADF-SPECENT-AGREE-TREND-20260905_S01`
- Source ID: `AI-CODEX-WTI-ADF-SPECENT-AGREE-TREND-20260905`

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
`strategy-seeds/sources/AI-CODEX-WTI-ADF-SPECENT-AGREE-TREND-20260905/source.md`,
pre-approval SHA-256
`B71F7A3176AD62FA606A22A597E9A8754D567F0B29FEFD252BB18CF35D215181`.
Its local-only retrieval receipt has SHA-256
`E584640F984CC543F72EC049F2F4BC58EA399AF502B547618CBF8CBFD1A53BF3`
and binds these complete approved records:

1. lag-one ADF source packet, SHA-256
   `576505363DE9DCA4F8E0CB4047D30DE630FB76CBC754F3F9FE3805CDA33507EC`;
2. peer-reviewed spectral-entropy and pinned periodogram packet, SHA-256
   `B0FBB9993C5FE3BF6643EC13E96AEBCDD669CA077D1A2A8A2677D65CAABE4514`;
3. peer-reviewed WTI continuation packet, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.

No new or deferred public URL is used.

## Approved mechanic

At the first executable `XTIUSD.DWX` D1 tick of each genuine broker month,
use sixty consecutive completed broker-month-end log closes.

```text
ADF: lag-one, intercept/no-time-trend regression over all 60 levels;
     qualify iff adf_t >= -2.594.
Spectral entropy: newest 48 adjacent monthly log returns; demeaned length-48
     one-sided DFT, paired bins doubled, Nyquist undoubled;
     qualify iff Hspec <= 0.88.
mom12 = x[59]-x[47].

BUY  iff both states qualify and mom12 > +1e-12
SELL iff both states qualify and mom12 < -1e-12
FLAT otherwise
```

Both comparisons are inclusive. Only momentum sign chooses side. Consume the
month before every fallible gate. Use `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, frozen `3.5*ATR(20,D1)` stop,
no target, 1,500-point spread ceiling, next-month exit, and forty-day stale
repair. News, Friday close, and stress are off.

## Reputable-source findings

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE` | Approved complete ADF, peer-reviewed spectral-entropy/transparent implementation, and peer-reviewed WTI continuation records with exact hashes and claim boundaries. |
| R2 | `PASS` | Shared sample, both arithmetic paths, inclusive boundaries, conjunction, side, attempt, fixed risk, stop, spread, and lifecycle are locked. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XTIUSD.DWX` D1 history and MT5 state supply every runtime input. |
| R4 | `PASS` | Bounded deterministic prices, OLS, DFT/entropy arithmetic, comparisons, ATR risk, and native execution only; no ML, banned signal indicator, external runtime feed, grid, or martingale. |

## Non-duplicate decision

The corrected-root receipt, SHA-256
`ED4E6003CC8E72481DA0B3509C08CAD7CA89B73986F8F11570505AC06ADAEFC5`,
found no exact identity across 4,817 registry rows and 1,436 cards. It returned
the expected fuzzy neighbors `QM5_41336`, `QM5_41312`, `QM5_41320`, and
`QM5_41319`. The configured Strategy Wiki root was absent; this decision does
not misstate that missing root as a clean scan.

Manual resolution: `QM5_41319` has only ADF; `QM5_41312` has only spectral
entropy; `QM5_41336` uses KPSS partial-sum/long-run-variance geometry instead
of frequency-power entropy; `QM5_41320` uses a lag-zero Phillips-Perron
construction. Pinned fixtures must include both one-gate disagreement paths
and a prior ADF-KPSS qualifier rejected here for high entropy. Verdict:
`DISTINCT_PRICE_LEVEL_ERROR_CORRECTION_AND_FREQUENCY_POWER_CONJUNCTION`.

Shared WTI continuation may still correlate. Only Q09 may accept or reject
realized portfolio fit.

## Kill and safety boundary

Retire on zero positions, fewer than five completed positions in any full
post-warm-up year, nonpositive governed economics, formula/fixture mismatch,
current-month leakage, invalid fixed risk, missing stop, malformed lifecycle,
nondeterminism, or downstream hard failure. Do not rescue failure by changing
the sample, lags, transform, bins, thresholds, side, stop, hold, spread, or
retry rule.

Authorized after G0 and clean allocation: branch-only non-live build,
independent reference tests, strict Q01, and one paced fixed-risk Q02 item if
CPU admission remains below the binding ceiling. Excluded: manual backtests;
live/demo/shadow/stress/optimization presets; portfolio-gate edits;
correlation waivers; portfolio admission; deploy/live manifests; `T_Live`;
AutoTrading; terminal control; and live use.

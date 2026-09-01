# WTI Monthly Daily Mean-Location Trend - Source Approval

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded WTI structural hypothesis, one Strategy Card, one branch
  build, strict Q01, and one paced non-live Q02 enqueue
- Proposed slug: `wti-mdaily-meanloc-tr`
- Proposed strategy ID: `AI-CODEX-WTI-MDAILY-MEANLOC-20260901_S01`
- Source ID: `AI-CODEX-WTI-MDAILY-MEANLOC-20260901`

## Authority and ordering

The current OWNER mission authorizes a new reputable-source, structural,
low-frequency commodity/energy sleeve and identifies direct WTI trend or
seasonality as eligible. This record approves the bounded source before card
extraction. It does not pre-approve activity, economics, robustness,
decorrelation, portfolio admission, deployment, or live use.

## Approved source and mechanic

The complete governed source is
`strategy-seeds/sources/AI-CODEX-WTI-MDAILY-MEANLOC-20260901/source.md`, with
its prompt/output trail beside it. Moskowitz, Ooi, and Pedersen (2012), as
fully reviewed in `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, supports
only the monthly WTI continuation carrier. The exact path statistic is a
pre-result QM synthesis:

```text
closes = all 17..23 D1 closes in immediately completed normalized month
mean_close = sum(closes) / count(closes)
location = closes[-1] / mean_close - 1
BUY if location > 1e-12; SELL if location < -1e-12; FLAT otherwise
```

Require an older boundary-proving bar, consume one attempt per month, and use
exact `XTIUSD.DWX` D1, `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
`3.5*ATR(20,D1)` hard stop, no target, 1,500-point spread ceiling, next-month
exit, and forty-day stale repair.

## Gate decision

| Gate | Verdict | Basis |
|---|---|---|
| R1 | `PASS` | Durable AI prompt/output/source record plus complete-read peer-reviewed monthly WTI continuation evidence and explicit claim limits. |
| R2 | `PASS` | Exact clock, observations, boundary proof, formula, sign, attempt, risk, stop, spread, and lifecycle. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native WTI D1 and MT5 state only. |
| R4 | `PASS` | Deterministic price arithmetic; no ML, banned signal indicator, external feed, grid, martingale, or scale-in. |

## Duplicate decision

The fail-closed corrected-root receipt
`artifacts/qm5_wti_mdaily_meanloc_tr_preallocation_dedup_20260901.json`,
SHA-256
`382847E3030752E00354B681D27E722AAEFD0B7F35E6E7ACE6F7ED3171183BFB`,
returned `CLEAN` across 4,761 registry rows, 1,398 cards, and 45 Wiki nodes.

Manual review distinguishes `QM5_13100` (six month-end mean), `QM5_41133`
(median of daily returns), `QM5_41105` (monthly high-low range location),
`QM5_41130` (month-open residence count), and `QM5_20187` (raw monthly
return). The `[110 x 19,101]` and `[90 x 19,101]` fixtures prove decision
disagreement with the raw-return and median-return neighbors.

Verdict:
`DISTINCT_WTI_COMPLETED_MONTH_FINAL_D1_CLOSE_VERSUS_SAME_MONTH_ARITHMETIC_MEAN_CLOSE_STRICT_SIGN_CONTINUATION`.

## Safety boundary

Q02 owns activity and baseline economics; Q09 alone owns realized
correlation. Authorized after G0 and registry gates: branch-only build,
reference tests, strict Q01, one fixed-risk D1 set, and one paced Q02 enqueue
if CPU admission permits. Excluded: manual tester run, optimization,
live/demo/shadow/stress presets, portfolio-gate changes, deploy/live manifests,
`T_Live`, AutoTrading, portfolio admission, and correlation waiver.

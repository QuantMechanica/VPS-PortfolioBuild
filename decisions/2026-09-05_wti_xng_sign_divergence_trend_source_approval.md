# WTI/XNG Twelve-Month Sign-Divergence Trend — Source Approval

- Date: 2026-09-05
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural WTI card, deterministic allocation, branch-only
  non-live build, strict Q01, and one paced Q02 enqueue if the host CPU ceiling
  is clear
- Proposed slug: `wti-xng-divtrend`
- Strategy ID: `MOP-EIA-WTI-XNG-SIGN-DIVERGENCE-20260905_S01`
- Source packet: `strategy-seeds/sources/MOP-EIA-WTI-DECOUP-2026/source.md`
- Source-packet SHA-256:
  `E2ACC15C814EC007D2846F8F7D3D912E93276759DCC34B41FB492C6433BC70D6`

## Authority and evidence

The current explicit OWNER mission authorizes one new reputable-source,
low-frequency commodity/energy hypothesis. The existing governed packet binds
the complete peer-reviewed time-series-momentum evidence of Moskowitz, Ooi,
and Pedersen (2012), including WTI and natural gas, to the complete U.S. EIA
oil/gas relationship report of Villar and Joutz (2006) and the peer-reviewed
weak-link evidence of Ramberg and Parsons (2012).

R1 passes because the parent evidence is attributable, complete-read, and
already governed. R2 passes for a locked monthly conjunction: compute exact
twelve-completed-month returns for WTI and XNG from synchronized completed D1
history, admit only strict opposite signs, and trade WTI in its own sign. R3
passes with registered native `XTIUSD.DWX` and read-only `XNGUSD.DWX`; the
continuous-CFD basis limitation remains explicit. R4 passes because runtime
uses only timestamps, prices, logarithms, comparisons, ATR risk, and framework
execution state.

## Claim and duplicate boundaries

No parent source tests this exact sign-disagreement conjunction, CFD mapping,
fixed-risk stop, economics, activity, or QM-book correlation. The corrected-
root receipt `artifacts/qm5_wti_xng_divtrend_dedup_20260905.json` (SHA-256
`324C00613A0A9F31D3F955433D75A270AB058C970005C55D00E18D3D21D84391`)
scanned 4,820 registry rows, 1,439 repository cards, and 45 Strategy Wiki
nodes and returned `CLEAN`.

Manual review separates the mechanic from `QM5_21516_wti-decoup-trend`, which
uses a 63-D1 Pearson-correlation magnitude threshold, and from two-leg XTI/XNG
rank, ratio, residual, and calendar baskets. Here XNG is read-only, its exact
twelve-month direction is load-bearing, and only WTI is ordered. Q09 receives
no waiver.

This approval excludes manual backtests, optimization, portfolio-gate changes,
portfolio admission, deployment, live manifests, `T_Live`, AutoTrading, and
live use.

---
source_id: QM-RESEARCH-2026-0010
title: US cash-open structure on XAUUSD (H-V2, 13:30 UTC gold-specific session mechanism)
source_type: internal_research
source_author: Claude
source_model: claude-sonnet-5
created: 2026-09-21
originating_task_id: 31012467-dde7-4b74-995c-def2241b28c0
status: draft
parent_source_ids: []
source_artifact: QM-RESEARCH://2026-0010
---

# US cash-open structure on XAUUSD (H-V2, 13:30 UTC gold-specific session mechanism)

## Research provenance

Authored by Claude under task `31012467-dde7-4b74-995c-def2241b28c0` (routed by Fable,
`fable-orchestrator-2026-09-21-velocity`), directed against the frozen 2026-09-20 Velocity
book evidence cohort. No ML/statistical search instrument was used. All measured figures
below come from `baseline_extract.json`
(`tools/strategy_farm/session_tools/velocity_hv1_hv3_baseline_extract_20260921.py`, reading
the real `q02_velocity_screen.json` and `README.md`).

## Structural cause

The task explicitly requires this hypothesis to use the US cash-open (13:30 UTC) mechanism
on **XAUUSD rather than indices**, because the index-trio candidates (41475 H-CW, 41476
H-MR) anchor to a US-cash-open proxy that is documented as mistimed for non-US-listed
symbols: `FTMO_PORTFOLIO_GAP_CURRENT.md` section 7 states the "cash-open" anchor is
"5-6 hours late for GDAXI" and drifts across DST, so a third of that symbol set has no
mechanism at all. XAUUSD does not have this problem: it is a genuinely continuous 23/5 OTC
market, so there is no "wrong exchange" to be mistimed against -- its volatility clustering
at 13:30 UTC (heavy USD macro-release density at 08:30 ET) is a property of the instrument
itself, not a borrowed anchor from a different market's calendar. Separately, two existing
always-on XAUUSD H1 configurations (10423, 11690) already show real measured edge but both
FAILED Q05 on drawdown (41% and 59% dd respectively) -- H-V2 tests whether session-gating
that same underlying gold edge to a single 13:30-14:30 UTC window, flat by 20:00 UTC,
reproduces the edge while removing the always-on exposure that likely drives the drawdown.

**Mechanical spec (bounded, no ML):**
- Symbol: XAUUSD. Timeframe: M15 signal / H1 context.
- Reference range: 12:30-13:30 UTC (the hour immediately preceding the window).
- Entry: first M15 candle in the 13:30-14:30 UTC window that closes beyond the reference
  range high/low, in the direction of the break (single volatility-expansion trigger, no
  failure/reversal variant for this hypothesis -- kept simpler than H-V1 to isolate the
  session-gating question).
- Stop: reference-range width. Target: 1.5x-2.0x reference-range width (fixed multiple).
- Hard time-stop: flat by 20:00 UTC every day -- 0% overnight by construction.
- One signal per day maximum. Mandatory news blackout per the active Edge Lab charter; no
  martingale/grid/averaging.

## Density arithmetic

- Structural ceiling: one 13:30-14:30 UTC window per weekday = up to 1.0 trades/bd before
  filtering.
- Discount for the mandatory news blackout (this window overlaps a large share of
  high-impact USD releases) and for days where the reference range is too narrow for a
  valid stop distance: prior estimate **0.5-0.7 trades/bd**. This is a structural prior;
  the closest measured analogue (10423, an always-on H1 config, not session-gated) runs at
  0.82 trades/bd, so 0.5-0.7 for a filtered single-window version is a conservative
  discount from that ceiling, not an extrapolation past it.
- Pilot fire-count estimate on `.DWX`: over the 1175-business-day evidence window
  (`baseline_extract.json.summary.bd_window`), 0.5-0.7 trades/bd implies **~590-820 total
  fires** across the 2018-2024 history.
- E[R] prior: **+0.10-0.15R/trade**, below 10423's always-on +0.086R... actually ABOVE it,
  reflecting the expectation that filtering to the highest-volatility window of the day
  concentrates the edge that was previously diluted across all H1 bars; but this is
  explicitly the assumption the Q02 canary must test, since the alternative (session-gating
  removes exactly the tail moves that drove 10423/11690's edge, leaving a smaller E[R]) is
  equally plausible and is what falsification criterion 2 below is designed to catch.
- Implied R/bd: 0.5-0.7 x +0.10-0.15R = **+0.05R/bd to +0.105R/bd**, roughly comparable to
  or somewhat above the current best single sleeve (13213, 0.048 R/bd) if the prior holds.

## Cost-to-target check

XAUUSD's spread/commission structure differs materially from FX majors; this document does
not invent a commission figure (Hard Rule: no invented commission/swap/DST values). The
stop/target here is scaled to the measured 12:30-13:30 UTC reference-range width (not a
fixed point value), so the commission_R < 0.03R check must be read from
`framework/registry/tester_defaults.json` at Q02 canary time, not assumed here.

## Falsification criteria (Q02/Q04)

Retire this hypothesis if, on the full 2018-2024 `.DWX` history at RISK_FIXED:
1. Measured density < 0.3 trades/bd (below the 0.5-0.7 prior), OR
2. Net E[R] < +0.10R/trade after costs, OR
3. PF < 1.05, OR
4. **Max drawdown reproduces the same failure class as 10423/11690** (i.e. session-gating
   does NOT fix the drawdown axis) -- this is the hypothesis's own specific falsification
   condition, distinct from the generic density/E[R] bars, because the entire point of the
   redesign is to fix a documented Q05 failure, not just to find positive expectancy, OR
5. The in-sample (2018-2022) configuration does not hold up on a 2023-2025 holdout at
   >=70% of its selection-period R/bd (per the `census_frontier_holdout.json` lesson), OR
6. H-V2's daily P/L shows pairwise |r| > 0.30 with 10700 (the current demo-roster gold
   sleeve) or lower-decile-day co-occurrence > 2x the independence baseline -- if H-V2 is
   just capturing a subset of 10700's existing edge rather than a distinct one, it cannot
   be carded alongside 10700 without the joint-tail check.

## Distinct from 13213 / 10706 / 10700 / 41475 / 41476 / 41477

- **13213 (USDJPY)**: different asset (FX vs metal) and different session (Tokyo vs US
  cash-open); cited only as the session-flat template profile, not transplanted.
- **10706 (GBPUSD)**: different asset entirely.
- **10700 (XAUUSD, demo roster)**: same asset. 10700 is NOT session-gated (19.7h hold, 58%
  overnight); H-V2 is a single-window, 0% overnight redesign. Falsification criterion 6
  above requires the joint-tail check against 10700 specifically because both are gold.
- **41475/41476 (H-CW/H-MR)**: same broad "cash-open" concept but applied to indices, where
  it is documented as mistimed for GDAXI. H-V2 avoids that exact failure mode by using an
  instrument (XAUUSD) with no exchange-timing mismatch to begin with -- this is the central
  distinction the task requires ("rather than indices (H-CW/H-MR failed on NDX/GDAXI)").
- **41477 (H-FXMR)**: FX majors, M15 EMA-reclaim trigger -- different asset class and
  different trigger family entirely; no overlap.
- **10423/11690 (existing always-on XAUUSD H1)**: same asset, same broad H1 timeframe, but
  NOT session-gated and both FAILED Q05 on drawdown. H-V2 is explicitly the session-gated
  redesign of the same underlying edge, not an independent discovery -- its falsification
  bar (criterion 4) is tied directly to whether it fixes what killed 10423/11690.

## Source manifest

```qm-source-manifest
# Auto-generated by research_source.seal; do not hand-edit.
research.json:         8263a4f8b9901bed112d4b8b47f6c00a98cdf032938b357741d05e14cdafe678
lineage.json:          581b1626bd8782dcc726e14c9c5cda11f79cff543e235721b3fdd4be53ee3883
critic_receipt.json:   529e8710554d85fac62d435853a1c03f01bb3170f7efbc283a06b49d698cec14
baseline_extract.json: 7426c6e94d560813826663f41a93d439280aec93d097eb7704d6c469819896e9
```

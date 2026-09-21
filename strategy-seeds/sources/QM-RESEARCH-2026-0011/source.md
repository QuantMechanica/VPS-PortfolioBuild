---
source_id: QM-RESEARCH-2026-0011
title: Tokyo-session structure on JPY crosses AUDJPY/GBPJPY (H-V3, native Asia-session mechanism, non-Balke trigger)
source_type: internal_research
source_author: Claude
source_model: claude-sonnet-5
created: 2026-09-21
originating_task_id: 31012467-dde7-4b74-995c-def2241b28c0
status: draft
parent_source_ids: []
source_artifact: QM-RESEARCH://2026-0011
---

# Tokyo-session structure on JPY crosses AUDJPY/GBPJPY (H-V3, native Asia-session mechanism, non-Balke trigger)

## Retired 2026-09-21 per critique 1614737c

Cross-vendor critique `1614737c` (Codex, verbatim in
`docs/ops/evidence/2026-09-20_velocity_book/hv1_hv3_critique_1614737c.md`) returned **REJECT** for this
draft: entry price, gap-vs-spike definition, ATR multiple, reference side and closed-bar/shift-1 semantics
were unspecified (a spike extreme read before the signal bar closes would look ahead); the 0.4-0.6/bd rate
was a bare assumption; the combined R/bd arithmetic was wrong (two symbols imply 0.064-0.144, not
0.032-0.072); negative breakout evidence does not establish a fade edge; thin-session spread was unmeasured.
Fable accepted the critique and sealed this artifact with ledger status **retired**. Nothing below is
buildable; a closed-bar, DST-aware re-authoring with a measured fire count (the
`tools/strategy_farm/session_tools/velocity_hv_prescreen_0921.py` harness now exists for that) and per-leg
kill rules would be a NEW artifact, not an edit of this one. The original text is preserved unchanged below
as the evidence trail.


## Research provenance

Authored by Claude under task `31012467-dde7-4b74-995c-def2241b28c0` (routed by Fable,
`fable-orchestrator-2026-09-21-velocity`), directed against the frozen 2026-09-20 Velocity
book evidence cohort. No ML/statistical search instrument was used. All measured figures
below come from `baseline_extract.json`
(`tools/strategy_farm/session_tools/velocity_hv1_hv3_baseline_extract_20260921.py`, reading
the real `q02_velocity_screen.json` and `README.md`).

## Structural cause

The task requires a Tokyo/Asia-session mechanism on AUDJPY/GBPJPY using "a different
trigger than the Balke stop bracket." Two independent facts motivate the redesign:

1. Every measured breakout/momentum-continuation configuration on AUDJPY, GBPJPY, EURJPY
   and CHFJPY in the frozen Q02 screen is net-negative (`baseline_extract.json`: 6
   configurations, R_bd from -0.001 to -0.045).
2. The Balke breakout-with-stop-bracket trigger itself, transplanted verbatim onto these
   exact pairs (lineage QM5_41484, RETIRED 2026-09-20), also measured flat: AUDJPY +0.005R,
   GBPJPY -0.001R, against a USDJPY control of +0.053R. `README.md` section 2c's own
   conclusion: "the Balke Tokyo-range window is a USDJPY-specific edge, not a transferable
   mechanism."

Both breakout-family attempts on these pairs have failed. H-V3 therefore switches the
trigger CLASS entirely -- from breakout-follow-through to mean-reversion/fade -- and
additionally rejects USDJPY's Tokyo-AM (GMT+3 03:00-06:00) window as the anchor for either
pair, since neither AUDJPY nor GBPJPY has USDJPY's liquidity structure. Each pair instead
uses ITS OWN native thin-liquidity session handoff: AUDJPY at the Sydney/Tokyo open
(21:00-22:00 UTC, when AUD's own regional session begins and the prior NY-session book is
thin), GBPJPY at the Tokyo/London handoff (06:00-07:00 UTC, the transition where Tokyo
liquidity is fading and London has not yet arrived). In both windows, an outsized
session-open gap is economically more likely to be a thin-book overshoot than a
sustained directional move -- the opposite logic from a liquid-session breakout, and the
reason the trigger here is fade, not breakout.

**Mechanical spec (bounded, no ML):**
- Symbols: AUDJPY (anchor 21:00-22:00 UTC), GBPJPY (anchor 06:00-07:00 UTC). Timeframe:
  M15 signal / H1 context.
- Reference level: the prior session's closing range (last H1 bar's high/low before the
  anchor window).
- Trigger: a gap/spike at the anchor window that exceeds a fixed magnitude filter
  (measured in ATR multiples of the preceding 20 H1 bars, a bounded, non-adaptive
  parameter) beyond the reference level -> fade back toward the reference level.
- Stop: gap/spike extreme (beyond the entry). Target: return to the reference level (fixed
  distance implied by the trigger itself, not adaptive).
- Hard time-stop: flat within 4 hours of entry -- 0% overnight by construction.
- One signal per symbol per day maximum. Mandatory news blackout per the active Edge Lab
  charter; no martingale/grid/averaging.

## Density arithmetic

- Structural ceiling: one anchor window per weekday per symbol = up to 1.0 trades/bd/symbol
  before filtering.
- The magnitude filter (gap/spike must exceed an ATR-multiple threshold) is deliberately
  selective -- most days will NOT produce a qualifying gap. Prior estimate:
  **0.4-0.6 trades/bd/symbol**, lower than H-V1/H-V2's priors because this trigger requires
  an extreme move, not merely a session having occurred.
- Pilot fire-count estimate on `.DWX`: over the 1175-business-day evidence window
  (`baseline_extract.json.summary.bd_window`), 0.4-0.6 trades/bd/symbol across 2 symbols
  implies **~940-1410 total fires** across the 2018-2024 history.
- E[R] prior: **+0.08-0.12R/trade**. Unlike H-V1/H-V2, there is no measured fade-style
  analogue on these pairs to scale from -- this prior is a bare structural assumption
  (fades in a thin-liquidity session should have a favorable stop-to-target ratio if the
  magnitude filter is well-calibrated) and carries the most uncertainty of the three
  hypotheses; `confidence` in `research.json` is explicitly rated "Low" for this reason.
- Implied R/bd: 0.4-0.6 x +0.08-0.12R = **+0.032R/bd to +0.072R/bd combined**, in the same
  range as the current single best sleeve (13213, 0.048 R/bd) if the prior holds -- a
  smaller expected contribution than H-V1/H-V2, consistent with its weaker evidentiary
  grounding.

## Cost-to-target check

Both anchor windows are thin-liquidity sessions where real-world spread widening is likely
larger than in London/NY hours; the `.DWX` tester models zero spread
(`FTMO_PORTFOLIO_GAP_CURRENT.md` section 1b), so a commission-only cost check here is
probably MORE optimistic than for H-V1/H-V2, not less. This document does not invent a
commission or spread figure (Hard Rule: no invented commission/swap/DST values) -- the
commission_R < 0.03R check, and an assessment of realistic thin-session spread, must both
be read at Q02 canary time from `framework/registry/tester_defaults.json` and flagged
explicitly if the tester's zero-spread assumption looks unrealistic for this window.

## Falsification criteria (Q02/Q04)

Retire this hypothesis if, on the full 2018-2024 `.DWX` history at RISK_FIXED:
1. Measured density < 0.25 trades/bd/symbol (below the 0.4-0.6 prior), OR
2. Net E[R] < +0.08R/trade after costs, OR
3. PF < 1.05, OR
4. The in-sample (2018-2022) configuration does not hold up on a 2023-2025 holdout at
   >=70% of its selection-period R/bd (per the `census_frontier_holdout.json` lesson), OR
5. Either leg's daily P/L shows pairwise |r| > 0.30 with QM5_13213 (USDJPY) or with each
   other, or lower-decile-day co-occurrence > 2x the independence baseline -- both AUDJPY
   and GBPJPY are JPY-denominated and share tail risk with the existing Balke sleeve; this
   uses the same threshold as the H-CW/H-MR joint-tail panel
   (`FTMO_PORTFOLIO_GAP_CURRENT.md` section 3).

## Distinct from 13213 / 10706 / 10700 / 41475 / 41476 / 41477 / 41484

- **13213 (USDJPY Balke)**: same broad Asia-session family but a DIFFERENT trigger
  (mean-reversion fade vs Balke's breakout-with-stop-bracket) and a DIFFERENT anchor per
  pair (Sydney/Tokyo open for AUDJPY, Tokyo/London handoff for GBPJPY -- neither is
  USDJPY's Tokyo-AM GMT+3 03:00-06:00 window). This is the direct response to the task's
  explicit requirement for "a different trigger than the Balke stop bracket."
- **41484 (Balke FX fan-out, RETIRED)**: this is the prior attempt on these exact pairs
  with the IDENTICAL trigger+window as 13213, which measured flat (AUDJPY +0.005R, GBPJPY
  -0.001R). H-V3 is not a re-run of 41484; it changes both the window and the trigger
  class.
- **10706/10700**: different assets (GBPUSD, XAUUSD), no overlap.
- **41475/41476/41477**: different asset classes (indices, FX majors on a different trigger
  family) and different sessions; no overlap.
- **Existing GBPJPY breakout-style EAs (37003, 9940, 11314, 11481)**: all measured
  negative in the frozen screen (`baseline_extract.json`). H-V3 deliberately avoids the
  breakout/momentum-continuation trigger family that has failed repeatedly on this pair and
  tests the opposite trigger class instead.

## Source manifest

```qm-source-manifest
# Auto-generated by research_source.seal; do not hand-edit.
research.json:         6faf1fe9627a08f3ecde6eaead5dac0830b332c2e781fe470b698d94fd2a382a
lineage.json:          7ca5d4c76c5b8d8d8e54b208264e6a7cd14f0ffa7f4365fb9bb0629c16fc45e5
critic_receipt.json:   529e8710554d85fac62d435853a1c03f01bb3170f7efbc283a06b49d698cec14
baseline_extract.json: 1258bc6032a5ac175fd19ffc5fc4355baa468830a17050b5588eca9857bddc2c
```

---
source_id: QM-RESEARCH-2026-0009
title: London-open range/reversal on EURUSD/GBPUSD (H-V1, native 07:00-08:00 UTC session structure)
source_type: internal_research
source_author: Claude
source_model: claude-sonnet-5
created: 2026-09-21
originating_task_id: 31012467-dde7-4b74-995c-def2241b28c0
status: draft
parent_source_ids: []
source_artifact: QM-RESEARCH://2026-0009
---

# London-open range/reversal on EURUSD/GBPUSD (H-V1, native 07:00-08:00 UTC session structure)

## Research provenance

Authored by Claude under task `31012467-dde7-4b74-995c-def2241b28c0` (routed by Fable,
`fable-orchestrator-2026-09-21-velocity`), directed against the frozen 2026-09-20 Velocity
book evidence cohort (`docs/ops/evidence/2026-09-20_velocity_book/README.md`,
`docs/ftmo/FTMO_PORTFOLIO_GAP_CURRENT.md`). No ML/statistical search instrument was used;
this is a directed hypothesis over already-measured evidence, not a Kimi OBSERVE/DISCOVER
search product. All measured figures cited below come from
`baseline_extract.json` (a deterministic re-derivation script,
`tools/strategy_farm/session_tools/velocity_hv1_hv3_baseline_extract_20260921.py`, reading
the real `q02_velocity_screen.json` / `README.md` files -- no number here is asserted from
memory).

## Structural cause

EURUSD and GBPUSD's natural liquidity center is the London session, not Tokyo. The
company's single fastest measured session-flat sleeve (QM5_13213, Balke GMT+3 03:00-06:00
range breakout on USDJPY: 0.744 trades/bd, +0.064R/trade, 0.048 R/bd, 7.2h hold, 0%
overnight) works because the breakout is measured against USDJPY's OWN native session
(Tokyo). When that identical window+trigger was transplanted verbatim onto nine other FX
pairs (lineage QM5_41484, fan-out completed and RETIRED 2026-09-20), every non-JPY major
came back flat-to-negative (AUDUSD -0.003R, GBPUSD -0.015R, EURUSD -0.082R) while the
USDJPY control reproduced the parent byte-exactly (+0.053R). The stated lesson in
`README.md` section 2c is explicit: "the next fan-outs must pair each mechanism with its
own session structure." H-V1 is that pairing for EURUSD/GBPUSD: the SAME mechanism class
(a bounded opening-range breakout, plus a mutually-exclusive failed-breakout/reversal
variant) re-anchored to the 07:00-08:00 UTC window in which EURUSD/GBPUSD actually derive
their liquidity and directional information, instead of reusing Tokyo's window.

**Mechanical spec (bounded, no ML):**
- Symbols: EURUSD, GBPUSD. Timeframe: M15 signal / H1 context.
- Range window: 07:00-08:00 UTC (fixed clock time, DST handled via broker-time convention
  per `CLAUDE.md` "Broker time (Darwinex/DXZ NY-Close)"; no adaptive/inferred window).
- Entry A (breakout): first M15 candle after 08:00 UTC that closes beyond the 07:00-08:00
  range high/low, in the direction of the break.
- Entry B (failure/reversal, mutually exclusive with A on the same range): a break beyond
  the range high/low that closes back inside the range within 2 M15 bars -> enter in the
  opposite direction.
- Stop: range width (from the breakout/failure point). Target: 1.5x-2.0x range width
  (fixed multiple, not adaptive). Hard time-stop: flat by 16:00 UTC every day -- 0%
  overnight by construction, mirroring 13213's overnight profile.
- One signal per symbol per day maximum (A and B cannot both fire the same day).
- Mandatory news blackout per the active Edge Lab charter; no martingale/grid/averaging.

## Density arithmetic

- Structural ceiling: one opening range per weekday per symbol = up to 1.0 trades/bd/symbol
  before any filtering.
- Discount for holidays, thin-range days (range too narrow to produce a valid stop-distance)
  and the mandatory news blackout removing high-impact-news days: prior estimate
  **0.6-0.7 trades/bd/symbol**, i.e. **1.2-1.4 trades/bd combined** across EURUSD+GBPUSD.
  This is a structural prior, not a measurement -- no configuration in the frozen Q02
  screen gates entry to this exact window (`baseline_extract.json` summary: 30 measured
  EURUSD/GBPUSD configurations, none session-anchored to 07:00-08:00 UTC).
- Pilot fire-count estimate on `.DWX` (prescreen v2 rule): the evidence window used
  throughout the frozen screen is **1175 business days**
  (`baseline_extract.json.summary.bd_window`). At 0.6-0.7 trades/bd/symbol over 1175 bd and
  2 symbols: **~1410-1645 total fires** across the 2018-2024 history, comfortably above any
  plausible minimum-fire-count floor for a Q02 canary.
- E[R] prior: **+0.10-0.15R/trade**, anchored to the 13213 template (+0.064R) scaled up for
  London's structurally higher realized-volatility-at-open relative to Tokyo's 03:00-06:00
  window -- explicitly flagged in `research.json.confidence` as the single most likely
  point of falsification, since it is an unverified cross-session transfer, not a
  measurement.
- Implied R/bd: 1.2-1.4 combined trades/bd x +0.10-0.15R = **+0.12R/bd to +0.20R/bd
  combined** (both symbols) if the E[R] prior holds -- against the measured inventory
  ceiling of ~0.03-0.06 R/bd per sleeve (`README.md` section 1c), this alone would double
  or triple the single best sleeve's contribution, and against the FTMO frontier's ~100
  USD/bd (0.20 R/bd book-wide at 0.5%) requirement (`FTMO_PORTFOLIO_GAP_CURRENT.md`
  section 2) it would supply a meaningful fraction of the gap on its own if the prior
  survives Q02.

## Cost-to-target check

Stop/target are scaled to the measured 07:00-08:00 UTC range width (not a fixed pip value),
so the cost ratio must be checked per-symbol against the documented commission in
`framework/registry/tester_defaults.json` once a canary is run -- this document does not
invent a commission or spread figure (Hard Rule: no invented commission/swap/DST values).
Qualitatively: EURUSD/GBPUSD London-open ranges are typically wide enough (tens of pips)
relative to the documented commission structure used elsewhere in the inventory (10706
GBPUSD H1: -29.28 USD/trade at 1% risk, `FTMO_PORTFOLIO_GAP_CURRENT.md` section 2) that a
commission_R < 0.03R check is plausible, but this is exactly what the Q02 canary must
confirm, not assume.

## Falsification criteria (Q02/Q04)

Retire this hypothesis if, on the full 2018-2024 `.DWX` history at RISK_FIXED:
1. Measured density < 0.3 trades/bd/symbol (well below the 0.6-0.7 prior), OR
2. Net E[R] < +0.08R/trade after costs, OR
3. PF < 1.05, OR
4. The in-sample (2018-2022) configuration does not hold up on a 2023-2025 holdout at
   >=70% of its selection-period R/bd -- directly applying the `census_frontier_holdout.json`
   lesson that in-sample winners in this EA family do not generalize OOS
   (`README.md` section 1c), OR
5. EURUSD and GBPUSD legs show pairwise daily-P/L |r| > 0.30 or lower-decile-day
   co-occurrence > 2x the independence baseline -- the same joint-tail threshold used for
   the H-CW/H-MR panel (`FTMO_PORTFOLIO_GAP_CURRENT.md` section 3) -- in which case only
   one of the two symbols may be carded, not both.

## Distinct from 13213 / 10706 / 10700 / 41475 / 41476 / 41477 / 41484

- **13213 (USDJPY Balke)**: same mechanism CLASS (opening-range breakout) but a different
  symbol and a different native session (Tokyo GMT+3 03:00-06:00 vs London 07:00-08:00
  UTC) -- H-V1 does not reuse 13213's window, it reuses only the economic logic, applied to
  each symbol's own session.
- **41484 (Balke FX fan-out, RETIRED)**: this is the transplant that already failed --
  IDENTICAL window+trigger copied onto GBPUSD/EURUSD/etc. H-V1 is the corrective response:
  same instruments, deliberately DIFFERENT window (each symbol's own open) and an added
  failure/reversal variant absent from 41484's pure breakout.
- **10706 (GBPUSD H1)**: not session-gated at all -- 7.4h median hold, 46% overnight,
  measured density 0.129-0.168 trades/bd. H-V1 is a single-window, session-flat (0%
  overnight) play; it does not compete for the same signals as 10706's always-on swing
  logic.
- **10700 (XAUUSD)**: different asset entirely; no overlap.
- **41475/41476 (H-CW/H-MR)**: index trio (NDX/GDAXI/SP500) anchored to a US-cash-open
  proxy that is documented as mistimed for non-US-listed symbols (GDAXI 5-6h late,
  `FTMO_PORTFOLIO_GAP_CURRENT.md` section 7) -- different asset class, and H-V1 avoids
  that specific failure mode by using each FX symbol's own genuinely-correct session open.
- **41477 (H-FXMR)**: the closest overlap -- same two symbols (EURUSD/GBPUSD) plus USDJPY,
  same broad London/NY session family. The mechanisms differ: 41477 is a continuous M15
  EMA-reclaim trigger (not gated to a specific narrow window) with a documented cost
  fragility (round-trip ~0.85 pip vs ~8.75 pip TP, needing gross >=+0.22R to net +0.10R,
  `FTMO_PORTFOLIO_GAP_CURRENT.md` section 7) and a "no magnitude floor" alternative trigger
  that risks dominating signal count with noise. H-V1 is session-gated to exactly one
  opening-range signal per symbol per day (bounding signal count structurally rather than
  via a magnitude floor) with a stop/target scaled to the measured range width rather than
  a fixed pip target. **This overlap is a real risk, not a formality**: if 41477 is ever
  measured, the joint-tail check in falsification criterion 5 above must also be run
  against 41477's EURUSD/GBPUSD legs before both are ever carded into the same book.

## Source manifest

```qm-source-manifest
# Auto-generated by research_source.seal; do not hand-edit.
research.json:         4191bfcb44e4b57b02c9acf0573d799b83aad30843e9cddd0ce867711e77be6a
lineage.json:          cbac97ba43a64c1dcdca22cbb1308c07c00209501693851911881bd2b0c8b22b
critic_receipt.json:   529e8710554d85fac62d435853a1c03f01bb3170f7efbc283a06b49d698cec14
baseline_extract.json: c987e2d3280118ed9113a45fc74a473ea04bf03eeaf1c40340c56f6bbda19f73
```

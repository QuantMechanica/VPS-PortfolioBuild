# Edge Lab — Adversarial Screen: Direction 1 Cross-Sectional FX Cohort

Date: 2026-05-22
Author: Claude (operation lead)
Task: research_strategy `dbddc2ab-6d58-4213-b5ce-799b276364e0`
Perspective: deep_strategy_critique_and_synthesis — kill on paper before MT5 time.
Charter: `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`
Thesis bank: `docs/research/EDGE_THESES_CROSS_SECTIONAL_2026-05-22.md`

## Scope

`D:/QM/strategy_farm/artifacts/cards_review/` currently holds **twelve**
cross-sectional / relative-value FX card drafts feeding Edge Lab Direction 1
(the direction the charter says is "launching now"). This screen is an
adversarial pass over that cohort *before* any are advanced to G0 / Q02, with
two questions: (1) which cards die on paper, and (2) the cohort is badly
over-populated — which family actually goes forward.

Cards in scope:

| ea_id | slug | thesis | g0_status | quality tier |
|---|---|---|---|---|
| QM5_10717 | edgelab-xsec-fx-momentum | T1 momentum | REVIEW | B |
| QM5_10721 | edge-lab-t1-fx-relative-momentum | T1 momentum | REVIEW | **A** |
| QM5_10739 | ff-gemini-el-d1-t1-mom-v1 | T1 momentum | DRAFT | C |
| QM5_10740 | ff-gemini-el-d1-t1-mom-v2 | T1 momentum | DRAFT | C |
| QM5_10864 | edge-lab-d1-momentum-v1 | T1 momentum | DRAFT | C |
| QM5_10718 | edgelab-regime-filtered-carry | T2 carry | REVIEW | B |
| QM5_10722 | edge-lab-t2-fx-filtered-carry | T2 carry | REVIEW | **A** |
| QM5_10741 | ff-gemini-el-d1-t2-cry-v1 | T2 carry | DRAFT | C |
| QM5_10742 | ff-gemini-el-d1-t2-cry-v2 | T2 carry | DRAFT | C |
| QM5_10865 | edge-lab-d1-carry-v1 | T2 carry | DRAFT | C |
| QM5_10719 | edge-lab-t3-fx-short-reversion | T3 reversion | REVIEW | **A** |
| QM5_10720 | edge-lab-t4-safehaven-rotation | T4 safe-haven | REVIEW | **A** |
| QM5_10889 | el-d1-t8-macro-cycle | business-cycle FX | DRAFT | C |
| QM5_10894 | el-d1-t13-ctot-momentum | terms-of-trade FX | DRAFT | C |

Five T1-momentum cards and five T2-carry cards for two theses. The charter
says each surviving thesis becomes **one** family of 2–3 mechanized variants.
The cohort is ~3× over-populated and must be culled before MT5 time is spent.

## Finding 1 — BLOCKER: the portfolio EA does not fit per-symbol Q02 fanout

Every cross-sectional card in this cohort needs an EA that reads the whole FX
basket from one host chart, computes currency-strength ranks, and opens
positions on selected pairs. The V5 pipeline runs **per-symbol Q02 fanout** —
`PROFITABILITY_TRACK_2026-05-21.md` records Q02 work items dispatched "across
37 M15 DWX symbols", and `farmctl health` counts `mt5_dispatch_idle` as
per-symbol work_items. A basket EA evaluated once per symbol either (a) trades
the same basket 28 times in parallel with conflicting magic numbers, or (b)
produces zero trades on 27 of 28 fanned-out symbols and one valid run on the
host — both are pipeline-evidence garbage.

QM5_10717, 10718, 10721, 10722 each explicitly flag this: *"the per-symbol Q02
fanout must be adapted — flag for G0 / build design."* It is flagged on every
card and **resolved on none.** This is a single shared blocker, not 12 separate
ones. **No Direction-1 cross-sectional card should advance to Q02 until the
build design answers: how is a basket EA represented as a Q02 work item?**
Likely answer: one designated host symbol, basket access via `CopyRates`,
Q02 fanout suppressed to a single run — but that is a build/`farmctl`
decision OWNER/Codex must take, not something a card can assert away.

Recommended action: raise one `ops_issue` for Codex — "Define the Q02 work-item
representation for cross-sectional / multi-symbol EAs" — and gate the entire
Direction-1 cohort behind it.

## Finding 2 — Massive duplication; advance one family, reject the rest

The T1 and T2 theses are each represented five times. Tiers:

- **Tier A (advance):** QM5_10721 (T1), QM5_10722 (T2), QM5_10719 (T3),
  QM5_10720 (T4). The `edge-lab-tN` set is internally consistent: proper
  `QM5_` ids, `g0_status: REVIEW`, narrow declared P3 surfaces, cost-realism
  *and* inversion falsifications, explicit distinctness statements, FTMO blocks
  with strategy-level guards stricter than the account limits. This is the
  canonical Direction-1 family.
- **Tier B (merge then reject):** QM5_10717, QM5_10718. Well-written and they
  surfaced the fanout blocker, but they are superseded by 10721/10722 — same
  thesis, less implementation rigour. Fold any unique content (e.g. 10718's V3
  "rotate to safe-haven when RED" variant idea) into 10722's variant family,
  then reject as duplicates.
- **Tier C (reject):** QM5_10739, 10740, 10741, 10742, 10864, 10865, 10889,
  10894 — see Finding 3 for the specific defects.

Net recommendation: **4 cards advance** (10721/10722/10719/10720), 2 merge-and-
reject (10717/10718), 8 reject (10739/10740/10741/10742/10864/10865/10889/
10894). 12 → 4. The variant *families* (V1/V2/V3 per thesis) live inside the
4 surviving cards' implementation-notes, exactly as the charter intends.

## Finding 3 — Per-card kill reasons (Tier C)

- **QM5_10864 / QM5_10865** — `g0_status: DRAFT`, bare numeric `ea_id`
  (`10864`, not `QM5_10864`) — schema-noncompliant. 10864's falsification
  ("drawdown >12%") contradicts the charter's 10% total-DD box; "1% fixed risk
  per trade" is loose for a market-neutral book. **10865 depends on VIX** ("VIX
  below its 200-day SMA") — VIX is not a DWX symbol; this is an R3
  data-availability failure mislabelled `r3_data_available: true`.
- **QM5_10742** — regime filter keyed to "S&P 500 above its 200-day MA". The
  only S&P feed in the farm is `SP500.DWX`, which is **backtest-only and not
  live-tradable** (`reference_dwx_sp500_unavailable`). A live-deployable Edge
  Lab EA cannot have a live signal dependency on a backtest-only symbol.
  Reworkable (swap to a price-derived FX risk proxy) but not as written.
- **QM5_10741** — viable in principle (ATR vol filter, no external feed) but
  thinner than and fully dominated by QM5_10722; no reason to carry both.
- **QM5_10739 / QM5_10740** — thin; `expected_trades_per_year_per_symbol: 52`
  is inconsistent with a weekly rebalance holding 4 pairs (the field is
  per-symbol and the math is not shown). 10740's own falsification ("kill one
  of T1.V2 / T3 if correlation > 0.7") is a *portfolio* decision that cannot be
  evaluated from a single card. Both are dominated by 10721's variant family.
- **QM5_10889** (business-cycle FX) — the signal is "3-month change in the
  10Y–2Y yield-curve slope". Sovereign yield-curve data is **not** a DWX feed;
  `r3_data_available: true` is wrong. The card's own fallback ("spot momentum
  as a macro-proxy") collapses the thesis *into* T1 momentum — so it is either
  an R3 failure or a duplicate of QM5_10721. Also "2% risk per currency pair"
  breaches the tightened 10% box. Reject.
- **QM5_10894** (synthetic terms-of-trade) — needs "a reliable feed for 5–10
  major commodity prices" incl. iron ore, which is not a DWX symbol; uses a VIX
  filter (unavailable). R3 failure. Its own falsification concedes the test is
  "does CToT beat plain price momentum" — i.e. it is a refinement of T1, not an
  independent thesis. Reject; if the idea survives, it returns as a T1 variant
  using only DWX-available commodities (gold), not a standalone card.

## Finding 4 — Tier A cards: the real risks that remain after the cull

The four survivors are sound enough to build, but G0 must hold them to:

- **T1 (10721) and T3 (10719) — the inversion falsification is load-bearing.**
  Both correctly require that long-losers/short-winners be *significantly
  worse*. G0 must insist the inverted control is run as a sibling Q02 job, not
  asserted. Without it, a positive backtest is indistinguishable from basket
  beta.
- **T2 (10722) — the carry signal source.** 10722 commits to broker-native
  `SYMBOL_SWAP_LONG/SHORT`. That is the right call (deterministic, already
  inside the tester), but Hard Rule forbids invented swap values — G0 must
  confirm the tester swap model is broker-accurate before build, and the EA
  must log swap values at signal time (the card already requires this). Watch
  for the failure mode the card itself names: profit dominated by swap accrual
  while price PnL is negative — that does not survive a broker swap change.
- **T2/T4 — Q08 is the whole point.** 10722 and 10720 only earn their place if
  they *win or survive* the Q08 crisis slices that sink naked carry / momentum.
  Both must be run against an unfiltered control. If the filter does not
  materially cut crisis-slice DD, the card is killed — this is non-negotiable.
- **Trade-count vs zero-trade risk.** Declared `expected_trades_per_year`:
  10721=18, 10722=12, 10720=18. A weekly-rebalance basket strategy with vol-veto
  skips can legitimately produce long flat stretches; combined with the fanout
  blocker (Finding 1) this is a real `zero-trade` exposure at Q02. The build
  must ensure a flat week logs as a deliberate no-signal decision, not an
  `INIT_FAILED` / zero-trade recovery trigger.
- **Correlation crowding.** 10719 explicitly exists "to diversify T1" and
  10720 is "a hedge leg". That portfolio claim cannot be verified until all
  four run — so do not promote any single card past Q11 on its own merits as a
  "diversifier"; the diversification claim is a Q12 portfolio question.

## Verification

- All 14 cards read in full from `D:/QM/strategy_farm/artifacts/cards_review/`.
- Data-availability claims checked against memory references
  `reference_dwx_sp500_unavailable` (SP500.DWX backtest-only) and the absence
  of VIX / sovereign-yield / iron-ore feeds in the DWX symbol set.
- Per-symbol Q02 fanout confirmed against `PROFITABILITY_TRACK_2026-05-21.md`
  (Q02 dispatched across 37 DWX symbols) and the `mt5_dispatch_idle` per-symbol
  work-item count in `farmctl health` (run 2026-05-22T12:17Z, overall OK).
- No card files modified; this is a read-only screen.

## Recommended next steps (for OWNER / router)

1. **Advance to G0:** QM5_10721, QM5_10722, QM5_10719, QM5_10720 — but gate
   their Q02 entry behind Finding 1.
2. **Raise one `ops_issue` for Codex:** define the Q02 work-item representation
   for cross-sectional / multi-symbol basket EAs. Blocks the whole cohort.
3. **Reject as duplicates / R3-failures:** QM5_10717, 10718, 10739, 10740,
   10741, 10742, 10864, 10865, 10889, 10894 — move to `cards_rejected/` with
   the reasons above. Salvage 10718-V3 (safe-haven-on-RED) into 10722's family.
4. Direction-1 forward count is **4 cards**, not 12 — this is the correct
   "one engine, NNFX diversification done once" the charter calls for.

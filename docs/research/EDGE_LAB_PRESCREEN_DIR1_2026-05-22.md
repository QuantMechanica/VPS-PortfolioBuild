# Edge Lab Pre-MT5 Adversarial Screen — Direction 1 (Cross-Sectional FX)

Date: 2026-05-22
Status: SCREEN — Claude adversarial pre-build review
Charter: `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`
Thesis bank: `docs/research/EDGE_THESES_CROSS_SECTIONAL_2026-05-22.md`
Router task: research_strategy (deep_strategy_critique_and_synthesis)

## Why this document exists

`cards_review/` holds **15 Direction-1 cross-sectional-FX card drafts** but only
**4 build-ready theses** (plus 3 cards that need rework or a data check).
`ready_approved_cards` is 0 and generic research
replenishment is frozen (`edge_lab_primary`). The bottleneck is not idea
supply — it is triage. The brief is "critique why they may fail before MT5 time
is spent"; this screen does exactly that and consolidates the batch so the G0
queue carries one card per thesis, not five.

Cards read for this screen: QM5_10717, 10718, 10719, 10720, 10721, 10722,
10739, 10740, 10741, 10742, 10864, 10865, 10889, 10890, 10894.

## Finding 0 — the blocker that hits every Direction-1 card

Every cross-sectional card is a **portfolio EA**: it reads the whole 8-currency
basket from one host chart, computes currency-strength ranks, and trades several
pairs. QM5_10717 and QM5_10718 say so explicitly in their implementation notes:
*"the per-symbol Q02 fanout must be adapted — run the EA once on a designated
host symbol with basket access, or treat the basket as one logical
instrument."*

The V5 pipeline's Q02 stage fans out **per symbol**. A cross-sectional EA does
not fit that contract. Two failure modes if this is not resolved before build:

1. The EA is built as written → Q02 fanout has no valid single-symbol
   representation → the work items either cannot be scheduled or run as
   degenerate one-symbol jobs that **do not test the cross-sectional thesis**.
2. The EA is silently downgraded to a one-pair trend EA to fit the fanout →
   every Direction-1 thesis is then untested and the screen below is moot.

**Recommendation (BLOCKER, raise to OWNER + Codex before any Direction-1
build):** decide the cross-sectional execution + Q02 representation model first
— designated host symbol with `CopyRates` basket access, or a single logical
"basket instrument" registered for fanout. No Direction-1 card should reach
Codex build until this is settled. This is one decision that unblocks all 12
cards; it is the highest-leverage action in the batch.

## Finding 1 — duplication: 15 cards collapse to 4 G0 candidates

### T1 cross-sectional momentum — 5 cards, keep 1
| Card | Tier | Verdict |
|---|---|---|
| QM5_10717 `edgelab-xsec-fx-momentum` | A — full schema, inversion-test falsification, vol-crash guard, variant family V1/V2/V3 | **KEEP as T1 G0 candidate** |
| QM5_10721 `edge-lab-t1-fx-relative-momentum` | A — equivalent quality, narrower P3 grid | MERGE into 10717 (donate the explicit P3 grid `{40,60,90}` lookback) |
| QM5_10740 `ff-gemini-...-t1-mom-v2` | B — thin; 1-month lookback | REDUNDANT — 10717's V2 already is the 21-day-lookback variant. KILL |
| QM5_10739 `ff-gemini-...-t1-mom-v1` | B — thin; 3-month lookback | REDUNDANT with 10717 V1. KILL |
| QM5_10864 `edge-lab-d1-momentum-v1` | B — thin; falsification "vs random G10 basket" is weaker and underspecified (which random? reseeded per run?) | KILL — inferior falsification to 10717's inversion test |

### T2 regime-filtered carry — 5 cards, keep 1
| Card | Tier | Verdict |
|---|---|---|
| QM5_10722 `edge-lab-t2-fx-filtered-carry` | A — commits to `SYMBOL_SWAP_LONG/SHORT`, logs swap at signal time, naked-carry control | **KEEP as T2 G0 candidate** |
| QM5_10718 `edgelab-regime-filtered-carry` | A — equivalent; carry source left as "swap OR static rate table" | MERGE into 10722; donate the V3 idea (rotate to JPY/CHF/USD when filter RED) as a future variant |
| QM5_10741 `ff-gemini-...-t2-cry-v1` | B — thin; ATR-vol filter | KILL — subset of 10722 |
| QM5_10742 `ff-gemini-...-t2-cry-v2` | B — thin; equity-proxy (S&P 200-SMA) filter, needs cross-symbol SPX data | KILL — duplicate; donate the equity-proxy-filter idea as a 10722 variant |
| QM5_10865 `edge-lab-d1-carry-v1` | B — **uses `VIX < 200-day SMA` as the filter** | KILL — see Finding 2 |

### T3 / T4 — 1 card each, no duplication
- QM5_10719 `edge-lab-t3-fx-short-reversion` — Tier A, clean. **KEEP.**
- QM5_10720 `edge-lab-t4-safehaven-rotation` — Tier A, clean, Q08-judged. **KEEP.**

### Extra "T8 / T9 / T13" cards — not Direction-1-ready
- QM5_10889 `el-d1-t8-macro-cycle` — see Finding 3.
- QM5_10890 `el-d1-t9-cbi-rs` — see Finding 4.
- QM5_10894 `el-d1-t13-ctot-momentum` — see Finding 3.

**Net:** the G0 queue for Direction 1 should carry **4 cards** (10717, 10722,
10719, 10720), not 15. Killing the 7 thin/duplicate cards plus merging 2 and
blocking 2 removes ~9 redundant G0 reviews and the matching Q02 fanouts.

## Finding 2 — `VIX < 200-day SMA` cannot be the carry filter (QM5_10865)

Two hard defects, either one fatal:

1. **Data:** VIX is not a standard MT5 Strategy Tester symbol on the DWX feed.
   The card asserts `r3_data_available: true` but names no DWX VIX series. The
   carry filter has no input → the EA cannot be built as written.
2. **Even with a VIX proxy, a 200-day SMA is too slow.** In Feb–Mar 2020 VIX
   crossed its own 200-day SMA only *after* the carry crash was underway. A
   filter that flips RED after the drawdown does not cap the left tail — and the
   thesis bank's own T2 falsification ("filtered-carry crisis-slice DD must be
   materially better than naked carry") would then fail. QM5_10722's 20-day
   realized-vol percentile + 5-day adverse-return veto is the correct fast gate.

QM5_10865 is dominated by QM5_10722 on both data feasibility and filter speed.
**KILL.**

## Finding 3 — theses that need data the MT5 tester does not have

- **QM5_10889 (T8 business-cycle timing)** wants the "10Y-2Y yield-curve
  slope." That series is not in the tester. The card then substitutes
  *"trailing 3-month spot momentum as a macro-proxy"* — at which point T8 **is**
  cross-sectional momentum (T1) and its own falsification ("must outperform a
  carry/momentum portfolio") is self-defeating: it cannot beat momentum because
  it *is* momentum. **KILL or REWRITE** — only viable if a checked-in yield
  series is added; otherwise it is a hidden duplicate of QM5_10717.
- **QM5_10894 (T13 commodity terms-of-trade)** needs Oil, Copper, Iron Ore,
  Gold price feeds inside a single backtest. Iron Ore is not a tradeable DWX
  symbol; cross-symbol historical access inside one MT5 backtest is constrained.
  `r3_data_available: true` is unverified. **BLOCK pending a data-feasibility
  check** — confirm which of the 4 commodity series are actually loadable in the
  tester before this reaches build.

These two should not consume a G0 slot until their data question is closed.
Evidence over claims (Hard Rule): a card may not assert `r3_data_available:
true` for a series no one has confirmed is in the feed.

## Finding 4 — QM5_10890 (CBI-RS) fails on sample size and contamination

- **Sample size:** the card's own falsification says "negative expectancy over
  10 documented intervention-like events." Ten events is not a statistical
  sample. Q08/Q11 cannot certify an edge on ~10 observations — the result will
  be noise either way.
- **Contamination:** it names EUR/CHF as a focus pair. EUR/CHF history is
  dominated by the 2011–2015 SNB floor and the Jan-2015 de-peg — a structural
  break, not a repeatable "intervention cycle." A backtest spanning it measures
  one unrepeatable event.
- **Backtest realism:** the card admits "extreme slippage during interventions"
  then proposes tight stops with 1:2 R:R. The MT5 tester with modelled spread
  will *not* reproduce intervention slippage, so a tester PASS would be a false
  positive — an evidence-integrity risk at Q08/Q11.

**KILL.** The CBI-RS thesis is not falsifiable within the farm's data and gate
model.

## Synthesis — recommended Direction-1 action

1. **BLOCKER:** resolve the cross-sectional EA / Q02 representation model
   (Finding 0) — OWNER + Codex decision. Nothing else proceeds without it.
2. Advance **4 cards** to G0: QM5_10717 (T1), QM5_10722 (T2), QM5_10719 (T3),
   QM5_10720 (T4). These four are the FTMO-friendly market-neutral core and
   together form one diversified engine, as the charter intends.
3. **KILL 7 cards** as duplicate/dominated: QM5_10739, 10740, 10741, 10742,
   10864, 10865, 10890.
4. **MERGE 2 cards** into the survivors: QM5_10721 → 10717, QM5_10718 → 10722.
5. **BLOCK 2 cards** pending data feasibility: QM5_10889 (yield series),
   QM5_10894 (commodity series).

Build order once Finding 0 is resolved: T1 → T2 → T4 → T3 (T4 is the Q08 hedge
leg, prioritised above T3 because it earns its keep precisely where T1/T2
bleed). Each is built as a 2–3 variant family; the gates remain the sole judge.

## Verification

- 15 Direction-1 cards confirmed present in `D:/QM/strategy_farm/artifacts/
  cards_review/` (directory listing, 2026-05-22).
- All card IDs, falsification clauses, and data claims above were read directly
  from the card files, not summarised from titles.
- No card files were created, edited, or deleted by this screen — it is
  advisory input to G0. Kill/merge decisions are recommendations for the G0
  reviewer and OWNER, not executed here.

---
title: Dual-Gate Registry — Full Queue State
date: 2026-05-13
last_updated: 2026-05-15
qa_agent: Quality-Business (0ab3d743-e3fb-44e5-8d35-c05d0d78715d)
supersedes: processes/strategy_cards/g1_approved_2026-05-09.md (still canonical for G1 audit)
policy_ref: processes/qb_reputable_source_criteria.md (rev 2, BINDING 2026-04-29)
status: BINDING
scope: All Strategy Cards through SRC06, as of 2026-05-13
changelog:
  - 2026-05-15: singh-cmd-corr DEFERRED (WTI.cash.DWX + USDX.f unavailable; no Darwinex USD-index equivalent; QUA-1537 c5c3b3c1)
  - 2026-05-15: queue count updated 32 → 31 P0-ready (singh-cmd-corr moved to Deferred)
  - 2026-05-15: singh-swap-fly friday_close=false ratification DONE (OWNER approved QUA-1527); P0 build QUA-1563 dispatched to Dev-Codex
  - 2026-05-15: QUA-1562 master directive active; 3 corrected-v2 cards G0/G1 approved and P0 builds dispatched (SRC01_S06, SRC02_S09, SRC04_S18)
  - 2026-05-15: QB G1 compliance audit queue open for QUA-1571/1572/1573/1574/1563 (pending Dev-Codex builds)
---

# Dual-Gate Registry — Full Queue State (2026-05-13)

## Purpose

This document records the complete dual-gate (CEO G0 + QB G1) status of every strategy card in
the pipeline as of 2026-05-13, after three gate events since the initial QB hire:
- QB G1 batch verdict: QUA-1059, commit `07c2d2f9f` (origin/main)
- CEO G0 review of 10 DRAFT cards: issue e6fefd6a (done)
- SRC06 Singh 14 cards on disk: commit `aada40eba` (origin/main)

**Phantom file note:** CEO comment on e6fefd6a claimed `g0_g1_dual_gate_2026-05-09.md` at commit
`7f9bbc9b`. This commit does not exist in the repo (confirmed via `git cat-file -e 7f9bbc9b`).
The CEO's verbal disposition (10 APPROVED + 5 DEFERRED) is authoritative via the issue thread;
this document supplies the missing on-disk artifact.

---

## 1. Already in Pipeline (do not re-dispatch P0 build)

| Card | Slug | ea_id | State |
|---|---|---|---|
| SRC02_S01 | chan-pairs-stat-arb | 1017 | In pipeline |
| SRC04_S03 | lien-fade-double-zeros | 1009 | In pipeline |
| SRC04_S08 | lien-channels | 1014 | In-flight (QUA-1090 — Dev build complete; P2 matrix running) |

---

## 2. P0-Ready Build Queue — Original Cohort (CTO QUA-1109 schedule)

Dual-APPROVED cards scheduled by CTO at QUA-1109 (commit `e04fa895`).
EA IDs 1018/1019 registered at commit `8af10429`.

| # | Card | Slug | ea_id | Lane | P0 build issued? | QB flag |
|---|---|---|---|---|---|---|
| 1 | SRC04_S04 | lien-waiting-deal | 1010 | A | TBD | — |
| 2 | SRC04_S05 | lien-inside-day-breakout | 1011 | B | TBD | — |
| 3 | SRC04_S06 | lien-fader | 1012 | A | QUA-bc002b3f (blocked) | — |
| 4 | SRC04_S07 | lien-20day-breakout | 1013 | B | TBD | — |
| 5 | SRC04_S09 | lien-perfect-order | 1015 | A | QUA-456b6660 (blocked) | — |
| 6 | SRC04_S11 | lien-carry-trade | 1016 | B | TBD | R3 conditional: bond-yield-threshold at P3 |
| 7 | SRC03_S16 | williams-pro-go | 1018 | A | TBD | — |
| 8 | SRC03_S17 | williams-pinch-paunch | 1019 | B | TBD | R3 conditional: bare Pinch/Paunch at P3 |

---

## 3. P0-Ready Build Queue — CEO G0 Approval Batch (e6fefd6a, 2026-05-09)

10 cards previously DRAFT; CEO G0 APPROVED via issue e6fefd6a comment (2026-05-09T11:32:26Z).
QB G1 was already complete for all 10 in batch `07c2d2f9f`.
EA IDs not yet allocated for this cohort; CTO must extend registry before P0 dispatch.

| # | Card | Slug | Timeframe | Style | QB flag |
|---|---|---|---|---|---|
| 9 | SRC03_S01 | williams-vol-bo | D1 | vol-expansion-breakout | — |
| 10 | SRC04_S02a | lien-dbb-pick-tops | H4/D1 | range / mean-reversion | — |
| 11 | SRC04_S02b | lien-dbb-trend-join | H4/D1 | trend / bband | — |
| 12 | SRC05_S01 | chan-at-bb-pair | pair / cointegration | stat-arb | ⚑ pair-EA infra needed |
| 13 | SRC05_S02 | chan-at-kf-pair | pair / Kalman | stat-arb | ⚑ pair-EA infra needed |
| 14 | SRC05_S03 | chan-at-buy-on-gap | D1 | gap-reversion | ⚑ equity venue; Darwinex CFD mapping needed |
| 15 | SRC05_S05 | chan-at-fx-coint-pair | FX pair | cointegration | — |
| 16 | SRC05_S06 | chan-at-cal-spread | pair | calendar spread | ⚑ calendar-spread infra; CTO confirmed at P0 |
| 17 | SRC05_S07 | chan-at-ts-mom-fut | futures | time-series momentum | ⚑ futures universe mapping |
| 18 | SRC05_S12 | chan-at-fstx-gap-mom | futures/D1 | gap momentum | ⚑ futures mapping |

---

## 4. P0-Ready Build Queue — SRC06 Singh Cohort (aada40eba, 2026-05-09)

14 cards committed to origin/main. Cards show `status: APPROVED` with g0/g1 dual-gate in headers
(CEO disposition per QUA-1110 directive + QUA-1059 QB G1). EA IDs TBD — all need registry allocation.

| # | Card | Slug | Timeframe | Style | QB flag |
|---|---|---|---|---|---|
| 19 | SRC06_S01 | singh-rapid-fire | M1 | scalping / trend | ⚑ P5b-latency: M1 + 10-pip TP; Darwinex commission brutal at M1 |
| 20 | SRC06_S02 | singh-piranha | M5 | scalping / MR | ⚑ P5b-latency flag |
| 21 | SRC06_S03 | singh-fade-break | M15/M30 | fade / MR | — |
| 22 | SRC06_S04 | singh-trade-break | M15/M30 | breakout | — |
| 23 | SRC06_S07 | singh-trend-rider | H1/H4 | trend / EMA-cross | — |
| 24 | SRC06_S08 | singh-trend-bouncer | H1/H4 | BB-pullback | — |
| 25 | SRC06_S09 | singh-fifth-element | H1/H4 | MT4-MACD / trend | ⚑ MT4 MACD impl note; P7 overfit flag (5-bar pattern) |
| 26 | SRC06_S10 | singh-power-ranger | H1/H4 | range / stochastic | — |
| 27 | SRC06_S11 | singh-pendulum | H1/H4 | range / S&R bounce | — |
| 28 | SRC06_S12 | singh-swap-fly | D1/W1 | carry + pattern | ⚑ friday_close=false exception: needs CEO + OWNER ratification before P0 |
| ~~29~~ | ~~SRC06_S13~~ | ~~singh-cmd-corr~~ | ~~D1~~ | ~~intermarket corr~~ | **DEFERRED 2026-05-15** — WTI.cash.DWX unavailable; USDX.f unavailable with no Darwinex equivalent (QUA-1537) |
| 30 | SRC06_S15 | singh-guppy-burst | M5 | range-bracket / ToD | ⚑ P5b-latency (M5 GBPJPY) |
| 31 | SRC06_S16 | singh-eng-bk-tea | M15 | ToD / fade | ⚑ London DST-sensitive; broker-time validation needed at P0 |
| 32 | SRC06_S17 | singh-gd-morn-asia | D1 | ToD / momentum | ⚑ inverted R:R flag (thin-thesis risk); P3 must validate positive expectancy |

---

## 5. Deferred — Instrument Unavailable or CEO Hold (not P0-ready)

5 SRC05 cards deferred by CEO at e6fefd6a; QB G1 APPROVED (R1-R4 pass), CEO G0 DEFERRED.
Unblock trigger: Darwinex instrument-mapping confirmation OR portfolio-of-N framework landing.

1 SRC06 card deferred by QB portfolio-fit verdict 2026-05-15 (instrument unavailability confirmed):
Unblock trigger: Darwinex adds USD-index instrument (USD futures, DXY CFD, or equivalent).

| Card | Slug | Defer reason | Source |
|---|---|---|---|
| SRC05_S04 | chan-at-spy-arb | SPX-component basket; no Darwinex multi-stock CFD coverage | CEO hold (e6fefd6a) |
| SRC05_S08 | chan-at-roll-arb-etf | ETF roll; ETFs not Darwinex-native | CEO hold (e6fefd6a) |
| SRC05_S09 | chan-at-vx-es-roll-mom | VX/ES futures; VX not Darwinex | CEO hold (e6fefd6a) |
| SRC05_S10 | chan-at-xs-mom-fut | Cross-sectional futures; universe mapping required | CEO hold (e6fefd6a) |
| SRC05_S11 | chan-at-xs-mom-stock | Cross-sectional stocks; Darwinex CFD availability uncertain | CEO hold (e6fefd6a) |
| SRC06_S13 | singh-cmd-corr | USDX.f unavailable + no Darwinex USD-index equivalent confirmed (QUA-1537); crude substitute XTIUSD.DWX exists but USD-index leg fatal to intermarket thesis | QB verdict 2026-05-15 (c5c3b3c1) |

---

## 6. Queue Summary

| Category | Count | Notes |
|---|---|---|
| Already in pipeline | 3 | |
| P0-ready (CTO QUA-1109 cohort) | 8 | |
| P0-ready (CEO e6fefd6a cohort) | 10 | |
| P0-ready (SRC06 Singh cohort) | 13 | singh-cmd-corr DEFERRED 2026-05-15 |
| **Total P0-ready new builds** | **31** | was 32; singh-cmd-corr removed |
| Deferred (instrument unavailable or CEO hold) | 6 | +1 singh-cmd-corr vs 2026-05-13 |

CTO QUA-1109 schedule covers 8 of the 31 P0-ready builds. **23 cards are outside the current
CTO schedule** and need P0 build ticket dispatch.

---

## 7. Portfolio-Fit Assessment (Full 32-card P0 queue)

This assessment applies to the build QUEUE, not the live portfolio. Portfolio caps (30%/timeframe,
40%/market, 50%/style) apply at P9 inclusion decision, not at P0 build. Flag here = monitor
at P9, not a P0 blocker.

### Timeframe concentration

| Timeframe | Count | % of queue |
|---|---|---|
| M1 | 1 | 3% |
| M5 | 2 | 6% |
| M15/M30 | 3 | 9% |
| H1/H4 | ~10 | 31% |
| D1+ | ~9 | 28% |
| Pair/multi-symbol | ~7 | 22% |

**Flag: H1/H4 at 31% of queue — marginally above 30% cap.** Not a P0 blocker; caps apply
at P9 live-portfolio inclusion. CEO/portfolio manager should throttle H1/H4 at P9 if needed.

### Market concentration

| Market | Count | % of queue |
|---|---|---|
| Forex (single-pair) | ~22 | ~71% |
| Pair/cointegration | ~7 | ~23% |
| Commodities/indices (cal-spread, futures-mapped) | ~2 | ~6% |

**Update 2026-05-15:** singh-cmd-corr (the primary commodity/intermarket card) removed (DEFERRED).
Forex concentration rises slightly from ~69% to ~71% as the non-forex D1 intermarket card exits.

**Flag: Forex single-pair at ~71% of queue significantly exceeds the 40% market cap.**
QB asks CEO to clarify: does the 40% forex cap apply to the DXZ-native forex universe
(where 90%+ of available instruments are FX pairs) or to a fully diversified cross-asset
portfolio? If Darwinex's deployable universe is FX-dominant, the cap may need recalibration
for DXZ context. Flagging for CEO strategic decision — not blocking P0 builds.

**Concentration pressure:** Removing singh-cmd-corr makes the SRC07 diversity-offset rule
([QUA-1533](/QUA/issues/QUA-1533)) more critical — it is now the primary mechanism for introducing
non-forex, non-D1 diversity into the build queue.

### Style concentration

| Style | Count | % of queue |
|---|---|---|
| Trend-following / momentum | ~10 | ~31% |
| Mean-reversion / range | ~10 | ~31% |
| Breakout | ~4 | ~13% |
| Carry / position | ~3 | ~9% |
| Correlation / pair stat-arb | ~5 | ~16% |

**Style is balanced.** Trend-following at 31% — well within the 50% cap. No style-concentration flag.

### Pre-P0 action flags (must-resolve before P0 dispatch)

| Flag | Cards affected | Owner | Status |
|---|---|---|---|
| friday_close=false exception ratification | singh-swap-fly | CEO + OWNER | **RESOLVED 2026-05-15** — OWNER approved (QUA-1527 done); P0 build dispatched (QUA-1563 todo→Dev-Codex) |
| WTI.cash.DWX + USDX.f availability | singh-cmd-corr | CTO / Pipeline-Op | **RESOLVED 2026-05-15** — both unavailable; USDX.f no Darwinex equivalent → card DEFERRED |
| EA ID allocation | All Singh + CEO batch (13+10 cards) | CTO (registry) | open |
| Pair-EA MT5 infrastructure | chan-at-bb-pair, chan-at-kf-pair, chan-at-fx-coint-pair, chan-at-cal-spread | CTO | open (QUA-1465 chain blocked) |
| Darwinex instrument mapping | chan-at-buy-on-gap, chan-at-ts-mom-fut, chan-at-fstx-gap-mom | CTO / CEO | open |

### Scalping P5b flags

singh-rapid-fire (M1), singh-piranha (M5), singh-guppy-burst (M5) carry P5b latency flags.
Darwinex DMA commissions + spread at M1/M5 create high execution-risk. Recommend: confirm
Darwinex spread/commission assumptions at P0 scaffold stage and add slippage-sensitivity axis
at P5b. These are NOT P0 blockers — the pipeline will filter them.

---

## 8. Next Actions

| Priority | Action | Owner | Status |
|---|---|---|---|
| HIGH | Allocate EA IDs for 23 un-scheduled cards (10 CEO batch + 13 Singh) | CTO (registry) | open |
| ~~HIGH~~ | ~~Ratify singh-swap-fly friday_close=false exception~~ | ~~CEO + OWNER~~ | **DONE 2026-05-15** — OWNER approved; P0 build on QUA-1563 |
| ~~HIGH~~ | ~~Confirm WTI.cash.DWX + USDX.f availability~~ | ~~CTO~~ | **DONE 2026-05-15** — both unavailable; singh-cmd-corr DEFERRED |
| MEDIUM | Extend P0 build-ticket dispatch beyond QUA-1109 cohort | CTO | open |
| MEDIUM | Clarify 40% forex-market cap scope for DXZ portfolio | CEO | open |
| MEDIUM | Pair-EA infrastructure confirmation (SRC05 stat-arb cards) | CTO | open (QUA-1465 chain blocked) |
| LOW | Darwinex instrument mapping for futures-dependent cards (S03, S07, S12) | CTO / CEO | open |
| LOW | H1/H4 throttle policy at P9 if concentration exceeds 30% live | CEO | open |

---

*QB Quality-Business — 2026-05-13, updated 2026-05-15. CEO final authority on all G0 decisions.
This registry documents QB's stewardship view; CEO resolves flagged items.*

---

## Appendix: Post-2026-05-13 Pipeline Events (QB monitoring)

| Date | Event | Impact |
|---|---|---|
| 2026-05-15 | QUA-1460 cancelled (stat-arb infra runaway loop) | QM5_1017 pair pipeline stalled; SRC05 stat-arb cards (⚑ pair infra) blocked |
| 2026-05-15 | P2 verdicts final: QM5_1014 BASELINE_ACCURATE_FAILED; QM5_1003/1004/1017/SRC04_S03 STRATEGY_DRIFT | No new PASS at P2; 5 EAs in recovery or failed |
| 2026-05-15 | singh-cmd-corr DEFERRED — WTI.cash.DWX + USDX.f both unavailable; no USD-index equivalent on Darwinex | Build queue: 32 → 31 cards; forex concentration: ~69% → ~71% |
| 2026-05-15 | QUA-1527 DONE — OWNER ratified singh-swap-fly `friday_close=false` exception | Pre-P0 flag cleared; P0 build QUA-1563 dispatched (singh-swap-fly, D1/W1 carry, Dev-Codex) |
| 2026-05-15 | QUA-1562 master directive: continuous pipeline loop active; CEO + QB G0/G1 gate | New operating model: Research → G0/G1 → P0 → G1 compliance audit → P1-P7 |
| 2026-05-15 | 3 corrected-v2 cards G0/G1 dual-APPROVED; P0 builds dispatched | SRC01_S06 (davey-3bar-eu-h4, EURUSD H4) → QUA-1571+QUA-1574; SRC02_S09 (chan-audcad-mr, AUDCAD D1) → QUA-1572; SRC04_S18 (lien-fade-00-asia, EURUSD Asian) → QUA-1573; all Forex single-pair |
| 2026-05-15 | QB G1 compliance audit queue: 5 P0 build issues pending Dev-Codex completion | QUA-1571/1574 (SRC01_S06), QUA-1572 (SRC02_S09), QUA-1573 (SRC04_S18), QUA-1563 (SRC06_S12) |

### Portfolio-fit note: new P0 builds are all Forex

All 4 EAs currently being built are Forex single-pair (EURUSD H4, AUDCAD D1, EURUSD Asian, singh-swap-fly FX-carry).
Combined with the ~71% forex concentration already in the build queue, QB flags this for OWNER/CEO awareness at P9.
Caps apply at P9 live-portfolio inclusion (not at P0 build) — no action needed now; flag for P9 portfolio inclusion decisions.

### Duplicate P0 build flag: QUA-1571 vs QUA-1574

Both QUA-1571 and QUA-1574 are P0 builds for the same strategy (SRC01_S06 davey-3bar-eu-h4, same card file).
QUA-1571 was dispatched by CEO from QUA-1562; QUA-1574 was opened during QUA-1566 G0 closure.
CEO/CTO should cancel one to avoid dual EA binary deployment. QB flags this for CEO resolution — not QB's scope.

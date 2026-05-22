# Edge Lab — cards_review Adversarial Pre-MT5 Screen

Date: 2026-05-22
Author: Claude (orchestration cycle, router task 39ff5c2a)
Status: SCREEN — advisory input to G0 review, not a gate verdict
Scope: all 27 card drafts currently in `D:/QM/strategy_farm/artifacts/cards_review/`
Charter: `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`

## Why this artifact instead of two more cards

The router task brief is "find or synthesize high-conviction strategy
directions **and critique why they may fail before MT5 time is spent**", with
`dedupe_required: true`. Inventory at cycle time: `cards_review/` already holds
**27** card drafts, generic research replenishment is **frozen**
(`generic_research_replenishment_frozen_edge_lab_primary`), and `health` shows
`unbuilt_cards_count` and `unenqueued_eas_count` both clear. The reservoir is not
starved of *cards* — it is starved of *screened, deduplicated* cards. Adding two
more generic drafts would worsen a glut and is exactly what the dedupe rule
exists to prevent. The high-value Claude artifact here is the adversarial screen
itself: kill/merge the redundancy on paper before any of these 27 consume a
T1–T10 slot.

## Headline: the backlog is ~27 drafts but ~14 distinct theses

Cross-sectional FX momentum and regime-filtered carry are each carded **five
times**. That is 10 drafts for 2 theses. Building them as 10 separate `ea_id`s
would burn ~10× the MT5 time for ~2× the information and will trip the G0
dedupe / Q-gate fingerprint logic. The screen below collapses them.

## Per-card verdict

Legend — KEEP: build as-is; MERGE: fold into a named variant family, do not
build standalone; FIX: build only after the listed defect is resolved at G0;
KILL: do not build, reason given.

### Cluster 1 — Cross-sectional FX momentum (Edge Lab T1)

| Card | Author | Verdict | Note |
|---|---|---|---|
| QM5_10717 `edgelab-xsec-fx-momentum` | Claude | **KEEP — family parent** | Cleanest spec; already carries an explicit V1/V2/V3 variant family (63d / 21d / +vol-crash-filter). Make this the single T1 build. |
| QM5_10721 `edge-lab-t1-fx-relative-momentum` | Codex | MERGE → QM5_10717 | Same thesis, 60d lookback, weekly rebalance. Differences (spread filter, 0.30% live risk) are parameter choices — fold in as build detail, not a new ea_id. |
| QM5_10739 `ff-gemini-el-d1-t1-mom-v1` | Gemini | MERGE → QM5_10717 V1 | 3-month lookback == QM5_10717 V1. Schema-thin (`g0_status: DRAFT`, no Q-prefixed section headers). |
| QM5_10740 `ff-gemini-el-d1-t1-mom-v2` | Gemini | MERGE → QM5_10717 V2 | 1-month lookback == QM5_10717 V2. Its own falsification note ("kill one if corr>0.7 with T3") is sound — keep that test, drop the card. |
| QM5_10864 `edge-lab-d1-momentum-v1` | — | MERGE → QM5_10717 | Top/bottom-3 instead of top/bottom-2; "use EMA-smoothed returns" is an undocumented degree of freedom. Fold the top-3 idea in as a sweep point. |

**Net:** 5 cards → 1 build (QM5_10717) with a 3-variant family. Kill 4 ea_ids.

### Cluster 2 — Regime-filtered carry (Edge Lab T2)

| Card | Author | Verdict | Note |
|---|---|---|---|
| QM5_10722 `edge-lab-t2-fx-filtered-carry` | Codex | **KEEP — family parent** | Strongest of the five: pins the carry signal to broker-native `SYMBOL_SWAP_LONG/SHORT` (deterministic, in-tester), narrow P3 grid, explicit naked-carry control. No external feed needed. |
| QM5_10718 `edgelab-regime-filtered-carry` | Claude | MERGE → QM5_10722 | Same thesis; vol-median filter == QM5_10722 V1. Its V3 (rotate to JPY/CHF safe-haven when RED) is a genuinely distinct idea — preserve it as a QM5_10722 variant or as QM5_10720's scope. |
| QM5_10741 `ff-gemini-el-d1-t2-cry-v1` | Gemini | MERGE → QM5_10722 | ATR-vol filter == QM5_10722 V1. |
| QM5_10742 `ff-gemini-el-d1-t2-cry-v2` | Gemini | FIX then MERGE | Equity-proxy filter is a fine variant, but "S&P 500 above 200-DMA" needs a routable index proxy — use `NDX.DWX`/`WS30.DWX`, not `SP500.DWX` (backtest-only, not live-routable). Fold as QM5_10722 V2. |
| QM5_10865 `edge-lab-d1-carry-v1` | — | FIX then MERGE | "VIX below 200-DMA" filter — **VIX is not a confirmed DWX feed.** Re-express the regime filter on a price-derived realized-vol proxy (as QM5_10722 already does) or kill. |

**Net:** 5 cards → 1 build (QM5_10722) with a 2–3-variant family. Kill/merge 4.

### Cluster 3 — Other cross-sectional FX (distinct theses, KEEP)

| Card | Verdict | Note |
|---|---|---|
| QM5_10719 `edge-lab-t3-fx-short-reversion` | **KEEP** | Distinct horizon (3–5d reversion). Cost-fragile by its own admission — make net-of-cost expectancy across ≥20 nonzero trades the hard P2 kill, and require corr<0.7 vs QM5_10717 (per QM5_10740's note) or one dies. |
| QM5_10720 `edge-lab-t4-safehaven-rotation` | **KEEP** | Distinct (risk-off conditioned hedge leg). Judge mainly on Q08 slice contribution, as the card states. Watch correlation crowding into a single JPY factor. |
| QM5_10889 `el-d1-t8-macro-cycle` | **FIX** | Business-cycle xsec needs a 10Y–2Y yield-curve input — **not a price feed the farm has** (`r3_data_available` is overclaimed). Either re-spec on a pure price macro-proxy or mark R3 FAIL at G0. Also: card claims a framework `xsec_rank_logic` module that **does not exist** (verified — see EDGE_BUILD_READINESS). |
| QM5_10894 `el-d1-t13-ctot-momentum` | **FIX** | Commodity terms-of-trade needs oil/copper/**iron ore** feeds; iron ore is not a DWX symbol. Constrain v1 to commodities actually present (`XTIUSD`, `XAUUSD`, maybe `XNGUSD`) or mark R3 FAIL. |

### Cluster 4 — Event / calendar (Direction 2 & 3)

| Card | Verdict | Note |
|---|---|---|
| QM5_10349 `savor-wilson-macro-announcement-idx` | **KEEP — FTMO ruling needed** | Well-built, strong dedupe notes, FOMC excluded. **But it intentionally holds through CPI/employment releases** — the charter mandates a news blackout and says it overrides `allow_fomc_hold`. Needs an explicit G0/OWNER ruling that "trade the scheduled risk-premium day" is inside the charter's "trade the drift, not the spike" carve-out. Without that ruling it fails the FTMO-compliance check. |
| QM5_10350 `savor-wilson-macro-beta-spread` | **KEEP — same ruling + ops** | Two-leg NDX/WS30 spread; card honestly flags it may need `OPS_FIX_REQUIRED` if V5 cannot trade paired legs from one EA. Same news-blackout ruling as QM5_10349. |
| QM5_10766 `pre-nfp-drift` | **KEEP** | Cleanly blackout-safe — enters Thu, exits 2h pre-release. Lowest charter risk of the event cluster. |
| QM5_10891 `el-d2-t10-fomc-drift` | **MERGE → QM5_10260 variant queue** | Pre-FOMC drift is variant #2 ("decay-aware pre-FOMC drift") in `PROFITABILITY_TRACK_2026-05-21.md`. Carding it as an independent Edge Lab ea_id fragments the FOMC family and risks the dedupe gate against the active lead QM5_10260. Route to the QM5_10260 variant queue, do not build standalone now. |
| QM5_10768 `fomc-post-mom` | **MERGE → QM5_10260 variant queue** | Post-FOMC continuation == variant #3 in the same track. Same fragmentation risk. Also enters 2h post-FOMC — needs the same blackout ruling. |
| QM5_10767 `idx-earnings-drift` | **FIX / likely KILL** | Needs an AAPL/MSFT/NVDA earnings calendar — **not in the `news_calendar` seed.** And 4 trades/yr/symbol can never build a statistically meaningful Q08/Q11 slice. Low conviction; defer behind everything else. |

### Cluster 5 — Calendar / seasonal (Direction 3)

| Card | Verdict | Note |
|---|---|---|
| QM5_10763 `fx-month-end-rebal` | **KEEP — but deconflict with QM5_10892** | Month-end equity-hedge FX flow. |
| QM5_10892 `el-d3-t11-month-end-rev` | **MERGE / deconflict** | Same window (last 2–3 trading days of month), same FX universe, as QM5_10763 — but QM5_10763 trades the rebalancing-flow *direction* while QM5_10892 trades MTD-overperformer *reversion*. These are near-opposite signals on the same bars: build **one** card that tests both directions as a sweep, or they will be each other's falsification control. Do not build both as separate ea_ids. |
| QM5_10764 `idx-totm` | **KEEP** | Turn-of-month index; needs multi-exchange holiday calendars — confirm at G0. |
| QM5_10765 `gold-monthly-seasonal` | **KILL / lowest priority** | Pure month-of-year seasonality on one symbol (XAUUSD). Falsification ("beat average monthly return") is weak; ~12 trades/yr; the structural cause (wedding/festival demand) is folklore-grade and easily a backtest artifact. If kept, it is the last thing to ever build. |

### Cluster 6 — Microstructure (Direction 4)

| Card | Verdict | Note |
|---|---|---|
| QM5_10769 `london-fix-reversion` | **KEEP — cost gate** | Well-specified M15 intraday reversion; DST mapping flagged. ~120 trades/yr — make net-of-cost expectancy over ≥200 trades the hard kill. |
| QM5_10893 `el-d4-t12-ls-ob-micro` | **FIX — highest failure odds** | SMC liquidity-sweep/order-block. The charter itself ranks SMC last/highest-risk. Concrete defect: a "2-pip beyond the sweep extreme" stop on M5 majors is inside realistic DWX spread+commission — almost certainly net-negative before logic even matters. Re-spec the stop in ATR terms and prove cost realism, or do not build. |
| QM5_10890 `el-d1-t9-cbi-rs` | **KILL — statistically dead on arrival** | Central-bank-intervention relative strength. Its own falsification needs "10 documented intervention-like events" — that is the entire sample. No backtest can reach Q08/Q11 statistical significance on ~10 events. Discretionary "intervention zone" detection. Kill before any MT5 time. |

## Recommended G0 review order (build sequence)

1. **QM5_10722** (filtered carry, family parent) — no external feed, swap-native, clean falsification.
2. **QM5_10717** (xsec momentum, family parent) — Direction 1 flagship per the charter.
3. **QM5_10719** + **QM5_10720** (T3 reversion, T4 safe-haven) — Direction 1 diversifiers.
4. **QM5_10349 / QM5_10350** — only after the news-blackout-vs-announcement charter ruling.
5. **QM5_10766**, **QM5_10763** (deconflicted with 10892), **QM5_10764** — calendar batch.
6. **QM5_10769** — microstructure, cost gate.
7. Deferred / fix-first: QM5_10889, QM5_10894 (data), QM5_10767 (data + sample), QM5_10893 (cost), QM5_10765 (weak thesis), QM5_10890 (KILL).
8. Route QM5_10891 + QM5_10768 to the **QM5_10260 variant queue**, not standalone builds.

## Bottom line for the factory

- 27 drafts → **~11 distinct builds** worth MT5 time after merge/kill.
- Killing the 10-into-2 momentum/carry redundancy is the single biggest MT5-time
  saving available right now and is mandatory under `dedupe_required`.
- Two cards (QM5_10349/10350) are **blocked on a charter ruling**, not on code —
  surface to OWNER/G0 before they enter the queue.
- One card (QM5_10890) should be killed outright; three more (10765, 10767,
  10893) are low-conviction and should sit behind everything else.

# Edge Lab Pre-MT5 Adversarial Screen — Directions 2 / 3 / 4

Date: 2026-05-22
Status: SCREEN — Claude adversarial pre-build review
Charter: `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`
Thesis bank: `docs/research/EDGE_THESES_BREADTH_2026-05-22.md`
Companion: `docs/research/EDGE_LAB_PRESCREEN_DIR1_2026-05-22.md`
Router task: research_strategy (deep_strategy_critique_and_synthesis)

## Why this document exists

Beyond the 15 Direction-1 cards (screened separately) `cards_review/` holds
**12 cards for Directions 2 (event-conditioned), 3 (calendar/seasonal), and 4
(SMC)**. The brief is "critique why they may fail before MT5 time is spent."
The honest finding: the batch is uneven — two cards are build-ready, two have
fatal data or thesis defects, and two more directly contradict each other.
Screening on paper here is far cheaper than burning T1–T10 time on cards that
the gates would kill or that cannot be built at all.

Cards read for this screen: QM5_10349, 10350, 10763, 10764, 10765, 10766,
10767, 10768, 10769, 10891, 10892, 10893.

## Direction 2 — Event-conditioned

| Card | Verdict | Reason |
|---|---|---|
| QM5_10349 `savor-wilson-macro-announcement-idx` | **KEEP → G0** | Tier A. Full schema, explicit dedupe notes vs QM5_10260, FOMC dates excluded by design, calendar-based, no surprise data. Clean. |
| QM5_10350 `savor-wilson-macro-beta-spread` | **KEEP → G0** | Tier A. Paired NDX-long / WS30-short beta spread. Honestly flags the two-leg execution risk and says to mark `OPS_FIX_REQUIRED` rather than degrade to an outright long — exactly right. |
| QM5_10768 `fomc-post-mom` | **KEEP (conditional)** | Post-FOMC 24–48h continuation. Must be deduped against `QM5_10260` (FOMC-cycle flagship) at G0 — different mechanic (post-announcement drift vs multi-week cycle) so likely distinct, but G0 must confirm. Sample is thin: 8 trades/yr/symbol ≈ 56 trades over a 7-yr backtest; the "<55% predictive power" falsification is borderline on that count. Low priority. |
| QM5_10891 `el-d2-t10-fomc-drift` | **REWRITE or KILL** | Two defects, see Finding 1. |
| QM5_10766 `pre-nfp-drift` | **REWRITE or KILL** | Does not test the stated thesis, see Finding 2. |

### Finding 1 — QM5_10891 mislocates the pre-FOMC drift anomaly

The card cites the well-documented pre-FOMC announcement drift, then applies it
to **USD FX majors** (EURUSD, GBPUSD, USDJPY, AUDUSD). The Lucca-Moench
pre-FOMC drift is an **equity-index** phenomenon — documented for the S&P 500,
not for FX. Applying it to FX pairs is a thesis-transfer error: a real anomaly
pointed at the wrong asset.

Second defect: the entry rule is *"enter long/short based on the prior 5-day
trend."* That is short-horizon momentum gated to a 24-hour calendar window — it
does not trade the *drift* at all. The card's title and its mechanics disagree.

**REWRITE** (apply pre-FOMC drift to `NDX.DWX` / `WS30.DWX`, and make the
signal the drift itself — directional exposure into the pre-announcement
window — not prior-trend momentum) **or KILL**. As written it would either
show nothing or, worse, show a spurious momentum result mislabelled as a
pre-FOMC edge that Q11 cannot certify.

### Finding 2 — QM5_10766 tests a trend filter, not pre-NFP drift

Entry is *"buy if H4 price is above the 20-EMA, sell if below"* on the Thursday
before NFP. The thesis claims to capture pre-event *positioning drift*; the
mechanic actually tested is generic trend-following inside a calendar window.
The "success rate < 52%" kill is weak, and ~12 trades/yr makes the sample tiny.
**REWRITE** to test the drift directly (the sign and persistence of the
realized pre-NFP move), **or KILL** — it does not earn an MT5 slot as written.

## Direction 3 — Calendar / seasonal flow

### Finding 3 — QM5_10763 and QM5_10892 are opposite-sign trades on the same window

Both trade the month-end FX window. They disagree on direction:

- **QM5_10763 `fx-month-end-rebal`** trades the rebalancing *flow direction*:
  if US equities outperformed, hedgers sell USD → the card trades **with** the
  flow. Grounded in Krohn & Sushko (2022, BIS) — price-insensitive mandate
  flow.
- **QM5_10892 `el-d3-t11-month-end-rev`** trades **reversion**: short the
  month-to-date top-2 currency outperformers, long the bottom-2.

These are mutually exclusive edges on the same calendar window. G0 must **not
approve both** — at most one is a real edge. Recommendation: the flow-direction
thesis (10763) is the better-sourced one (a documented institutional cause),
but it needs equity-index data for the signal (see Finding 4). The
reversion thesis (10892) is pure-price and easier to test but its mechanic is
the weaker-sourced claim. Decide one at G0 by data feasibility; do not spend
MT5 time on both.

### Finding 4 — cards asserting `r3_data_available` for series the tester lacks

- **QM5_10763** needs S&P 500 vs foreign-index monthly returns to build the
  signal — cross-symbol historical data inside a single FX backtest. Confirm
  the index series are loadable in the tester before build (same constraint
  flagged for the commodity series in the Direction-1 screen).
- **QM5_10767 `idx-earnings-drift`** triggers on *"the day after Apple /
  Microsoft / Nvidia earnings"* and asserts `r3_data_available: YES`. That is
  **false** — the MT5 tester trades NAS100 / US500 CFDs and has no
  single-company earnings calendar. The card also yields only 4 trades/yr/
  symbol (~28 obs over 7 yr) — uncertifiable at Q08/Q11. **KILL.**

### Direction 3 verdicts

| Card | Verdict | Reason |
|---|---|---|
| QM5_10764 `idx-totm` | **KEEP → G0** | Turn-of-the-month on indices, 200-SMA trend filter, calendar + price only. Cheap, fast, structurally grounded (pension inflow flow). |
| QM5_10769 `london-fix-reversion` | **KEEP → G0** | Tier A. Well-engineered, honest on DST mapping and a 200-trade falsification floor; the one intraday card, diversifies a swing-heavy batch. Caveat: 120 trades/yr/symbol — recompute expected trades after news-blackout attrition. |
| QM5_10763 `fx-month-end-rebal` | **CONDITIONAL** | Finding 3 + Finding 4. One of {10763, 10892} only. |
| QM5_10892 `el-d3-t11-month-end-rev` | **CONDITIONAL** | Finding 3. One of {10763, 10892} only. |
| QM5_10765 `gold-monthly-seasonal` | **KILL** | Buy-Jan/Aug, sell-Mar/Oct gold seasonality. The "Indian wedding / Chinese New Year demand" cause is folklore-grade, not a mechanical flow — it fails the charter's structural-cause bar. Month-of-year seasonality in gold is heavily data-mined and regime-dependent; high overfit-to-history risk with a falsification ("beat the 20-yr average monthly return") that rewards exactly that overfit. |

## Direction 4 — SMC / microstructure

| Card | Verdict | Reason |
|---|---|---|
| QM5_10893 `el-d4-t12-ls-ob-micro` | **DEFER (correctly last)** | See Finding 5. |

### Finding 5 — QM5_10893 SMC: defer, then tighten before build

The charter explicitly schedules Direction 4 last as the highest-failure-odds
direction, and wants exactly one disciplined SMC mechanization — so this is not
a kill. But three issues must be closed before it consumes MT5 time:

1. **Residual discretion.** "Market Structure Shift" and "Order Block 50% mean
   threshold" are not fully mechanical as written. Any ambiguity becomes
   curve-fit surface. The falsification (random sweep vs structured sweep) is
   good, but the rule surface must be pinned to deterministic definitions
   first.
2. **Blackout attrition.** 100 trades/yr/symbol on M5 — a mandatory news
   blackout will void a meaningful fraction of setups. The expected-trades
   figure does not net this out; recompute it post-blackout so Q02 zero-trade
   logic and the falsification sample are sized honestly.
3. **Cost realism.** M5 entries with 2-pip stops sit close to (not over) the
   charter's HFT line. Spread/slippage realism is the likely killer, not the
   pattern logic — P5b cost review must be explicit.

**DEFER** until Directions 1–3 produce their first screened, gate-tested batch,
as the charter sequence requires. Then rework definitions before build.

## Shared infrastructure note

Two G0-ready cards — QM5_10350 (paired NDX/WS30 beta spread) and the entire
Direction-1 cross-sectional family — need a **multi-symbol / multi-leg EA
execution model** that the standard per-symbol Q02 fanout does not provide.
QM5_10350 handles this honestly (it will self-mark `OPS_FIX_REQUIRED`). This is
the same blocker raised as Finding 0 of the Direction-1 screen. Resolving the
multi-symbol execution + Q02 representation model once unblocks cards across
Directions 1 and 2 — it is the highest-leverage build-design decision in the
whole Edge Lab batch and should go to OWNER + Codex now.

## Synthesis — recommended Direction 2/3/4 action

1. **Advance 4 cards to G0:** QM5_10349, QM5_10350 (D2), QM5_10764, QM5_10769
   (D3). QM5_10768 advances conditionally on a clean dedupe vs QM5_10260.
2. **Resolve the 10763 / 10892 conflict at G0** — approve at most one
   month-end card, chosen by data feasibility (Finding 3/4).
3. **REWRITE or KILL** QM5_10891 (wrong asset + wrong signal) and QM5_10766
   (tests a trend filter, not the drift).
4. **KILL** QM5_10765 (fails the structural-cause bar; overfit risk) and
   QM5_10767 (no earnings calendar in the tester; uncertifiable sample).
5. **DEFER** QM5_10893 (Direction 4 is last; tighten definitions, recompute
   post-blackout trade count, and budget cost realism before build).
6. Raise the **multi-symbol execution / Q02 representation** decision to
   OWNER + Codex — it gates QM5_10350 and the Direction-1 family.

## Verification

- 12 Direction-2/3/4 cards confirmed present in `D:/QM/strategy_farm/artifacts/
  cards_review/` (directory listing, 2026-05-22).
- All card IDs, entry rules, data claims, and falsification clauses above were
  read directly from the card files.
- No card files were created, edited, or deleted by this screen. Kill / rewrite
  / defer calls are recommendations for the G0 reviewer and OWNER, not executed
  here. Pipeline verdicts remain the gates' alone.

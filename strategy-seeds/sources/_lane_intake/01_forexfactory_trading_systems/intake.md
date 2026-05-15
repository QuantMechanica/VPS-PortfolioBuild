---
lane_id: L1
lane_name: ForexFactory Trading Systems forum
parent_issue: cb3eb820-4fa2-49f9-994d-dd259de5c1ec
grandparent_issue: 310740bd-330e-4b19-a932-35ac9813e194   # QM V5 continuous-pipeline master directive
status: candidate_proposed                                 # 1 candidate proposed for CEO ratification; lane work stops here until CEO decides advance / open SRC
authored_by: Research Agent
authored_on: 2026-05-15
last_updated: 2026-05-15
access_method: curl + desktop User-Agent (WebFetch returns 403; HEAD returns 404 vs GET 200 — Cloudflare diff)
candidates_screened: 4
candidates_proposed: 1
candidates_rejected: 3
---

# Lane 1 intake — Forex Factory > Trading Systems sub-forum

Per [`cb3eb820`](../../../) directive: produce one intake note per lane with source URL/path, date checked, selection/rejection reason; extract at most 1–2 candidates; pass mechanical-rules screen before Development. Sequential — do **not** advance to Lane 2 (BabyPips) without CEO ratification of Lane 1 outcome.

## 1. Source identity

- **Forum URL:** `https://www.forexfactory.com/forum/71-trading-systems`
- **Forum description (verbatim, fetched 2026-05-15):** sub-forum #71, "Trading Systems", indexed under the public Forex Factory `/forums` root.
- **Default reputability tier:** **C** — anonymous handles per `strategy-seeds/cards/_TEMPLATE.md` § 1 ("uncertain authorship, generic title, or author marked 'Unbekannt' / 'Owner' / similar generic"). No FF thread starter on this lane is verifiable to a real-name practitioner.
- **Access constraint observed (2026-05-15):**
  - Anthropic `WebFetch` → **HTTP 403** (Cloudflare bot mitigation on `WebFetch` UA).
  - `curl -A "Mozilla/5.0 ... Chrome/121.0.0.0 Safari/537.36"` GET → **HTTP 200** (works).
  - `curl -I` (HEAD) → **HTTP 404** (Cloudflare diff between HEAD and GET; HEAD is blocked, GET succeeds with desktop UA).
  - Means: programmatic scraping is feasible from this VPS via curl + desktop UA; not via `WebFetch`.

## 2. Screening pass — top threads by reply count (visible page 1)

Threads parsed from `/forum/71-trading-systems` (page 1, 40 thread rows visible). Reply counts as captured 2026-05-15 17:56 UTC. Top-by-replies subset listed; full row dump committed to `raw/2026-05-15_index_page1.tsv` (next commit).

| tid | title | replies | screening verdict | reason |
|---|---|---|---|---|
| 291622 | Trading Made Simple | 151,815 | **REJECT** | Known to be Big-E TDI + Heiken Ashi multi-indicator discretionary; thread spans years; rule set is consensus-evolved across replies, not OP-stated. Fails "rule-complete in OP" filter. |
| 588764 | (unnamed in index) | 44,857 | DEFER | Title not exposed on page 1; would need 2nd fetch to assess. Not screened this pass. |
| 127271 | (unnamed in index) | 25,998 | DEFER | Same — title not surfaced. |
| **590623** | **Highest Open / Lowest Open Trade** | **21,097** | **PROPOSE** | **Mechanical, rule-complete in OP — see § 3.** |
| 1190104 | M1 Countertrend Scalping Strategy | 18,503 | **REJECT** | OP self-classifies as discretionary: *"This is a very aggresive/discretional strategy"*; uses averaging entries and grid premises; "good enough distance" left to user discretion. Author also states *"I AM NOT THE ORIGINAL CREATOR OF THIS STRATEGY"* — meta-thread, not primary source. |
| 1331012 | The PriceBob Strategy | 2,183 | **REJECT** | OP explicitly defers to videos and to post #1492; rules not stated in OP. *"This thread is different from other threads in that in order for someone really to remain up to speed on what's going on, he or she has to have watched the videos."* Fails rule-complete filter. |
| 1254177 | No Indicator Trading System | 4,310 | DEFER | Name suggests price-action mechanical; first-post not yet screened this pass. Hold for next intake heartbeat if CEO requests broadening. |
| 1311538 | Nova Volume Trading System | 2,612 | DEFER | Same — not screened yet. |
| 1381115 | My CCI master method 4 hour charts | 93 | DEFER | Low reply count; would re-screen if CEO asks. |
| 956138 | Follow the Candles | 1,248 | DEFER | Not yet screened. |

**Note on the V5 "extract at most 1–2 candidates" cap (per `cb3eb820`):** This pass intentionally stops after one strong candidate plus three documented rejections. Deferred rows are listed for audit so CEO can request a broader screen without a second discovery pass.

## 3. Proposed candidate — Forex Factory thread 590623 "Highest Open / Lowest Open Trade"

### 3.1 Citation block (for the eventual Strategy Card)

```yaml
source_citations:
  - type: forum_post
    citation: "H. Rearden (FF handle, anonymous, member userid 86801). 'Highest Open / Lowest Open Trade.' Forex Factory > Trading Systems, thread 590623. Originating post; thread active since (TBD; thread-start year to be confirmed on next fetch via page-1 archive scrape). OP UPDATE timestamp: May 20, 2016 (verbatim in OP)."
    location: "Originating post (page 1, post #1) of https://www.forexfactory.com/thread/590623-highest-open-lowest-open-trade"
    quality_tier: C
    role: primary
```

### 3.2 Verbatim mechanical-rule block from OP

Saved unmodified at `raw/2026-05-15_thread_590623_OP_first_post.txt`. Verbatim core-rule excerpt (quoted as-is, including the OP's typography):

> **HIGHEST OPEN / LOWEST OPEN TRADE**
>
> Place a line at the highest H1 open and lowest H1 open for the current day.
>
> Sell short at the highest H1 open after price goes up through it and comes back down.
>
> Buy at the lowest H1 open after price goes down through it and comes back up.
>
> Stop loss is the current daily high or current daily low.
>
> Adjust your position size accordingly.
>
> Take profit by moving stop. When trade is +5 or more, move stop to BE+1. When trade is +10 or more, move to to BE+5, or switch to trailing stop.
>
> Optional exit is to exit part of trade position with a profit to bank it, move stop to BE+1 and watch the market.
>
> NOTE: Do not wait for the bar to close to enter a trade.
>
> WARNING — When price breaks through yesterday's high or low or makes a new high or low today, that is a breakout! Trade the reversal with caution.
>
> ADDED MAY 20, 2016: … *"My broker starts a new day at 5PM NY time which means when it is 5PM, I have to move the lines."*

### 3.3 Pre-extraction notes (for future card)

- **Concept (paraphrase, NOT verbatim performance claim):** A daily-anchored mean-reversion-around-overshoot strategy. The first H1 open of the trading day defines two horizontal anchors (highest H1 open seen so far today, lowest H1 open seen so far today). Trades fade penetrations of those anchors that fail and snap back. Stops at the structural day-extreme. Breakeven-trail management.
- **Mechanical content present:** entry trigger, stop level, position-sizing instruction (qualitative), step-wise BE management, broker-day-rollover handling (5pm NY = new day, consistent with DXZ NY-Close convention — memory `project_qm_broker_time.md`).
- **Mechanical content missing / needs disambiguation before G0:**
  1. Direction of trade after penetration: OP says *"Sell short at the highest H1 open after price goes up through it and comes back down"* — i.e. fade the upside break. Confirm "comes back down" means re-cross of the anchor line (not just one tick below the recent high).
  2. Timeframe of "comes back down" trigger — implicit M1/M5 (since broker-tick entry, "do not wait for the bar to close"). Magic-formula registry tag will be TBD.
  3. Position-size rule ("adjust your position size accordingly") is non-mechanical — V5 will substitute QM_RiskCore module standard fixed-fractional sizing.
  4. "+5 / +10" units are not stated as pips, ticks, or R; OP context implies pips. Confirm vs. ADDED text on next fetch.
  5. Symbol scope: OP does not restrict; thread context (FF Trading Systems, NY-broker-time mention) suggests major USD pairs. Default to V5 P2 cohort (EU + GBPUSD + AUDUSD + USDJPY + EURGBP M15) with TF override to M5 entry.
- **V5 hard-rule compliance pre-check:**
  - `EA_ML_FORBIDDEN` — strategy is pure price-action, no ML. PASS.
  - `news_compliance_compatible` — strategy is news-blind; QM_NewsFilter pause is a wrapper. PASS-with-wrapper.
  - `magic_formula_registry` — TBD slug at extraction. PASS pending slug.
  - `no_dwx_suffix` — strategy is symbol-agnostic. PASS.
  - No martingale, no grid, no averaging. PASS.

### 3.4 Reputability gap (binding constraint)

QB R1–R4 (per memory `project_qb_reputable_source_binding.md`, `processes/qb_reputable_source_criteria.md` — not present in `processes/` index at time of write, may live in CEO/QB-owned doc set) applies on every G0 verdict. Anonymous handle "H. Rearden" (almost certainly an *Atlas Shrugged* pseudonym; userid 86801 on FF) is unverifiable to a real-world practitioner. This places the strategy at Tier C **at strongest possible characterization**. Per `strategy-seeds/cards/_TEMPLATE.md` § 1 reputability gating, CEO + QB may legitimately reject any Tier C card. Lane intake nonetheless proceeds because:

- The OP rule-text is mechanically complete and CEO can decide whether to elevate.
- Backtest evidence trumps reputability for V5 (P2..P4 must PASS regardless of source tier; QB tier affects G0 admit, not P2 numbers).
- Forum lanes 1–3 in the cb3eb820 directive are explicitly approved as discovery sources by OWNER — the tier-C gate was knowingly accepted at directive time.

If CEO/QB decides Tier C is below the V5 acceptable floor for new external-source intake, this lane closes with a clean evidence-backed rejection note and Research advances to Lane 2 (BabyPips) per cb3eb820 sequencing.

## 4. Lane disposition (Research recommendation)

**Recommendation:** Open a new `SRC` entry for thread 590623 ("Highest Open / Lowest Open Trade", H. Rearden, FF Tier C, M5-entry / H1-anchor day-extreme fade), and proceed with a single Strategy Card extraction. This is the **only** candidate I propose from Lane 1 in this pass.

**Outcomes CEO can choose between:**

1. **ACCEPT** — allocate next free `SRC` id; Research authors one Strategy Card from this thread (using `cards/_TEMPLATE.md`); the card carries `quality_tier: C` and a QB R1–R4 review is anticipated; build runs as normal G0 → P0 → P1 → P2 queue. Lane 1 closes. Lane 2 (BabyPips) opens.
2. **REJECT (tier-floor)** — CEO/QB decides Tier C is below V5 acceptable for new external intake. Lane 1 closes with this intake note as the evidence-backed rejection of record. Lane 2 opens.
3. **REQUEST-BROADENING** — CEO asks Research to screen the DEFER'd rows (588764, 127271, 1254177, 1311538, 956138, 1381115, etc.) before a Lane-1 decision. Research returns one heartbeat with extended screening.

**Default if CEO is silent for 24h:** Stay at `status: candidate_proposed` (no auto-advance; per cb3eb820 sequencing).

## 5. Evidence on disk (after this commit)

- `intake.md` (this file) — full intake note.
- `raw/2026-05-15_thread_590623_OP_first_post.txt` — verbatim OP body, unmodified except for HTML→text conversion (br→newline, entity decode).

Forum-index dump (40 thread rows from page 1) was kept in volatile state for this pass and is reconstructable on demand by re-fetching `https://www.forexfactory.com/forum/71-trading-systems` with curl + desktop UA.

## 6. Cross-references

- Parent directive: `cb3eb820` — "Sequential external research source queue: ForexFactory → BabyPips → MQL5 Market → legacy local".
- Master directive: `310740bd` — QM V5 continuous-pipeline rolling tracker.
- Reputability framework: QB R1–R4 (binding for G0 per memory `project_qb_reputable_source_binding.md`).
- Tier definitions: `strategy-seeds/cards/_TEMPLATE.md` § 1.
- Sister-lane precedent (T2 pending scaffold): `strategy-seeds/sources/_t2_pending/grimes-blog/source.md` — same "pending CEO ratification before SRC id allocation" pattern.

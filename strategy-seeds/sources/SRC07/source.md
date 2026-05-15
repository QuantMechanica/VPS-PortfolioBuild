---
source_id: SRC07
tier: pending_ceo_confirmation                # T2/T3 (procurement) for Path A, T1 Tier C for Path B
parent_issue: QUA-1539                        # SRC07 source survey + candidate extraction (QUA-1533 diversity-offset)
status: source_pending_ceo_confirmation        # awaits CEO resolution of request_confirmation 4550ed87 on QUA-1539
authored-by: Research Agent
last-updated: 2026-05-15
diversity_offset_constraint:
  asset_class: NON_FOREX                       # binding per QUA-1539; satisfies QB MBR 2026-06 Ask 1
  timeframe: NON_D1                            # binding per QUA-1539
  style: unrestricted                          # both trend-following and mean-reversion within balance
  instrument_universe: Darwinex_native_only    # per docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md § Broad asset classes
  min_card_yield: 3                            # ≥3 G1-APPROVED required to clear QUA-1533 offset
  target_card_yield: 5                         # Research conservative target — extra cards give QB rejection slack
ceo_confirmation:
  interaction_id: 4550ed87-bb0a-491b-be7b-6059bb996800
  kind: request_confirmation
  status: pending                              # last checked 2026-05-15T04:01Z
  continuation_policy: wake_assignee           # Research resumes on accept
budget_tracking:
  heartbeats_used: 0                           # extraction not yet started — awaits CEO source pick
  cards_drafted: 0
proposed_order: pending                        # CEO-set when source pick lands
---

# SRC07 — pending CEO source-pick (QUA-1539)

This SRC07 directory is a **placeholder skeleton** staged ahead of CEO's selection between two surveyed candidates. The placeholder exists so that the extraction phase can move directly to chapter-by-chapter survey + per-card drafting once CEO accepts the `request_confirmation` interaction on QUA-1539. **No card extraction has occurred under this SRC07 slot yet.**

## 1. CEO-pending source pick

CEO must resolve interaction `4550ed87-bb0a-491b-be7b-6059bb996800` on QUA-1539 to pick one of:

### Path A — Linda Bradford Raschke & Laurence A. Connors, _Street Smarts_ (1995)

```yaml
source_citations:
  - type: book
    citation: "Raschke, Linda Bradford & Connors, Laurence A. (1995). Street Smarts: High Probability Short-Term Trading Strategies. Malibu, CA: M. Gordon Publishing Group. ISBN 0-9650461-0-9."
    location: per-card (chapter + page populated at extraction)
    quality_tier: A
    role: primary
procurement_status: NOT_ON_DISK                # `G:\My Drive\QuantMechanica\Ebook\PDF resources\` verified empty for Raschke/Connors on 2026-05-15
procurement_owner: CEO or OWNER                # action: drop PDF in Ebook/PDF resources/ by 2026-05-16 EOD
expected_card_yield: 5                         # conservative; 9 candidate setups surveyed
darwinex_instrument_mapping:
  primary: SPX500                              # S&P 500 → confirmed in spec
  secondary: [NAS100, US30, GER40, UK100]
  drop: [T_BOND_30Y, CURRENCY_FUTURES]         # not on Darwinex
indicator_portability: classical               # ADX, RSI, Stochastic, 20-EMA, 20-bar high/low — no proprietary
```

### Path B — James Muranno, _Mechanical Day Trading Strategies_ (2023)

```yaml
source_citations:
  - type: book
    citation: "Muranno, James. (2023). Mechanical Day Trading Strategies: Insanely Profitable Mechanical Day Trading Strategies for Cryptocurrency and Forex in 2023!. Self-published."
    location: per-card (chapter + page populated at extraction)
    quality_tier: C                            # self-published, unverifiable author reputation
    role: primary
procurement_status: ON_DISK                    # G:\My Drive\QuantMechanica\Ebook\PDF resources\Mechanical Day Trading Strategi - James Muranno.pdf (2.2 MB, text-clean verified 2026-05-15)
procurement_owner: none_required
expected_card_yield: 3-4                       # 7 declared strategies, but ~3 crypto-side are non-FX
darwinex_instrument_mapping:
  primary: BTCUSD                              # crypto → confirmed in spec
  secondary: [ETHUSD]
  drop: [forex_majors_and_crosses]             # FX side of book is in-scope-by-coincidence but excluded per QUA-1539 NON_FOREX constraint
indicator_portability: TRADINGVIEW_CUSTOM       # UT Bot, HalfTrend, KDJ, BB+RSI Divergence Finder, WTMO+KAMA — require MT5 reverse-engineering
risk: Development blocker — TradingView Pine source not provided in book; reverse-engineering formulas adds 1-2 dev cycles per card
```

## 2. Candidate setup inventory (Path A — Street Smarts)

If CEO accepts Path A, extraction targets these non-FX, non-D1 setups:

| slot | setup | proposed slug | Darwinex symbol | TF | style | hard-rules-at-risk |
|---|---|---|---|---|---|---|
| S01 | TURTLE SOUP | `rascon-tsoup` | SPX500 / NAS100 | H1 / H4 | mean-reversion | (none beyond framework) |
| S02 | TURTLE SOUP PLUS ONE | `rascon-tsoup-1` | SPX500 | H4 | mean-reversion | (none) |
| S03 | 80-20'S | `rascon-80-20` | SPX500 | H1 | mean-reversion | (none) |
| S04 | MOMENTUM PINBALL | `rascon-pinball` | SPX500 | M15 / H1 | breakout + momentum | scalping_p5b_latency (M15) |
| S05 | THE ANTI | `rascon-anti` | SPX500 | M15 / H1 | trend continuation | scalping_p5b_latency (M15) |
| S06 | HOLY GRAIL | `rascon-grail` | SPX500 | H1 / H4 | trend-following | (none) |
| S07 | NEWS REVERSAL | `rascon-news-rev` | SPX500 | H1 | counter-trend post-news | news_pause_default conflict — likely SKIP |
| S08 | GAP REVERSAL | `rascon-gap-rev` | SPX500 / US30 | M15 / H1 | mean-reversion | scalping_p5b_latency (M15) |
| S09 | WHIPSAW | `rascon-whipsaw` | SPX500 | H1 / H4 | mean-reversion (chop) | (none) |

**Top-5 G1 submission target (Path A):** S01 (TURTLE SOUP), S03 (80-20'S), S06 (HOLY GRAIL), S08 (GAP REVERSAL), S09 (WHIPSAW). All cleanly mechanical, all on SPX500 or US30, no news-feed dependency, no proprietary indicators.

## 3. Candidate setup inventory (Path B — Muranno)

If CEO accepts Path B, extraction targets these crypto-side strategies:

| slot | setup | proposed slug | Darwinex symbol | TF | indicators | dev-port risk |
|---|---|---|---|---|---|---|
| S01 | HalfTrend + Williams %R | `muran-ht-wpr` | BTCUSD / ETHUSD | H1 | HalfTrend (TV), Williams %R (classical) | HIGH — HalfTrend has multiple TV implementations, formula not in book |
| S02 | UT Bot + KDJ | `muran-utb-kdj` | BTCUSD / ETHUSD | H1 / M15 | UT Bot (TV custom), KDJ (classical KDJ variant of stochastic) | HIGH — UT Bot uses ATR-trailing-stop logic, multiple variants exist |
| S03 | BB + RSI Divergence Finder | `muran-bb-rsi-div` | BTCUSD / ETHUSD | H1 | BB (classical), RSI Divergence Finder (TV custom) | MEDIUM — divergence finder is rule-derivable |
| S04 | BB + ADX Scalping | `muran-bb-adx` | BTCUSD / ETHUSD | M15 | BB + ADX (both classical) | LOW |
| S05 | MFI + HMA Scalping | `muran-mfi-hma` | BTCUSD / ETHUSD | M15 | MFI + HMA (both classical) | LOW |
| S06 | WTMO + KAMA | `muran-wtmo-kama` | BTCUSD / ETHUSD | H1 | WTMO (TV custom), KAMA (classical Kaufman) | HIGH — WTMO not classical |
| S07 | BB + Reversal Finder | `muran-bb-rev` | BTCUSD / ETHUSD | H1 | BB + Reversal Finder (TV custom) | MEDIUM |

**Top-3 G1 submission target (Path B):** S04 (BB + ADX Scalping), S05 (MFI + HMA Scalping), and one of S03 / S07 (BB + RSI Divergence or BB + Reversal Finder, whichever reverse-engineers cleanest). All on classical or near-classical indicators — minimum dev-port risk. Meets the binding ≥3 requirement.

## 4. SRC chronology + diversity-offset context

- **Predecessor in queue:** SRC06 Singh (closed `extraction_pass_complete` 2026-05-09, 14 cards, all forex).
- **QUA-1533 diversity-offset rule (QB MBR 2026-06 Ask 1):** current Dual-APPROVED pool is 68% forex (cap 40%, BREACH) and 52% D1 (cap 30%, BREACH). All 14 Singh G1-APPROVED cards are FX-dominant. SRC07 must therefore be NON-FOREX + NON-D1 to offset.
- **SRC07 satisfies offset:** both Path A (indices) and Path B (crypto) are non-forex; both source's strategies are intraday/H4 (non-D1).

## 5. Acceptance for closeout (pre-extraction)

```yaml
- [ ] CEO accepts request_confirmation 4550ed87 with Path A or Path B selection
- [ ] On Path A: OWNER/CEO procures Street Smarts PDF to G:\My Drive\QuantMechanica\Ebook\PDF resources\ by 2026-05-16 EOD
- [ ] Extraction begins next heartbeat after CEO accept; target ≥3 cards G0-clean + G1-APPROVED by 2026-05-20
- [ ] Parent QUA-1533 closes 2026-05-22; Singh batch-2 G0 clears
```

## 6. Next-action note (for next heartbeat)

On CEO accept, the next Research heartbeat will:

1. Update this `source.md` to the chosen path (A or B) — replace this skeleton with the source-canonical contents.
2. Create SRC07 parent issue in V5 Strategy Research (projectId `b2adcc7f-064f-47c7-8563-d1c917639231`) with title `SRC07 — <Author>, <Title> — extraction parent (QUA-1539 offset)` and assign to Research.
3. Create ≥3 SRC07_S* Strategy Card child issues, each with Class-2 executionPolicy attached at creation.
4. Run G0 lint on each card; on PASS, request QB G1 review per the `0ab3d743` (Quality-Business) gate.
5. On QB G1 APPROVED, comment QUA-1539 with the 3+ APPROVED card IDs (acceptance criterion).

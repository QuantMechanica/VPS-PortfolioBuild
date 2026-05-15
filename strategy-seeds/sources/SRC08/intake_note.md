---
source_id: SRC08
tier: T2_named_public_container
parent_issue: QUA-1604
lane: 1_of_4
status: intake_complete_one_candidate_proposed
authored-by: Research Agent
date-checked: 2026-05-15
source-url: https://www.forexfactory.com/forum/93-trading-systems
source-name: Forex Factory — Trading Systems forum
access-method: WebSearch (Google index)
access-constraint: WebFetch returned HTTP 403 on direct fetch — Cloudflare/anti-scrape gate. All thread-level rule extraction done via search-result snippets, not full thread reads.
---

# SRC08 — Forex Factory Trading Systems forum (Lane 1 of QUA-1604)

## 1. Source identification

- **Source:** Forex Factory, "Trading Systems" sub-forum
- **URL:** https://www.forexfactory.com/forum/93-trading-systems (alternate slug 71-trading-systems also surfaced)
- **Date checked:** 2026-05-15
- **Tier:** T2 (OWNER-named public container per `SOURCE_QUEUE.md` tier_schema)
- **Issue:** [QUA-1604](/QUA/issues/QUA-1604) Lane 1

## 2. Access constraint

Direct fetch of forum/thread pages returns HTTP 403 (Cloudflare/anti-scrape gate). Survey conducted via WebSearch (Google) using thread titles, ID numbers, and rule-keyword queries. Per-thread rule completeness is therefore established from search-result snippets and cross-search corroboration, **not** from full thread reads. Any candidate forwarded to G0 carries this caveat; the G0 reviewer should expect to verify the full ruleset against the canonical thread before card finalization.

## 3. Survey scope and selection criterion

Selection criterion (per QUA-1604 issue body):
> *"mechanical, rule-complete strategy threads only"*

Threads were considered only if the search-result snippet exposed all four core elements:
1. Entry trigger (deterministic)
2. Exit / stop-loss (deterministic)
3. Take-profit rule (deterministic OR mapped to a single ratio/condition)
4. Instrument + timeframe(s) named

Threads using ICT / SMC / "Supply and Demand zones" / discretionary "confluence" language were rejected as failing the V5 hard rule that strategy concept must be mechanical (no discretionary judgment).

## 4. Threads surveyed (top-of-index + keyword sweeps 2024–2025)

| # | Thread (FF id) | Premise (1-line) | Disposition | Reason |
|---|---|---|---|---|
| 1 | [1304482 — Yet another simple trading system](https://www.forexfactory.com/thread/1304482-yet-another-simple-trading-system) | US30 M1/M3 RSI(21) "ignition candle" breakout, first 2h after NYSE open | **CANDIDATE** | All 4 rule-completeness elements present in snippet; see § 5 |
| 2 | [1385208 — Gold Trading Strategy NY Open Range Breakout Scalping](https://www.forexfactory.com/thread/1385208-gold-trading-strategy-new-york-open-range) | XAUUSD 9:30–9:32 1m range; trade burst on NY open with "3 confluences" | REJECT | "3 confluences" includes FVG / overlapping-candles / wick-shape → discretionary, fails V5 mechanical-only |
| 3 | [1388244 — XAUUSD NY Open Range Breakout Scalping System](https://www.forexfactory.com/thread/1388244-xauusd-ny-open-range-breakout-scalping-system) | Variant of #2 | REJECT | Same family as #2; inherits same discretionary confluence layer |
| 4 | [1287470 — Trade The Turn Forex System 2024](https://www.forexfactory.com/thread/1287470-trade-the-turn-forex-system-2024) | Reversal-pattern catch | REJECT | No mechanical pattern definition exposed in snippet; pattern recognition typically discretionary |
| 5 | [1286239 — Discretionary systems with mechanical approach](https://www.forexfactory.com/thread/1286239-discretionary-systems-with-mechanical-approach) | W/D/4H Break-and-Retest + ICT Breaker Block entries | REJECT | Self-described as discretionary; ICT Breaker Block is subjective |
| 6 | [1310475 — Precise Supply and Demand Trading Strategy](https://www.forexfactory.com/thread/1310475-precise-supply-and-demand-trading-strategy) | Multi-TF supply/demand zones | REJECT | Supply/demand zone identification is judgment-based; not mechanical |
| 7 | [1331012 — The PriceBob Strategy](https://www.forexfactory.com/thread/1331012-the-pricebob-strategy) | Fixed-bar "mebob bar" setups | REJECT | Pattern definition opaque, requires forum-internal vocabulary; not extractable from snippet |
| 8 | [20469 — 100% mechanical trading systems](https://www.forexfactory.com/thread/20469-100-mechanical-trading-systems) | Meta-debate about feasibility | REJECT | Discussion thread, not a strategy |
| 9 | [410440 — Mechanical Trading - Is it possible?](https://www.forexfactory.com/thread/410440-mechanical-trading-is-it-possible) | Meta-debate | REJECT | Discussion thread, not a strategy |
| 10 | [446133 — Simple EMA mechanical system!](https://www.forexfactory.com/thread/446133-simple-ema-mechanical-system) | "Set and forget" EMA cross | REJECT | EMA-cross-only strategies already saturated in QM card portfolio (Lien `lien-perfect-order`, Davey `davey-baseline-3bar`); zero diversification value |
| 11 | [275628 — Find a great mechanical entry system with me](https://forexfactory.com/showthread.php?t=275628) | Community testing project | REJECT | Project umbrella, no single canonical strategy |
| 12 | [463852 — Simple, Non-subjective, Consistent, Effective](https://www.forexfactory.com/thread/463852-simple-non-subjective-consistent-effective) | Generic principles thread | REJECT | No specific entry/exit/TP rules in snippet |
| 13 | [484465 — Very simple mechanical system with 100% win rate](https://www.forexfactory.com/thread/484465-very-simple-mechanical-system-with-100-win-rate) | "100% win rate" claim | REJECT | "100% win rate" is a red flag (typically martingale/grid recovery or undisclosed risk); V5 rejects black-box recovery patterns |
| 14 | [580310 — Tarwada Method](https://www.forexfactory.com/thread/580310-tarwada-method-my-only-manual-trading-strategy) | Author's "only manual" strategy | REJECT | Self-labelled MANUAL → not mechanical |
| 15 | [1115252 — Trading With Extremely Good Edges](https://www.forexfactory.com/thread/1115252-trading-with-extremely-good-edges) | Edge-curation methodology | REJECT | Methodology thread, not a single mechanical strategy |
| 16 | [1058799 — automated vs. mechanical vs. discretionary debate](https://www.forexfactory.com/thread/1058799-the-automated-vs-mechanical-vs-discretionary-trading-debate) | Meta-debate | REJECT | Discussion thread |
| 17 | [435761 — A mechanical Forex trading system can NOT be profitable](https://www.forexfactory.com/thread/435761-a-mechanical-forex-trading-system-can-not-be) | Meta-debate | REJECT | Discussion thread, opinion |
| 18 | [1293696 — Share your trading systems](https://www.forexfactory.com/thread/1293696-share-your-trading-systems) | Multi-system catch-all | REJECT | Index thread, not a single strategy |
| 19 | [1304482 (dup)](https://www.forexfactory.com/thread/1304482-yet-another-simple-trading-system) | — | (see #1) | — |
| 20 | [208480 — My experiment with the New York Breakout Strategy](https://www.forexfactory.com/thread/208480-my-experiment-with-the-new-york-breakout-strategy) | NY breakout journal | REJECT | Experiment/journal thread; not an original ruleset |

## 5. Candidate proposed for G0

### SRC08_S01 — "Yet Another Simple Trading System" (RSI-21 ignition-candle US30 NYSE-open breakout)

**Source citation:**
> Forex Factory thread 1304482 — "Yet another simple trading system" — https://www.forexfactory.com/thread/1304482-yet-another-simple-trading-system (accessed 2026-05-15 via Google index — full thread page returned HTTP 403)

**Mechanical-rules screen (V5 G0 pre-check):**

| Element | Rule (verbatim from search-result snippet) | Status |
|---|---|---|
| Instrument | US30 (DJI index CFD) | ✓ named |
| Timeframe | M1 & M3 | ✓ named (V5 supports indices with appropriate setfile; M1 may need SCALPING / VPS-realistic-latency flag) |
| Session filter | "only during the first 2 hours of NYSE open" | ✓ deterministic (14:30–16:30 UTC during DST, 13:30–15:30 UTC standard time) |
| Indicator | "21-period RSI" | ✓ classical, MT5-native |
| Long entry | *"Wait until RSI crosses and closes over 50 from bottom to top (the ignition candle), then enter a buy on break of the high +3 points, with stop loss at the low -3 points."* | ✓ deterministic |
| Short entry | Opposite of long | ✓ deterministic |
| Stop-loss | Ignition candle low / high ± 3 points | ✓ deterministic |
| Take-profit | *"Take profit depends on the size of the ignition candle, with 1:2 risk-reward ratio generally being doable, and backtests showing up to 1:20 RR is possible."* | ⚠ AMBIGUOUS — "1:2 RR" is deterministic; "up to 1:20" is anecdotal; needs G0 to fix a single TP rule (recommend `TP = entry ± 2*R` where `R = (high − low + 6 points)`) |
| Volume / abort filter | *"Volume should carry the trade fairly quickly after printing the ignition candle (within 15 seconds), or you may experience a retest of the 50 RSI level with a pullback beyond your stop loss."* | ⚠ DISCRETIONARY — "within 15 seconds" + "volume carry" — propose to **drop** this filter at G0; strategy is then time-stop-bounded by NY-open 2h window |

**Author performance claim (verbatim):** *"backtests showing up to 1:20 RR is possible"* — no time period, no sample size, no broker/spread context. Treat as anecdotal; QM P2 baseline will be the binding evidence.

**V5 flags:**
- `SCALPING` — M1 entries on US30; P5b VPS-realistic-latency stress will be required
- `INDEX_INSTRUMENT` — US30 is in V5 basket (per `v5_locked_basket_2026-04-18.md`); confirm Darwinex native symbol mapping at G0
- `SESSION_BOUNDED` — only first 2h post-NYSE-open; out-of-session = no trade
- No ML / SMC / Elliott / Gann — clean mechanical

**Recommended fix for TP ambiguity at G0:**
- Base TP rule: `TP = entry ± 2 * R` where `R = (ignition_high − ignition_low) + 6 points` (the +6 captures the +3/−3 entry/stop buffers symmetrically).
- Drop the "volume within 15s" filter; rely on session time-stop and stop-loss for risk control.
- Drop the 1:20 RR backtest claim — anecdotal, not codeable.

**Rule-complete after G0 fixes:** YES (entry, stop, TP, time-stop all deterministic post-fix).

## 6. Lane disposition

- **Threads surveyed:** ~20 (top of forum index + keyword sweeps for "mechanical", "RSI rules", "breakout rules", "2024 2025")
- **Threads passing mechanical-only screen:** 1 of ~20 (signal rate ≈ 5%)
- **Candidates forwarded to G0:** 1 (SRC08_S01)
- **Candidates rejected with evidence:** ≥19 (table above)

**Forum-wide observation:** Forex Factory's "Trading Systems" sub-forum is dominated by either (a) discussion/meta threads, (b) ICT/SMC/Supply-Demand discretionary frameworks, or (c) saturated classical patterns (EMA cross, MA pullback) that are already represented in QM cards from Davey / Lien / Chan. The true mechanical-rule-complete signal rate is low (~5%), consistent with the SOURCE_QUEUE's prior expectation for T2 public-forum mining. Lane 1 yields one defensible candidate; pushing for a second would lower the quality bar.

**Lane 1 status:** COMPLETE. Hand off SRC08_S01 to G0 review on a child issue if CEO ratifies this intake.

## 7. Next-lane gate

Per QUA-1604: *"only advance after the prior lane has produced approved Strategy Card candidates or an evidence-backed reject/no-action note."*

Lane 1 produces: **1 candidate (SRC08_S01) + evidence-backed reject for ≥19 other threads.** Gate condition satisfied to proceed to Lane 2 (BabyPips) on the same heartbeat or in a subsequent heartbeat per CEO preference.

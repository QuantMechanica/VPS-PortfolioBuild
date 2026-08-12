# FTMO Campaign — Wave-1 Synthesis & Wave-2 Plan (2026-07-21)

**Authority:** OWNER 2026-07-21 (win FTMO Phase-1 ≤30d, P≥0.80; Codex Sol/max; Claude orchestrates).
Synthesizes 8 headless-Codex Wave-1 outputs: 2 keystones (Book Architecture, Strategy Sourcing +
ICT) + 6 forum/foreign-language source clusters. Claude's ranking artifact; drives Wave 2.

## 1. The verdict (honest): today NO-GO, but the gap is now exactly measured

The Book Architect (`FTMO_BOOK_ARCHITECTURE_2026-07-21.md`) proved **no book assemblable from today's
evidence reaches P(pass)≥0.80/30d** — best (H) = **26.46%**. It is a **carry-density**, not a risk,
problem: the best book needs **+$556 per weekday session ($12,232/horizon)** more deterministic-
equivalent carry. Total-DD death ≤3.6%, daily-DD ~0% — safety is not the constraint.

**Two proven motors anchor the book:** 13213 USDJPY (193 tr/yr, swap-free) + 13301 GDAXI (115 tr/yr;
eliminate its 1 overnight trade). The 5% risk budget is already full → **new density must REPLACE
slow supports**, and we need **≈6 new 0.5% swap-free intraday-flat slots**, ~250-500 tr/yr each,
~0.10-0.25 net R/trade, **spread across non-overlapping sessions** (the 3% concurrent governor
discards duplicated exposure).

## 2. Deduped candidate reservoir (across all 8 outputs)

★ **Systemic dedup:** five sourced candidates (`prop-ny15-orb`, `nifty-orb30`, `ny-orb-confirm`,
`bn-orb15-rvol`, and 20007's ORB lane) are **one NY/index opening-range family** — they compete for
**at most one slot**, not five. Same-event SP500/NDX/WS30 ports = one family (Architect §8).

| Bucket | Candidates | Status |
|---|---|---|
| **Proven motors** | 13213 USDJPY, 13301 GDAXI | in book; 13301 kill overnight leg |
| **Existing EAs to gate (cheapest carry)** | 4006 (Breedon-Ranaldo EURUSD session-flow ~480 legs), 20007 (intraday config: ORB/VWAP/mom lanes ~250/sym), 13212 (Mulham US500 gap→FVG 90/yr), 13209 (Mulham PM sweep 140/yr, under-firing), 20023 (Savor-Wilson macro-day, zero-firing) | built; need gate/diagnosis |
| **New academic siblings (carded)** | idx-intramom-hv (Gao 2018 intraday-momentum hi-vol, ~300 legs), idx-macro-xfomc (Savor-Wilson ex-FOMC) | draft cards in `strategy-seeds/cards/ftmo-density-2026-07-21-drafts/` |
| **New forum candidates (top, orthogonal)** | london-box (GBPUSD/EURGBP FX London box 120-200/sym, NOVEL), bn-late-break (India late-session squaring 120-150/sym, NOVEL, US-close orthogonal), prop-sess-vwap-pb (VWAP pullback XAUUSD+NDX 60-180/sym), spx-news-day (M5 index macro, has numeric source PF 1.26), pivot-pullback (FX floor-pivot mean-reversion 150-220/sym, NOVEL but path-bias risk) | draft cards in `sources/cards_<cluster>/` |
| **Diversifiers (not density slots)** | 12969 gotobi + postfix-gotobi (Asia calendar, ~38/yr each, peer-reviewed) | anchor only |
| **DEAD / stop-work (confirmed)** | 20006 (PF 0.55, neg control), 20004/20026 TOM, 10440/10911 overnight index (no FTMO swap), all ICT/chart-pattern/liquidity-sweep/generic-session-breakout with no structural cause | do not rescue |
| **ICT last stand** | 12535 + 10629/USDJPY — ONE joint outcome-blind 2025 falsification (repair specs delivered), then closed regardless | LOW-CONFIDENCE_LAST_FALSIFICATION |

Forum honesty ledger: futures-orderflow returned **0 cards** (all dedup to incumbents — clean negative
result + an incumbent-requalification matrix); russia-mql **rejected 90.3%** as grid/martingale;
Nikkei/KOSPI ruled UNMAPPABLE (no .DWX proxy — honest no-card). Every kept candidate carries a real
citation (DOI or reproducible thread). Full reachability logs in each `FTMO_SOURCE_<CLUSTER>` doc.

## 3. The orthogonal 6-slot design (Claude's synthesis)

Beyond the two motors, fill six 0.5% slots by **session × mechanism** so the concurrent-risk governor
never discards carry as duplicate exposure:

| Slot | Session | Mechanism | Best expression | Build state |
|---|---|---|---|---|
| 1 | Europe→US | FX order-flow session-flow | **4006** (EURUSD) | built — reroute Q02 |
| 2 | US-open | index opening-range (ONE of the ORB family) | **20007 ORB lane** (built); bench: nifty-orb30 rule / ny-orb-confirm | built — gate |
| 3 | US-midday | intraday-momentum (last-½h ~ first-½h, hi-vol) | **idx-intramom-hv** (Gao) | carded — build |
| 4 | US-close | late-session squaring/closing flow | **bn-late-break** | card — build |
| 5 | Event | scheduled macro-announcement day | **20023** (built, fix zero-fire) → refine ex-FOMC via idx-macro-xfomc | built — diagnose |
| 6 | US-session, non-index | VWAP-benchmark pullback (XAUUSD adds instrument diversity) | **prop-sess-vwap-pb** | card — build |
| bench | Europe FX | session box (alt to slot 1) | **london-box** | card — hold |
| anchor | Asia | Tokyo-fix payment flow (low density) | 12969 + postfix-gotobi | diversifier, not a slot |

**Honest weak point:** Asia has no ≥250/yr swap-free candidate; 13213 doubles as the Asia-into-Europe
carrier and the Asia slot is filled by low-density fix anchors. This is a known residual gap.

## 4. Wave-2 execution order (marginal P(pass) per build-effort; Claude drives, serial builds)

1. **4006 — reroute the pending Q02.** Highest density, already built, #1 in BOTH keystones. The
   blocker was a `.DWX` history-sync error; **today's storm de-junction fix may have already cleared
   it** — verify the pending canonical row, let it run on a warm-cache terminal, adjudicate. NO
   duplicate enqueue, NO factory isolation.
2. **20023 + 13209 gate-defect diagnosis** (static / RAM-free). 20023 fires 0 trades on SP500/WS30
   (calendar/event-day mapping); 13209 fires 1 (filter over-restriction). Diagnose before any build.
3. **20007 first gate** — freeze ONE lane→symbol mapping before results (no post-hoc best-lane pick).
4. **13212 first Q02** — existing binary, unchanged center.
5. **New builds (serial, magic-resolver race):** idx-intramom-hv + idx-macro-xfomc (carded) → then
   card-approve + ea_id-allocate the top forum cards (london-box, bn-late-break, prop-sess-vwap-pb).
6. **Re-run the FTMO MC** (`ftmo_p1_mc.py`, equity_compounded, 100k paths, 30d) on the assembled book
   as real streams land → **admission gate P(pass)≥0.80 → OWNER** (money gate, never PF alone).

Every candidate enters the MC only with a pipeline-qualified trade ledger; design frequencies are
targets, not evidence. No challenge purchase / AutoTrading follows from research.

## 5. ICT closure

Repair specs for 12535 (killzone-sweep→MSS→FVG) and 10629/USDJPY (sweep→BOS→OB-retest) are
build-ready in `FTMO_STRATEGY_SOURCING_2026-07-21.md` §3-4. They earn ONE joint, outcome-blind,
preregistered 2025 falsification (2 deterministic runs, ≥5 trades/cell, positive net, evidence-set
PF floor, ≤10% DD, 2× cost stress). A joint PASS evidences these two frozen implementations only —
not ICT doctrine. A fail closes the line. Stale 10629 .ex5 must not be routed; 10628/SP500 stays HOLD.

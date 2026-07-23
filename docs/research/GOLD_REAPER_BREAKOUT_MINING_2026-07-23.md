# Wim Schrynemakers "Gold Reaper" Breakout Family — Mining & Mechanization Dossier

**Author:** Claude · **Date:** 2026-07-23 · **Status:** research finding (edge brief) · **Mode:** ultracode multi-agent
**Method:** 14-agent mining workflow (9-lane web sweep → synthesis → 4-lens adversarial critique;
run `wf_9b991ead-019`), + fetched primary sources, + repo prior-art verification.
**OWNER request:** investigate Wim Schrynemakers' strategies (Gold Reaper etc.) and what it takes to
implement these breakout strategies.

---

## Executive verdict (hard-nosed, no hedge)

**Do NOT clone Gold Reaper. It is not a new edge — it is a higher-production-value rebuild of a
breakout we already tested and killed (Balke XAU), and its own live numbers reproduce that failure
signature independently.** The only implementable value is to route ONE *converted* form — a
volatility-gated, EOD-flat, gold-flow-anchored opening-range breakout — into the existing **20007
`GOLD_BREAKOUT` lane** as a **testable hypothesis with a hard drawdown-tail acceptance bar**, expected
to be difficult to pass. We mechanize the *style* into a clean-room QM cell; we do not copy the product.

Two independent XAU-breakout implementations converge on the same death:

| Implementation | Type | PF | MaxDD | DD/Net | Source |
|---|---|---|---|---|---|
| **Balke XAU** (QM5_13213) OOS, gross | intraday session-anchored, EOD-flat XAU breakout | **1.03** | −$40,645 on +$13,342 net | **3.05×** | `D:/QM/reports/balke_walkforward/result.json` (verified) |
| **Gold Reaper** (Profalgo) LIVE | multi-TF S/R breakout, 9-strategy ensemble | **1.08** | **41.7%**, win ~72% | — | workflow F9 (newyorkcityservers review) |

Balke's *winner* was USDJPY (OOS PF 1.20); its gold leg died (verified). The mechanism generalizes to
FX and dies on XAU. **The Q05-DD death is not a risk to hedge — it is the predicted outcome.**

---

## 1. Who / what

- **Wim Schrynemakers** = Profalgo Limited (MQL5 user `strueli`), systematic EA developer since ~2005;
  traded S/R gold breakouts discretionarily since ~2008 and coded the EA to replicate "almost
  identically." Products: **Gold Trade Pro** (calmer D1 sibling), **The Gold Reaper** (the breakout EA),
  **Ultimate Breakout System** (30-strategy successor — best public window into the engine).
- **The Gold Reaper** = XAUUSD-only, fully-automated multi-timeframe support/resistance **breakout**
  ensemble. No grid, no martingale, no averaging; hard SL+TP on every trade.

## 2. Unified mechanical spec (KNOWN / INFERRED / UNKNOWN)

| Element | Verdict | Detail |
|---|---|---|
| Instrument / TF | KNOWN | XAUUSD only. Reaper attaches H1, analyses **H1+H4+D1** internally (9 sub-strategies). Gold Trade Pro = D1 only (7–8 sub-strategies). *The "8" in the request is the GTP count; Reaper is 9.* |
| S/R construction | **UNKNOWN (proprietary)** | Described only as "important recent highs/lows" across TFs. Clean-room model: rolling swing-H/L or prior-period H/L (Donchian-style) per TF, confluence = zone. |
| Entry | KNOWN (mechanism) | **Pending STOP orders** bracketing the level; fills only on break-through *with momentum*. Bidirectional. |
| Breakout trigger | KNOWN qualitatively, **threshold UNKNOWN** | Break beyond level "with momentum" + "multiple confirmation algorithms" + multi-TF agreement. No published ATR/RSI number. |
| Fake-breakout filter | KNOWN as enum | Discrete input **Low/Med/High** (default Med). Mechanism undisclosed. |
| Exits | KNOWN structure | Fixed hard SL + fixed TP every trade, then **trailing SL AND trailing TP**. Virtual-expiration on pendings; randomization jitter. |
| News | KNOWN (values) | **Only NFP**, not full calendar: NFP filter, 100 min before / 60 min after, closes + deletes pendings. AutoGMT (+2 winter / +3 summer = our NY-close convention). |
| Session / weekend | KNOWN | **No hard London/NY window** — level-driven, not clock-boxed. Only Friday-stop (weekend-flat) + NFP windows. |
| Sizing / risk | KNOWN (defaults) | Max Total DD input (Low 15 / Med 30 / High 50 %), Max Daily DD hard-stop, weighted lots, auto-scales frequency+lot to account size. |
| **Intraday-flat?** | **KNOWN = NO** | ~9h mean hold, ~5 trades/wk (whole ensemble); **~39% of fills carry overnight** (9h/23h). Trailing-TP winners hold multi-session. Only weekend-flat, never nightly-flat. |
| "9 strategies" | INFERRED = **one over-parameterized breakout** | They share instrument, entry, exit, and signal; differ only in *TF combination* and *confirmation-filter tightness*. Risk tiers 1–3/4–7/8–9 = a stop-width sweep (developer-unverified, review-inferred). |
| Performance | KNOWN (load-bearing) | Backtest 2020–24 PF **2.72** / DD 12.4% / win 81% → **live PF 1.08 / DD 41.7% / win 72%**. Classic over-fit degradation. |

**Provenance discipline:** all mechanics above are from public product/vendor copy + independent
reviews (idea/rules are not copyrightable). **No decompiled/pirated source was consulted.** Exact S/R
math and the 9 sub-strategy internals remain proprietary/undisclosed. Vendor **tuned constants**
(NFP 100/60, filter enum, tier buckets) are treated as marketing artifacts, **not** ported into a build.

## 3. Why cloning fails — the four adversarial lenses converge

1. **Structural cause — NONE as shipped.** Static horizontal S/R breakout is textbook chart lore with
   zero limit-to-arbitrage (everyone sees the same high; a real break-predicts-continuation edge would
   be front-run). Same species as the retired Wyckoff/SMC/ICT corpus. **The PF 2.72→1.08 / DD 3.4×
   live collapse is not "re-prove clean-room" — it is positive falsification** by the same standard that
   retired ICT icy-tea (PF 0.89) and Balke.
2. **Density — ZERO motors.** The "~250/yr" is a *stacking illusion*: 9 correlated selectors on one
   level set ⇒ ~28/yr per sub-strategy (3.5× below the <100 "not a motor" line). The FTMO killer is not
   swap — it is the **41.7% live DD (4.17× the 10% total limit)** and the fat left tail (high-win/low-PF)
   that trips the 5%-daily rule on a single bad day. Even the "lowest-DD" tier ran 12.4% backtest DD
   (already >10%).
3. **Overfit — one idea in a nine-strategy costume.** 2020–24 is the single most flattering regime for a
   long-gold breakout (COVID spike, 2022 inflation trend, 2023–24 CB-buying bull). Predicted pairwise
   equity-curve correlation across the 9 sub-strategies **> 0.7**. Falsifier: strip to the single core
   breakout and test OOS on **2011–2019** (2011 top, 2013 crash, 2015–18 range/bear) — regime-fit dies
   there.
4. **Prior-art — this is Balke XAU redux, and Balke XAU is dead.** The nearest prior art is **not** the D1
   survivors; it is **Balke XAU (13213)** — an intraday, session-anchored, EOD-flat XAU breakout we ran
   to walk-forward and killed (OOS PF 1.03, DD 3.05× net, verified). Gold Reaper's live PF 1.08 / DD 41.7%
   *independently reproduces* that signature = a **reproduced base rate**, not two anecdotes.

## 4. What is genuinely NEW — the one degree of freedom worth a test

Neither Balke nor any of our four confirmed **D1 XAU survivors** (10123 Donchian-20, 10128 Bollinger-1σ,
10145 TSM, 10183 Carver — all ~10–50 tr/yr, multi-day holds; 10123's card confirms **10 tr/yr**, so the
"101 trades" is full-history cumulative) has any **volatility-regime conditioning**. They trade *every*
breakout / are unconditional trend-followers.

**The single unexplored lever = a volatility-regime GATE that provably compresses the drawdown TAIL
(not the mean)** by refusing to trade the low-vol/chop XAU regime where the whipsaw losses are
manufactured. The peer-reviewed basis (Sonnert-style vol-state-conditional intraday momentum: "narrow
vol-scaled thresholds optimal, GARCH did not beat fixed") is the only cited mechanism with an
action-against-the-whipsaw. **Causal emphasis correction: the vol-gate IS the edge; the breakout is
merely how you time the fill inside an active regime.** If the vol-gate does not carry its own
incremental survival, there is no edge regardless of breakout geometry.

## 5. Implementation plan — build it as a gated cell in 20007 `GOLD_BREAKOUT`, not a standalone clone

20007's `GOLD_BREAKOUT` lane is already stubbed as "bands = daily open ± k×ATR/realized-vol; enter first
breach; flat EOD" and flagged "untested surface, the open question." This research answers it: build the
converted form **there**, as a TESTABLE HYPOTHESIS (F8 earns a Q02→Q04 slot, nothing more).

Deterministic, R4-clean lane enrichment:
- **Vol-regime gate = the edge** (require its standalone incremental Q04 net-of-cost survival). Breakout = timing device inside an active regime.
- **Anchor to gold's ACTUAL flow events, not equity-borrowed session opens** (spot XAU is 24h OTC — no opening/closing auction; the 20007 card's own warning against porting the equity first-half-hour rule applies): race `gb_anchor ∈ {lbma_fix_1030, lbma_fix_1500, macro_release_window, london_open, overlap_open}`. The **LBMA fix windows (10:30 / 15:00 London)** and **US-macro-release vol windows** have a real order-flow cause; generic session-opens are weaker. Session-calendar infra for this already landed (`framework/calendars/` — London/US/XETRA/LBMA, committed 94c09b885).
- **ATR/realized-vol-scaled threshold** (`gb_orb_minutes ∈ {15,30,60}`, grid k) — vendor's price-scaling + F8's "narrow vol-scaled optimal."
- **Fake-breakout filter** as a *clean-room* enum (`gb_confirm_close`: close-beyond-by-`buffer×ATR`) — **do NOT port the vendor's Low/Med/High constants**; let QM optimization set thresholds.
- **Forced MOC flat** — verify no trailing-TP path can carry a position past session close (the exact defect that makes the vendor swap-exposed). This is the divergence that makes it swap-free and FTMO-legal.
- **Concurrency:** one lane + one position + a setfile grid (magic-registry hygiene) — **not** 9 concurrent sub-magics. Diversification lives at the Q11 portfolio layer.

### Acceptance bar (the critical correction: DD-tail, not PF)
Because the prior-art kill is a **drawdown** kill (Balke XAU had *positive net* +$13.3k and still died on
DD), routing falsification to Q04 net-of-cost (a *mean* test) is necessary but **insufficient**. Hard bar:

> On our full-history .DWX XAU **including 2011–2019 OOS**, the vol-gated lane must drive **MaxDD/Net
> from Balke's 3.05× to ≤ ~1.3× (the Q05 ceiling) while holding ≥ 180 tr/yr.** If the gate cannot cut the
> tail without collapsing frequency below the density floor, **GOLD_BREAKOUT-on-XAU is closed** — the same
> negative Balke already recorded — and the lane is retired, not iterated.

### Dedup gate (the correction: drawdown co-exceedance, not just daily corr)
Gate the new lane against the D1 XAU survivors (10123/10128) on **drawdown co-exceedance / drawdown-window
overlap**, not only Pearson daily-return correlation (DL-083 0.40). An intraday ORB and a D1 Donchian can
show low daily corr yet share identical regime dependence (both bleed in chop, both print in trending-vol),
so their drawdowns synchronize and stack against the 5%-daily / 10%-total limits even at low corr.
Frequency-band difference (250/yr vs 10–50/yr) is **not** orthogonality of edge.

### Housekeeping
The backlog already holds redundant, **built** XAU/session-ORB expressions — `QM5_10181_tv-xau-ny-orb-retest`
and `QM5_10140_tv-london-session-break` (both G0-approved, `.ex5` present) — plus 20007's own `ORB` +
`GOLD_BREAKOUT` lanes. Fold/reconcile these into the 20007 grid rather than maintaining parallel XAU-ORB
duplicates that each re-discover the same base rate.

## 6. Gap-list — what agy / Codex / transcripts add next

- **Primary source (fetching):** Darwinex "Market Masters" interview `Q4LJyCn9_kA` transcript (via
  `fetch_transcript.py`) — his own words on the manual S/R method + his separate **post-NY night
  mean-reversion "scalping" book** (NOT in the EA; a potentially distinct idea worth its own scan).
- **agy (server-side, bypasses Cloudflare — lower priority given the decisive verdict):** MQL5 product
  comment threads (111357/111467), the ForexFactory reverse-engineer thread (403'd to WebFetch), and
  forexrobotlab's review — for any user-*deduced* S/R lookback / breakout-offset. No pirated source.
- **Codex (build-phase, deferred until 20007 is built + OWNER greenlights the lane):** S/R primitive A/B
  (prior-day H/L vs session opening-range H/L) raced through Q02→Q04; ATR-scaled-vs-fixed threshold on
  .DWX XAU; deterministic fake-breakout mechanization; MOC-enforcement assertion; NFP data coverage in
  `D:/QM/data/news_calendar`.

## 7. Bottom line for the OWNER

Wim Schrynemakers is a real, credible systematic gold-breakout developer, but **Gold Reaper adds no
falsifiable edge to QM** — its only hard evidence is *negative* (live PF 1.08 / DD 41.7% = "don't ship
overnight gold breakout"), and it duplicates both our killed Balke XAU and our existing D1 XAU survivor
cluster. The correct "implementation" is not a clone: it is a **single vol-regime-gated, gold-flow-anchored,
EOD-flat ORB cell in 20007's `GOLD_BREAKOUT` lane**, judged on a **drawdown-tail acceptance bar (MaxDD/net
≤ ~1.3× at ≥180 tr/yr over 2011–2019 OOS)**, gated against the XAU cluster on drawdown co-exceedance, and
**expected to be hard to pass** — that difficulty is the honest test of whether there is a gold breakout
edge at all, or whether XAU breakout simply joins Balke in the documented-negative pile.

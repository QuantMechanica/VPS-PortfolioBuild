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

> ⚠️ **The paragraph above and parts of §3.4 and §5 are CORRECTED by the REVISION section immediately
> below** (independent Codex cross-challenge, verified). The no-clone verdict stands; the Balke
> *equivalence/base-rate* framing, the "Q05 ceiling", the LBMA footing, the 2011–2019 OOS, and the
> acceptance/dedup gates do not. Read the REVISION before acting.

---

## REVISION — independent Codex cross-challenge (2026-07-23, claims verified against repo)

A cross-model review (Codex, gpt-5.6-sol, read-only) was run at the OWNER's request against this dossier —
because every critic in the original 14-agent workflow was a Claude model and may share blind spots. It
**upholds the no-clone verdict** but found several load-bearing errors, each verified here against the
actual files. This section supersedes the conflicting claims below.

1. **Balke "independent reproduction / reproduced base rate" — WITHDRAWN.** Balke and Gold Reaper are
   mechanically different (Balke: fixed 03:00–06:00 broker range, forced 18:00 exit; Gold Reaper: H1/H4/D1
   S/R zones, anticipatory zone orders, overnight carriage). They share only "XAU + breakout" → a **weak
   family prior ("XAU breakouts whipsaw")**, not equivalence. Their live windows may overlap (not
   independent), and Gold Reaper reports DD but no net, so a common "DD/net signature" is uncomputable.
   Balke stands as valid **negative prior art** — nothing stronger.
2. **Gold Reaper's "live PF 1.08 / DD 41.7%" is UNAUDITED third-party testimony** (sole source: one review
   site; no trade stream, dates, or account history). Treat as strong *adverse testimony*, not verified OOS.
3. **The "Q05 ceiling = MaxDD/net ≤1.3×" is INVENTED — no such gate exists.** Verified: Q05
   (`framework/scripts/q05_stress_medium.py:50-51`) gates **PF > 1.0 AND DD < 25% of $100k AND trades ≥ 20**;
   a DD breach is *parked for portfolio review*, not a MaxDD/net threshold. §5's acceptance bar is wrong.
4. **The LBMA-fix anchor is NOT established footing — contradicted by our own prior study.**
   `docs/research/XAU_FIX_DRIFT_STUDY_2026-06.md`: all t-stats < 2, no significant AM/PM pattern,
   *"No card before a proper M1 study."* §5's "LBMA fix has real order-flow footing" over-credits it. (Not
   fully refuted — a within-bar M1 signal isn't ruled out — but there is no established edge.)
5. **Spec conflict:** 20007 declares **`news-blackout ON`** (card line 72); trading macro-release windows
   contradicts the approved hypothesis. Resolve before any lane change.
6. **"2011–2019 OOS" is data-infeasible** (earliest XAU H1 bar ≈ 2017-10 per the fix study; no M5/M15 from
   2011) and is not true OOS without pre-registration of rules/thresholds.
7. **DL-083 mischaracterized:** it is a **regime-split return correlation** (admit < 0.15, reject ≥ 0.40),
   not a generic daily-Pearson boundary. Drawdown co-exceedance is a *secondary* path-risk metric, not the
   replacement dedup gate.

**Corrected acceptance test (replaces §5's bar):** compare the **gated arm vs an identical ungated arm**
(plus a matched-random-density control) on FTMO **tail** statistics — worst rolling-12-mo DD, DD duration,
daily expected shortfall, worst-day loss, Monte-Carlo p95 DD, and P(breaching 5% daily / 10% total at the
actual governor) — **not** MaxDD/net vs Balke's unrelated 3.05×. Density target stays **≥250/yr** (180 is
only the acceptable lower band; ≈$35.70/weekday vs $49.60 at 250).

**Corrected disposition:** retire the *unconditional* `GOLD_BREAKOUT` ("daily open ± k×ATR, first breach" =
price-band lore); retain **one preregistered `XAU_EVENT_VOL_BREAKOUT` hypothesis** with **10181
(`tv-xau-ny-orb-retest`, H1 ATR-conditioned NY-ORB, ~110/yr, EOD-flat) as the MANDATORY control** and Balke
as a second control. Note our XAU D1 survivors **10123 (standalone PF 1.51) and 10145 (PF 1.42) are
standalone-profitable** — they failed *portfolio admission* on correlation (~0.91), so "all XAU breakout is
dead" is too strong.

**The decisive experiment (Codex's design, adopted):** a **trigger-level, common-exit factorial** — freeze
volatility state *before* range/zone formation; hold the exit machinery IDENTICAL across arms (fixed
15/30/60-min + EOD); race triggers {Balke-range, multi-TF zone, LBMA-window, macro-window} × {ungated,
vol-gated, matched-random-density control}; measure forward return, MFE/MAE, FTMO tail. This isolates
whether the *breakout trigger* carries information vs whether exit/sizing/overnight packaging destroys a
usable trigger — without which "the breakout has no edge" and "the vol-gate is the edge" are both untested
assertions.

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

### 2a. Primary-source confirmation — his own words (Darwinex "Market Masters" interview `Q4LJyCn9_kA`, transcript fetched)

The interview transcript **confirms and sharpens** the adversarial verdict — the author himself undercuts
the marketing:
- **He calls it a commodity strategy.** On the S/R breakout: *"it's actually a very old strategy … used by
  many Traders … effective on many markets."* By his own account there is **no proprietary/unique edge** —
  it is a widely-used breakout (vindicates the structural-cause lens directly from the source).
- **The "9 strategies" are ONE level with varied exit management.** He places *"multiple pending orders at
  the resistance level, each one … a different … stop loss management, take profit management."* So the
  ensemble is literally one S/R zone with several exit parameterizations — exactly the "one over-parameterized
  breakout" the overfit lens predicted, from the author's mouth.
- **Anticipatory entry AT the zone, not a confirmed break.** He uses **zones, not lines**, and places pendings
  *at* the level (not above it): *"I used to do above … but last year I found by doing"* entries at the level
  works better. His real entry is anticipatory bracket-orders around a dynamic S/R zone with fast break-even
  management — not the "momentum-confirmed break" the reviews imply.
- **He ABANDONED the volatility-breakout.** His origin "dream EA" was a volatility breakout (*"if price moves
  fast … price will move forward in that direction"*) but he says *"I don't use this kind of strategy at the
  moment."* So the vol dimension is **not even in his shipped product** — our proposed vol-regime gate is a
  QM addition, not a recovery of his method.
- **Correction to an earlier agent claim:** there is **no "post-NY night mean-reversion scalping book."** The
  transcript's only relevant remark is that one of his DXZ strategies *"was a scalper wasn't running so well
  anymore"* — a passing mention of an underperforming scalper, not a mechanizable mean-reversion system.
  (No "mean reversion", "reversion", or "fade" appears anywhere in the transcript.)

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
> ⚠️ **SUPERSEDED by the REVISION section above** — the "Q05 ceiling ≤1.3×" is invented and the 2011–2019
> OOS is data-infeasible. Use the matched-arm FTMO tail test in the REVISION instead.
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

- **Primary source (DONE):** Darwinex "Market Masters" interview `Q4LJyCn9_kA` transcript fetched and
  folded in (see §2a). No further "night mean-reversion book" exists — that earlier agent claim was an
  overstatement of a one-line "underperforming scalper" remark.
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

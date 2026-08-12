# Mulham Trading — Channel Mechanization Dossier (2026-07-13)

**Mandate:** OWNER 2026-07-13 — mine https://www.youtube.com/@MulhamTrading
(180 videos), build strategy cards, feed the factory.

**Method:** yt-dlp channel enumeration (direct) → 38 priority transcripts via
proxy rotation (`tools/strategy_farm/fetch_transcript.py` primitives; batch
runner + status: `D:\QM\reports\research\mulham_trading_channel_2026-07-13\`)
→ 8 parallel extraction passes with mandatory per-rule caption timestamps →
this synthesis. agy has no video tool on the current build (verified 3×,
2026-07-12); captions are the only channel. **On-screen chart content is a
documented evidence GAP** — every card below flags caption-only provenance.
agy contributes R1 web reputation research: router ticket
`11105b13-8116-4ed3-a1fc-420dd98a0eff` (open at card-cut time; card R1 is
provisional per the 13033 precedent — author's own taught material, pipeline
judges).

**Inputs (all timestamped, machine-verified against transcripts):**
- Triage (all 180 videos classified): `docs/research/MULHAM_CHANNEL_TRIAGE_2026-07-13.md`
- Extractions: `D:\QM\reports\research\mulham_trading_channel_2026-07-13\extractions\cluster1..8*.md`
- Raw transcripts + fetch evidence: `...\transcripts\`, `...\batch_status.json`

## 1. Core finding: one engine, many liquidity objects

Across 38 analyzed videos the channel teaches ONE entry engine:

> HTF/session liquidity level is swept → validity gate (CHoCH / CISD /
> displacement / IFVG-close / rejection block) → retrace entry at a PD array
> (FVG-50%, OB proximal edge, OTE-62 fib) → SL beyond the sweep extreme →
> fixed R multiple (2.5–3R) or opposite-level target.

The videos differ in WHICH level is swept and WHEN. Distinct liquidity
objects found: (1) rolling 4H fractal swings, (2) Asian session range,
(3) prior-session H/L in next session's clock window, (4) prior-day PM-session
range, (5) midnight/daily-open price lines, (6) 20:00-EST H1 candle range
(CRT family), (7) Mon–Thu weekly expansion faded on Friday, (8) US500 opening
range gap (RTH close→open), (9) killzone-open ±30min sweep, (10) 15m
structural swing via M1 rectangle break.

Backtest evidence is thin channel-wide: the only structured claims are the 4H
sweep (Discord member, 3 months, 28 trades, 65% WR, +44R; cluster: template
videos 4cK3weGxZeA/IW7CSIfnJU4), Judas swing (author, 6 months EURUSD, 40
setups, 55% WR, +44R; Zsv16OGWVRU) and an EURUSD turtle-soup replay (15 days,
+20R, 76% WR; xzSFYcgKiao). None are verifiable; all are manual replays.
Author's own strategy ranking (1FWGwBBvNVk) D-tiers ICT/SMC and ORB while he
sells an ICT course — treated as an honesty signal about the class, not the
mechanics: **market structure is his only S-tier concept.**

## 2. Card slate (5 cards, IDs 13208–13212)

Selection criteria: distinct liquidity object, mechanically closed form after
documented codification decisions, not a documented-dead class, .DWX-testable,
index/metals preferred (FTMO mandate 2026-07-06), one card per object —
intra-family duplication left to Q09 admission.

| ID | Slug | Object | Symbols | Period |
|---|---|---|---|---|
| QM5_13208 | mulham-4h-sweep-fvg | rolling 4H fractal sweep (flagship) | XAUUSD, EURUSD | M15 |
| QM5_13209 | mulham-pm-range-sweep | prior-day PM range, NY-morning sweep | US500, NDX | M5 |
| QM5_13210 | mulham-asian-sweep-london | Asian range, London-window wick sweep | EURUSD, XAUUSD | M5 |
| QM5_13211 | mulham-tgif-weekly-fade | Friday fade of Mon–Thu expansion | NDX, EURUSD | H4/M15 |
| QM5_13212 | mulham-us500-org | US500 opening range gap | US500 | M15 |

Full rule specs with timestamp citations live in the cards
(`D:\QM\strategy_farm\artifacts\cards_approved\QM5_1320[8-9]*.md`,
`QM5_1321[0-2]*.md`) and the cluster extraction files.

## 3. Exclusions (documented, with reasons)

- **Silver Bullet windows** (POyd5Quw0WY, 6ZMZcChkoHo, Myr2s-hpeBY,
  oiArTaTBEkI; also the 10:00–11:00 entry leg of 1-tXh6e3F00): documented
  dead class (2026-06-27, re-confirmed 2026-07-12). Not re-mechanized.
- **NY-open M1 session-range reversals** (Judas swing M1 variant xMg1zRrQNgU/
  Zsv16OGWVRU midnight→8:30 anchor; 938DnASjXyM Tip-1 Asia-range London
  continuation): same class as QM5_13204 (9 configs, all PF<1.0). The Judas
  6-month backtest is the channel's best evidence, but the mechanic is
  dead-class-adjacent on our own records — excluded; revisit only if 13209/
  13210 (the two session-range cards with genuinely different anchors) pass
  Q02 and show the family is not uniformly dead.
- **1-min sniper family** (~17 videos): structural-anchor variant is NOT
  identical to 13204 (cluster8 class check) but low prior + FX-M1 commission
  hostility (raw-spread requirement admitted by author) → no card. Class
  boundary probe only if the slate above produces survivors.
- **CRT/20:00-candle gold** (KRfZ3qPbwR0, rZlRz-dg5LE): 13033
  family (time-anchored candle-range sweep). Fold as potential input variant
  of 13033 after its Q02 verdict, not a new card.
- **Breaker block** (Lg0jjYB2loo): 1-week discretionary replay, experience-
  gated skips, no aggregate stats — R1 too weak; retest leg noted as possible
  v2 module.
- **Candle patterns** (CCT/2-candle/3-candle AMD): delegation-heavy; AMD
  sweep+reclaim core duplicates 13033 class. CCT previous-candle-color bias
  kept as a filter primitive, not a card.
- **Concept/psychology videos** (~95): no mechanics (triage doc).

## 4. Reusable modules (build-lane notes, not cards)

- Valid-pullback / CISD MSS definition (pSoTxziDGNU; cluster6) — candidate
  upgrade for the CHoCH step of any sweep EA.
- Midnight/8:30-open premium-discount side gate (IFVv-h2O0QU) — bias filter.
- D1 EMA(9)>EMA(18) bias (uL5ecYgsd9U) — trivial regime filter.
- 61.8% inducement rule (_56pepw4hvU): retrace short of 61.8% ⇒ expect second
  sweep — skip-filter candidate.
- IFVG close-through trigger (y6FE59PWa1Q) and BPR object (Z2JxMuXTpww) —
  alternative gate/entry objects for v2 variants.
- Rule-50 partial management (xzSFYcgKiao) — management variant, test in
  exit-surgery passes only.

## 5. Falsification discipline

Every card carries: Q02 gross PF≥1.20 at card-scaled floor kills the family;
no window re-fitting; symmetric direction honesty; the two session-range cards
(13209/13210) explicitly test the INCREMENTAL elements vs the dead 13204
class (defined range object + opposite-extreme target + regime gate) — if
they die at Q02, the whole Mulham session-reversal family is closed for good
and the exclusion list above becomes permanent.

## 6. Risks

- Caption-only provenance: chart-level nuances (exact fractal window, FVG
  quality) are codified by us, not the author — flagged per card as deliberate
  deviations (13033 precedent).
- FX instances (EURUSD legs of 13208/13210/13211) face the ~$45/trade
  commission gate; metals/index legs are the mandate-preferred carriers.
- Author monetizes mentorship/Discord; performance claims are marketing until
  agy's R1 ticket lands. R1=PASS is provisional on the 13033 "author's own
  taught material" rationale.

# Mulham Trading — Full-Channel Triage (2026-07-13)

**Source:** https://www.youtube.com/@MulhamTrading — 180 public videos enumerated
via yt-dlp flat-playlist on 2026-07-13 (VPS direct; enumeration is not
bot-blocked). Raw manifest:
`D:\QM\reports\research\mulham_trading_channel_2026-07-13\channel_videos_raw.txt`.

**Mandate:** OWNER directive 2026-07-13 — mine the entire channel, build strategy
cards for mechanizable strategies, feed them into the factory. Explicit OWNER
order, so the reservoir-throttle (research only when ready cards < 5) does not
gate this work.

**Method reality (binding):** agy has NO video tool on the current build
(confirmed 3×, memory 2026-07-12). The only working channel is public-caption
transcripts via proxy rotation (`tools/strategy_farm/fetch_transcript.py`).
Captions ≠ screen: chart annotations are a documented evidence GAP; per-rule
timestamps are mandatory (fabrication case fe1704fc). agy contributes what it
can do — web source-reputation research (R1) — via a router ticket.

## Channel profile

Single author ("Mulham"), ~8 years claimed trading experience, content is
almost exclusively **ICT/SMC** (liquidity sweeps, FVG, order blocks, market
structure, killzones) with a recent drift toward channel-native "rules based"
scalping formats. High repetition: the same core mechanics recur across dozens
of videos in different packaging. Around 12 videos carry explicit backtest
claims — those are the R1 anchors.

## Cluster verdicts (all 180 videos classified)

### A. Backtest-claim videos — R1 anchors, fetch first (12)
| Video | Title (short) | Note |
|---|---|---|
| 4cK3weGxZeA | Backtesting 4H Liquidity Sweep — 75% WR | top R1 anchor, 46 min |
| IW7CSIfnJU4 | Backtested 4H Sweep — impressive results | same mechanic, 2nd sample |
| Zsv16OGWVRU | Backtested Judas Swing, 6 months | |
| xzSFYcgKiao | High-WR Liquidity Sweep + 1h backtesting | 75 min |
| Lg0jjYB2loo | Breaker Block real backtesting | |
| nM75XTSKoT0 | 40 pips/day ICT strategy, backtesting results | |
| 18NN257cu2c | Simple ICT liquidity strategy, backtested | |
| POyd5Quw0WY | Silver Bullet 33% ROI backtest | DEAD CLASS — contra-reference only |
| 1FWGwBBvNVk | Tested every strategy, ranked (7 yrs) | author's own ranking = triage signal |
| ZSxnS60NW9Q | Tested every strategy, this one changed everything | ranking signal |
| 938DnASjXyM | 3-step 1-min scalping (sniper) | representative of 1-min family — class check vs 13204 |
| 4LLlROGjI0Y et al. | — | psychology framing, no backtest |

### B. Session-/time-anchored sweep mechanics — core card candidates
Distinct mechanics identified from titles (transcripts must confirm):
1. **4H candle-range sweep reversal** (4cK3weGxZeA, IW7CSIfnJU4, sKXhF6OQ_QY) —
   caution: mechanically adjacent to QM5_13033 CRT; card only if the transcript
   shows a genuinely different anchor/window/trigger.
2. **Asian-range sweep at London open** (GfxScm82JHM, Qts-UF2MdZY, AmwFBku47dU,
   Ujtiqz4bLeU) — session-range sweep, we have NO live card on this.
3. **Judas swing** (xMg1zRrQNgU, Zsv16OGWVRU) — London false-move reversal.
4. **TGIF Friday reversal** (AmrstrJpKE0) — day-of-week anchored retracement;
   fits our calendar-cadence primitive machinery.
5. **8:30 / midnight-open High-Low-of-day timing** (IFVv-h2O0QU, uBVIE_QbIEU) —
   time-anchored extreme formation; potentially novel primitive.
6. **Turtle soup HTF-level sweep** (WN8e-TLksog, rZnjkZ_JV2o, 9oSQ_XsnMcI).
7. **Opening Range Gap** (XcG9b43jjJo) — overnight-gap fade/fill.
8. **PM-session sweep** (VcutSZuf1FY).

### C. Candle-pattern mechanics
- **Candle Continuity Theory** (t2gRVa4Ontw, mAjWnerBs4M, BxHQgX4QZRM,
  3xrbhv_RYbw) — 1-candle continuation logic.
- **2-candle strategy** (s66K_NCbDmE), **3-candle** (KwlcaNPclm0).
- **1-candle gold** (rZlRz-dg5LE).

### D. Channel-native "rules based" formats (non-ICT packaging)
- 15-min gold rules-based (tD5apb1P55E), "2 lines" 15-min (MKsjbL0WNjg),
  gold full course (KRfZ3qPbwR0, 8bPZDxRdPDg, JyUX0y5NSDA, ddM8U79r-EE),
  "1 rectangle" scalping (YYJqdey4dV0, _56pepw4hvU), swing strategy
  (o-51_-x_oqw), indicator strategies (qOwnZdkatGw, f8pacTyc7aM, LB8_k9-gvS4,
  XFZe47HGdi4).

### E. Concept/education/psychology — NO cards (≈95 videos)
FVG theory (Q1vS5kordLA, q5Qz9xxVKKI, ZzP5iGMuD_Y, N4wZgUi6xP8, 2SLJnyoVEXo,
64EDxtO14Gc, CZpRwGVH_NI, 5CWhpJxcIAM, iRBT1vqSksE, ZX-LtPTZmoo, _tV7B0qJ6jU,
tqU1Raa-Dss, Mx_4O9bSprE, qE2G2DeU5vI), market structure (t9ZcAV9iYCI,
qsZtluOzC2k, NRuC72gxu04, ifbtPYSGDVQ, M0Yw-kBToo0, ufVbXjADLMk, WbYdzljNEf8,
fr1_cgCSBaw, IcswyyF0De8, pSoTxziDGNU†), bias methods (t8JhvEbifR8,
uL5ecYgsd9U†, LUzTe5hv1A4, FkMYha47r-k, qCfOcd86va0), PD arrays / OB / BPR /
SMT / MMXM theory, liquidity concepts (mKwLb10OQaY, ItWIYU41d-8, LwrWgV5EdjY,
og9vT8E5F2Y, hVSIs5qb9Uk, etViwWHn91Y, _6cvdY3Alws, Nd79mZglSO4, Fu2__JYnmx8,
eVNCijRybmo), psychology/meta (CqYXQ54pj-M, 4LLlROGjI0Y, M2vnxiWsKGs,
mgrWYQM5Xlo, gEdlCi2BIBI, ozevLHj3q4o, qJsUnTyh4uc, 6otkAzkl8PE, cKAVojV1840,
aW8XAbcNRsw, SPJGBkAYoY8, BAfRVpKIxZ4, fPFOXqmzJp8, QNiIiEhyNBk, Cj09mzu5_oU,
FxHBdSCDKdM, dXzvA8-rcMM, BL0HTuNBpPI, SYQQq9FBAkw, dibFmOOjyOA), tooling/
aesthetics (ItURBcTvT7o, 9YuKVhn7gnE, u4oG06EW0Z4, XFZe47HGdi4), mega-courses
(IXSu0MClr34 12h, ExYPERyGsUc, 6u7kpCEVROc, OwGhFkcFtRw, JbB4ofg7Gq0,
w9WQBU2N9t0, UqW5hxFx62Y, r8bgiWo7ef8 2.4h) — course videos may be mined later
for rule detail on a specific mechanic, not as standalone cards.
† = "100% mechanical" claim → borderline; transcript decides.

### F. Documented-dead classes — DO NOT re-mechanize
- **ICT Silver Bullet** (6ZMZcChkoHo, Myr2s-hpeBY, oiArTaTBEkI, POyd5Quw0WY):
  no mechanical edge — memory 2026-06-27, re-confirmed 2026-07-12 (13204).
- **ICT first-swing 1-min NY sweep** (13204, video zw_J5RP31cA, 9 configs all
  PF < 1.0): Mulham's "1-Minute Scalping (Sniper Entry)" family (CBFqrJYBjE0,
  yyYwZIMrfGI, dC6isQNwY6s, hFGN36FH6C0, NWjm1qI2fgY, _yAj5o9BP8Q, Y1r7fTJ0FZ8,
  938DnASjXyM, NhnQASg7Bq4, kfyWeqbZdKk, NVMTuja5SVw, ZJQjf__B2Lg, tSNpsvMuhpo,
  ZdpmX0tfw88, 8Tpn0noZRxg, HfBJMM1ULKY, 3Orrok1u23s) is PRESUMED the same
  class until one representative transcript (938DnASjXyM) proves a different
  mechanic. Default: no cards from this family.
- **Judas Swing** overlaps the Silver-Bullet time-window class — transcript
  must show a distinct, testable anchor before a card is cut.

### G. Duplicates vs existing QM work — no new cards
- CRT video (Q-9r_jY1S50) ≡ QM5_13033 (Novo CRT). Contra/corroboration
  reference only.
- Turtle soup ≡ generic HTF sweep reversal — overlaps 13033 + the 4H-sweep
  candidate; dedupe at card stage.
- Wayward-style BB scalping: none found on this channel (13031 unaffected).

## Priority fetch list (batch 1, 30 videos, running)

Batch runner: scratchpad `mulham_batch_fetch.py` → transcripts to
`D:\QM\reports\research\mulham_trading_channel_2026-07-13\transcripts\`,
status JSON `batch_status.json`. Batch 2 (ranking videos, xzSFYcgKiao,
Lg0jjYB2loo, 938DnASjXyM, KwlcaNPclm0) queued after batch 1 verdicts.

## Card budget expectation

180 videos → ~8 distinct mechanics → expect **3–5 cards** after dedupe vs
existing work and dead classes. Selection criteria: (1) mechanically complete
in transcript, (2) not a documented-dead class, (3) orthogonal to live book +
existing cards, (4) .DWX-testable (index/metals preferred per FTMO mandate).

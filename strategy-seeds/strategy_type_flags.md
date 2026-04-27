# Strategy Type Flags — V4-Mined Controlled Vocabulary

> **Status (2026-04-27):** DRAFT, awaiting CEO + CTO ratification on QUA-244.
> **Owner:** Research Agent.
> **Scope:** This file is the **controlled vocabulary** of `strategy_type_flags` used in V5 Strategy Cards (`strategy-seeds/cards/_TEMPLATE.md` field, child issue under QUA-236). It is **mined from V4 archives** — every flag has at least one V4-named example. New flags MUST cite V4 evidence; otherwise propose a new source via Research before adding.

## Why this file exists

OWNER directive (paraphrased on QUA-244): "We have so much information collected from V4, all of that was already known there!" — V5 must not re-invent strategy-type buckets. The V4 archive already has a de-facto taxonomy expressed across:

- The 5 V4 research-inspiration specs in `strategy-seeds/specs/` (ATH-Breakout-ATR-Trail, Good-Carry-Bad-Carry, Modernised Turtle, Seasonality-Trend-MR-Bitcoin, Two-Regime Trend-Following).
- The 8 V4 SM_XXX regime / carry / vol-bucket EAs explicitly named in the Two-Regime spec §9 and the Good-Carry-Bad-Carry spec §9 (the load-bearing "what is net-new vs existing family" tables).
- The V4 star-EA reference (`reference/v4_doc/star-ea-reference.md` — Gotobi, GoldAsianDrift, SilverBullet, ProGo, ADX5NR6).
- The V4 locked-basket snapshot (`strategy-seeds/v5_locked_basket_2026-04-18.md`) — referenced for SM_124 / SM_186 / SM_221 / SM_345 / SM_157 / SM_640 / SM_882 / SM_890.
- The V4 learnings archive (`lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md`) — for the modality flags (gridding, scalping, ml-required, pyramiding) that V4 already disambiguated as hard rules.

This file harvests the vocabulary V4 already encoded; it does **not** introduce new buckets.

## How flags are used on a Strategy Card

Each card may carry **one or more** flags. They are not mutually exclusive — a single strategy is typically described by one entry-mechanism + one exit-mechanism + zero-to-many filter/overlay flags + a direction flag. Example: **Modernised Turtle** = `donchian-breakout` (entry) + `donchian-trail` + `atr-hard-stop` (exits) + `trend-filter-ma` (filter) + `symmetric-long-short` (direction). Example: **Good-Carry-Bad-Carry** = `carry-direction` + `skew-regime-filter` (entry) + `atr-hard-stop` + `signal-reversal-exit` (exits) + `symmetric-long-short`.

Card reviewers should expect 3–6 flags per card. Fewer than 2 is suspicious (under-specified). More than 8 is suspicious (probably composite of two strategies — split into two cards).

---

## A. Entry-mechanism flags

### donchian-breakout
- **Definition**: Entry triggered when the closing or intrabar price clears the prior N-day donchian high (long) or low (short), N typically 20–55 bars.
- **V4 examples**: Modernised Turtle (V4 inspiration spec, Donchian 55/20 default); generic donchian EAs derived from `Include/FTMO/FTMO_Strategy_Base.mqh` referenced in `strategy-seeds/specs/ath-breakout-atr-trail.md` §9.
- **Disambiguation from**: `ath-breakout` (donchian uses rolling N≤100; ATH uses N≥252 bars and produces 0–3 trades/year/symbol vs donchian's 6–10); `n-period-max-continuation` (donchian breakout opens a position to ride a multi-week trend; n-period-max-continuation uses N=5–10 with a fixed time-stop hold, not a trail).

### ath-breakout
- **Definition**: Entry triggered when the close clears a very-long-lookback (N ≥ 252 bar, ≈1Y D1) or true all-time-high price, with the wide-trail-pays-the-tail thesis.
- **V4 examples**: ATH-Breakout-ATR-Trail (V4 inspiration spec, Wilcox-Crittenden 2005-derived); SM_254 family (custom ATR-trail EAs cited in `specs/ath-breakout-atr-trail.md` §9.4 as the trail-implementation pattern reference).
- **Disambiguation from**: `donchian-breakout` (lookback ≥ 252 vs ≤ 100; signal density ~5–30 trades/symbol over a 6Y DEV window vs ~50–120; degenerates into donchian if N is reduced).

### n-period-max-continuation
- **Definition**: Long-bias entry when current close prints at or above an N-bar maximum, N typically 5–50, expecting short-horizon momentum continuation over a time-bounded hold.
- **V4 examples**: Padysak-Vojtko trend-follow leg in `specs/seasonality-trend-mr-bitcoin.md` §3 Sub-signal B (default N=10, hold 5 days).
- **Disambiguation from**: `donchian-breakout` (much shorter N=5–50; pairs with a fixed `time-stop` exit, not `donchian-trail` or `atr-trailing-stop`); `ath-breakout` (short lookback, not very-long).

### n-period-min-reversion
- **Definition**: Long-bias entry when current close prints at or below an N-bar minimum, N typically 3–20, expecting bounce / mean-reversion over a time-bounded hold.
- **V4 examples**: Padysak-Vojtko mean-revert leg in `specs/seasonality-trend-mr-bitcoin.md` §3 Sub-signal C (default N=10, hold 3 days).
- **Disambiguation from**: `n-period-max-continuation` (opposite extreme, opposite expected direction over the hold); `mean-revert-rsi` (uses raw price extremum, not an oscillator threshold).

### carry-direction
- **Definition**: Entry direction set by the sign of the broker overnight swap differential (`SymbolInfoDouble(SYMBOL_SWAP_LONG/SHORT)`); long when positive carry, short when negative carry, optionally smoothed and dead-banded.
- **V4 examples**: SM_076 CarryDivergence (AUDUSD/USDJPY M15 carry-direction with intraday divergence trigger, cited in `specs/good-carry-bad-carry.md` §9); SM_1341 / SM_1342 / SM_1343 / SM_1363 generic carry filters (binary "trade only carry-aligned" rule, same source).
- **Disambiguation from**: `skew-regime-filter` (carry-direction sets the side; skew-regime-filter is an additional gate over the carry side, not a substitute).

### session-close-seasonality
- **Definition**: Entry/exit gated to a specific calendar window adjacent to a recurring session close (e.g. NYSE cash close, BTC 21:00–23:00 UTC), exploiting end-of-day rebalancing flow.
- **V4 examples**: Padysak-Vojtko seasonality leg in `specs/seasonality-trend-mr-bitcoin.md` §3 Sub-signal A (post-NYSE-close drift, D1 proxy via prior-close-time gate).
- **Disambiguation from**: `session-time-gate` (gate is the trigger here — entry fires *because* the window opened — whereas `session-time-gate` is a filter over a different base entry); `intraday-day-of-month` (Gotobi-style date-based, not session-clock-based).

### intraday-day-of-month
- **Definition**: Entry triggered or biased by recurring calendar dates of the month (e.g. Japanese Gotobi: 5/10/15/20/25 dates concentrate fix-flow demand for USD/JPY).
- **V4 examples**: SM_124 Gotobi (UK100, V4 locked-basket; star-EA reference: "DSR leader, strong PF profile" — `reference/v4_doc/star-ea-reference.md`).
- **Disambiguation from**: `session-close-seasonality` (date-of-month, not time-of-day); `session-time-gate` (does not gate a different base — the date-of-month *is* the entry trigger).

### asian-session-drift
- **Definition**: Entry exploiting the directional drift of a specific asset (typically gold, silver, or AUD/JPY) during the Asian trading session, often paired with a regime gate.
- **V4 examples**: SM_186 GoldAsianDrift (XAU during Asian session, "Portfolio star profile" in V4 — `reference/v4_doc/star-ea-reference.md`; uses the `RegimeFiltered` overlay per `specs/two-regime-trend-following.md` §9).
- **Disambiguation from**: `session-time-gate` (Asian-session-drift packages session + asset thesis as the entry trigger; pure `session-time-gate` is just a filter over an arbitrary base); `intraday-session-pattern` (specifically Asian session, not London-fix or NY-AM patterns).

### intraday-session-pattern
- **Definition**: Entry exploiting a known intraday micro-pattern within a specific session (e.g. ICT Silver Bullet: 10:00–11:00 NY session liquidity grab; pivot break-and-go).
- **V4 examples**: SM_221 SilverBullet (V4 locked-basket, ICT London Silver-Bullet window — `reference/v4_doc/star-ea-reference.md`, "Expansion running"); SM_419 ProGo (pivot break-and-go pattern, "Strong USDCHF sample" — same reference).
- **Disambiguation from**: `asian-session-drift` (NY/London session, different liquidity dynamics); `session-time-gate` (session window IS the entry trigger here, not a filter).

### narrow-range-breakout
- **Definition**: Entry on the breakout of a range-contraction / NR-bar pattern, often paired with an ADX or volatility-regime filter to require coiled-spring conditions.
- **V4 examples**: SM_404 ADX5NR6 (ADX(5) + Narrow-Range-6, "Strong holdout PF, 6/8 walk-forward symbols" — `reference/v4_doc/star-ea-reference.md`).
- **Disambiguation from**: `donchian-breakout` (NR-breakout requires an explicit range-contraction precondition; donchian fires on any N-bar extreme regardless of preceding compression); `vol-regime-gate` (NR is the entry, not just an overlay).

### mean-revert-rsi
- **Definition**: Entry on a classic oscillator-extreme reversion signal (e.g. RSI(14) < 30 with a longer-MA trend filter), with the bounce thesis.
- **V4 examples**: Cited in `strategy-seeds/cards/_TEMPLATE.md` §4 example pseudocode as the canonical `RSI(14)<30 AND price > SMA(200)` entry. **No V4 SM-named survivor in the locked-basket snapshot or star-EA reference**, so the flag is reserved for future research-mined cards rather than backed by a V4 deployed-EA example. *(Flagged for CEO/CTO discussion: keep as reserved, or strike if no V4 deployment evidence found.)*
- **Disambiguation from**: `n-period-min-reversion` (RSI uses an oscillator threshold; min-reversion uses raw N-bar price extremum).

---

## B. Exit-mechanism flags

### atr-trailing-stop
- **Definition**: Volatility-scaled monotone trailing stop (long: `trail = max(trail_prev, max_high_since_entry − ATR(P)·M)`), with M typically 2–10 ATR units; ATR may be frozen at entry or recomputed each bar.
- **V4 examples**: ATH-Breakout-ATR-Trail (V4 inspiration spec, ATR(42)·10 default, recomputed each bar — load-bearing per §9); SM_254 family (custom ATR-trail EAs referenced as trail-implementation pattern in `specs/ath-breakout-atr-trail.md` §9.4).
- **Disambiguation from**: `donchian-trail` (price-based extreme, not vol-based distance); `atr-hard-stop` (frozen safety backstop, not a trail; the same EA can have both).

### donchian-trail
- **Definition**: Exit when price prints the M-day opposite-direction donchian extreme (long: low ≤ min(low[t-M..t-1])), classic Turtle 20/55 pairing.
- **V4 examples**: Modernised Turtle (V4 inspiration spec, default 20-day opposite-extreme exit pairs with 55-day entry).
- **Disambiguation from**: `atr-trailing-stop` (extreme-based not vol-based; can fire even in low-vol regimes where ATR-trail is too wide); `time-stop` (price-conditional, not clock-only).

### atr-hard-stop
- **Definition**: Fixed catastrophic stop placed at entry at distance `ATR(P)·M`, typically M = 2–4 for primary stops, 12–20 for far-backstop "trail-failed" safeties; ATR frozen at entry.
- **V4 examples**: Modernised Turtle 2N stop (V4 spec); ATH-Breakout-ATR-Trail 15×ATR safety backstop (V4 spec); Padysak-Vojtko 3×ATR(14) hard stop on all 3 legs.
- **Disambiguation from**: `atr-trailing-stop` (hard stop never moves; trail moves monotonically with price); `time-stop` (price level, not bar count).

### time-stop
- **Definition**: Exit at a fixed number of bars after entry (e.g. HoldDays = 5), regardless of price action; primary or sole exit on time-bounded thesis strategies.
- **V4 examples**: Padysak-Vojtko all 3 legs (`specs/seasonality-trend-mr-bitcoin.md` §4: 1-day hold for seasonality, 5-day for trend, 3-day for MR — primary exit, not just safety).
- **Disambiguation from**: `donchian-trail` / `atr-trailing-stop` (no price condition fires the exit on the time leg); `signal-reversal-exit` (clock-only, not signal-driven).

### signal-reversal-exit
- **Definition**: Exit when the same signal that triggered entry reverses (carry-flip, posterior-blend flip, target-exposure crosses through zero), often debounced over 2–3 consecutive bars.
- **V4 examples**: Two-Regime Trend-Following (V4 inspiration spec §4: target-exposure reversal exit + posterior-blend flip is the *primary* mechanism); Good-Carry-Bad-Carry (V4 inspiration spec §4: 2-bar carry-direction-flip exit + 3-bar skew-regime-flip exit).
- **Disambiguation from**: `donchian-trail` (signal logic, not price extreme); `regime-stand-down-exit` (driven by *signal value*, not by the *detector failing diagnostics*).

### regime-stand-down-exit
- **Definition**: Exit triggered when the regime detector itself fails its self-validation diagnostics (e.g. BIC gap collapses, transition-matrix diagonals < 0.9, state-mean separation degenerates), and the EA refuses to take new positions until diagnostics restore.
- **V4 examples**: Two-Regime Trend-Following stand-down (V4 inspiration spec §3 Stage A & §4: HMM diagnostic-fail closes positions and blocks entries until next refit). **No corresponding heuristic V4 SM_XXX EA — the existing `RegimeFiltered` family (SM_186/237/370) does NOT have intrinsic self-invalidation per `specs/two-regime-trend-following.md` §9.** Flag is reserved for HMM/MS-style detectors; do not apply to heuristic-gate EAs.
- **Disambiguation from**: `signal-reversal-exit` (driven by detector *failing*, not detector *flipping value*); `regime-filter-multi` (overlay flag is an entry filter; this is the corresponding exit trigger).

### friday-close-flatten
- **Definition**: Forced flat at Friday session close (default V5 framework behaviour per `cards/_TEMPLATE.md` §11), to neutralise weekend-gap risk on indices/metals.
- **V4 examples**: `EnableFridayClose` parameter in Padysak-Vojtko spec §4 (`FlattenOnFriday` default false for FX, default-on recommended for indices). Default V5 framework rule: weekend-gap-sensitive symbols flatten at Friday 21:00 broker time.
- **Disambiguation from**: `time-stop` (calendar-based not bar-count based; framework default not strategy-specific).

---

## C. Filter / regime-overlay flags

### trend-filter-ma
- **Definition**: Long-only suppression unless `Close > SMA(L)` (and symmetric for shorts), L typically 100–250; suppresses counter-trend signals against the dominant regime.
- **V4 examples**: Modernised Turtle SMA(200) filter (V4 inspiration spec); Two-Regime Trend-Following bull-state slow-MA signal (V4 inspiration spec §3 Stage B, BullMA_L=200 default).
- **Disambiguation from**: `vol-regime-gate` (price-vs-MA, not vol bucket); `regime-filter-multi` (single-feature MA, not multi-feature decision tree).

### vol-regime-gate
- **Definition**: Single-feature ATR-ratio / vol-percentile classifier modulating either entry permission or risk size by vol bucket.
- **V4 examples**: SM_086 VolRatioRegime (ATR-short/ATR-long ratio bucket → risk multiplier — `specs/two-regime-trend-following.md` §9 table); SM_104 VRRegimeSwitch (vol-ratio classifier switches between two fixed rules at a vol threshold — same table); SM_110 RiskRegimeSwitch (vol-ratio classifier scales risk per bucket; entry rule unchanged — same table).
- **Disambiguation from**: `regime-filter-multi` (single-feature ATR ratio, not multi-feature engineered tree); `atr-regime-mr-gate` (specifically MR-only-in-low-ATR; vol-regime-gate is generic).

### atr-regime-mr-gate
- **Definition**: ATR-percentile gate restricting *mean-reversion* entries to low-ATR regimes only — assumes MR is unsafe in vol expansions.
- **V4 examples**: SM_141 ATRRegimeMR (ATR percentile, gates MR entries to low-ATR regime only — `specs/two-regime-trend-following.md` §9 table).
- **Disambiguation from**: `vol-regime-gate` (general-purpose vol bucket; this flag is MR-specific and unidirectional — only blocks high-vol entries on MR strategies).

### regime-filter-multi
- **Definition**: Heuristic multi-feature regime classifier (typically engineered decision tree over ATR / HLR / time-of-day / SMA-position) producing GREEN / YELLOW / RED labels that gate or scale a base strategy's entries.
- **V4 examples**: SM_186 RegimeFiltered (`g_base.EvaluateRegimeV1` GREEN/YELLOW/RED gate + risk multiplier — RED=block, YELLOW=half-risk, GREEN=full; portfolio star, GoldAsianDrift base — `specs/two-regime-trend-following.md` §9); SM_237 RegimeFiltered (same pattern, different base strategy); SM_370 RegimeFiltered (third base strategy).
- **Disambiguation from**: `vol-regime-gate` (multi-feature engineered tree, not single ATR ratio); `hmm-regime-blend` (heuristic discrete labels, not statistical posterior probability — V4's existing family lacks intrinsic self-invalidation per spec §9).

### hmm-regime-blend
- **Definition**: 2-state Markov-switching / Hidden-Markov-Model regime detector producing a continuous posterior `P(bull|data)`, blended into a posterior-weighted target exposure across two distinct rule sets (one per regime), with self-invalidating diagnostics.
- **V4 examples**: Two-Regime Trend-Following (V4 inspiration spec, Zakamulin-Giner 2023 derivative — full HMM with EM, posterior-blend, BIC/transition-diag/state-mean self-checks; explicitly net-new vs `RegimeFiltered` heuristic family per §9).
- **Disambiguation from**: `regime-filter-multi` (heuristic discrete labels vs continuous posterior; rule *gates* in heuristic vs rule *changes* in HMM-blend); `vol-regime-gate` (statistical likelihood model on returns vs single-ATR-ratio bucket).

### skew-regime-filter
- **Definition**: Realized higher-moment (rolling skewness or range-based skew over D1 returns) gate over a base entry, suppressing trades when the recent return-distribution shape signals adverse-tail conditions.
- **V4 examples**: Good-Carry-Bad-Carry (V4 inspiration spec, Bekaert-Panayotov 2018 derivative — realized-skew over 60-bar window gates carry direction; explicitly distinct from carry-only baseline per §9 net-new argument). **No V4 SM-named deployed example** — the spec's whole point is that no V4 EA has this gate (SM_076 / SM_1341 / SM_1342 / SM_1343 / SM_1363 are carry-only without skew filter).
- **Disambiguation from**: `vol-regime-gate` (third-moment, not second-moment); `carry-direction` (skew-regime-filter is the *gate over* carry-direction — never used standalone).

### session-time-gate
- **Definition**: Trade only inside a specified broker-session window (e.g. London 08:00–12:00, NY 13:30–17:30 broker time) — *gates a different base entry*, not the entry trigger itself.
- **V4 examples**: SM_069 RegimeGatedLDN (heuristic London-session gate blocking trades outside the permitted window — `specs/two-regime-trend-following.md` §9 table).
- **Disambiguation from**: `intraday-session-pattern` (session is the trigger, not a filter); `session-close-seasonality` (specifically post-close drift, not arbitrary intraday window); `asian-session-drift` (packages session + asset thesis as entry, not a filter).

### news-blackout
- **Definition**: Suppress entries (and optionally close positions) inside an N-minute window around scheduled high-impact news events; standard V5 framework module per `cards/_TEMPLATE.md` §11 and Pipeline P8 News Impact gate.
- **V4 examples**: P8 News Impact gate (V4/V5 pipeline standard, modes OFF / PAUSE / SKIP_DAY per `decisions/2026-04-25_news_compliance_variants_TBD.md`); referenced as deferred-to-P8 in all 5 V4 inspiration specs §4.
- **Disambiguation from**: `session-time-gate` (event-driven, not clock-based); `friday-close-flatten` (news-event window, not weekend-gap window).

---

## D. Direction flags

### symmetric-long-short
- **Definition**: Both long and short legs implemented and ablatable as P3 axes (`EnableLongs`, `EnableShorts` independent inputs); FX-default since cross-rates have no secular drift.
- **V4 examples**: Modernised Turtle (V4 inspiration spec §3); ATH-Breakout-ATR-Trail (V4 inspiration spec §3 — explicitly "Drop long-only" decision); Two-Regime Trend-Following (V4 inspiration spec §3); Good-Carry-Bad-Carry (V4 inspiration spec §3).
- **Disambiguation from**: `long-only` (defaults differ; ablation surface differs).

### long-only
- **Definition**: Strategy implements long entries only; short side intentionally out of scope, typically because the underlying thesis assumes secular upward drift (equities / BTC) or asymmetric anomaly.
- **V4 examples**: Padysak-Vojtko Bitcoin spec (V4 inspiration, `specs/seasonality-trend-mr-bitcoin.md` §3 — "the paper is long-only — no short on the MAX/MIN legs").
- **Disambiguation from**: `symmetric-long-short` (intentional asymmetry, not just an ablation result).

---

## E. Modality flags (V4 hard-rule disambiguations carried into V5)

These flags are already named in `cards/_TEMPLATE.md` §10 (`gridding`, `scalping`, `ml_required`) and §11 (allowability checklist). Listed here for completeness so a card carries them as explicit booleans rather than implicit assumptions. Their definitions trace to `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md` and CLAUDE.md hard rules.

### gridding
- **Definition**: Strategy adds positions on adverse moves at fixed grid intervals, escalating exposure into drawdowns.
- **V4 examples**: V4 had grid-style EAs; in V5 strict 1%-cap fallback documentation is required per `cards/_TEMPLATE.md` §11. **No grid EA in the V4 locked-basket snapshot or star-EA reference** — V4's surviving sleeves are all non-grid.
- **Disambiguation from**: `pyramiding` (gridding adds *into losses* at fixed intervals; pyramiding adds *into profits*, e.g. Classic Turtle's +0.5N stacking).

### scalping
- **Definition**: Sub-M5 / very-short-hold strategy where realistic VPS latency materially affects fills; requires P5b stress with calibrated latency simulation.
- **V4 examples**: V4's M15 SM_076 CarryDivergence is borderline (M15 is not strictly scalping, but flagged historically in V4 review as latency-sensitive due to swap-tick timing). Most V4 surviving sleeves are H1/D1, not scalping.
- **Disambiguation from**: V5 framework requires Friday-close compatibility for scalping unless explicitly waived; standard P8 news-blackout still applies.

### ml-required
- **Definition**: Strategy uses any machine-learning model (neural net, gradient boost, random forest, online learner) for signal generation or filtering; **V5 hard-fail** per CLAUDE.md and `cards/_TEMPLATE.md` §11 (`EA_ML_FORBIDDEN`).
- **V4 examples**: None — V4 explicitly rejected ML strategies. Flag is included as a hard-fail check on the card, not as a category that has V4 examples.
- **Disambiguation from**: `hmm-regime-blend` (HMM with EM is a maximum-likelihood statistical fit, *not* machine learning in the V5 sense — no gradient descent on a parameterised function approximator, no held-out validation set; per `specs/two-regime-trend-following.md` §9 EM is acceptable as native MQL5, ~150–250 LOC).

### pyramiding
- **Definition**: Strategy adds units to a winning position at favourable-direction intervals (e.g. Classic Turtle 4-unit stack at +0.5N intervals); banned by V5 framework default per `cards/_TEMPLATE.md` §7 and Modernised Turtle §9 ("incompatible with FTMO / Darwinex-Zero single-trade risk caps").
- **V4 examples**: Classic Turtle (rejected pattern); explicitly NOT used in any V4 surviving SM_XXX sleeve. Modernised Turtle V4 inspiration spec §9: "Pyramiding: Up to 4 units at +0.5N intervals → None — one full-risk unit per signal".
- **Disambiguation from**: `gridding` (adds into profits, not losses); diversification at portfolio level (P9 family-cap-3 / symbol-cap-2) is not pyramiding.

---

## Mining provenance summary

| Source path | Flags contributed |
|---|---|
| `strategy-seeds/specs/ath-breakout-atr-trail.md` | `ath-breakout`, `atr-trailing-stop`, `atr-hard-stop`, `symmetric-long-short` |
| `strategy-seeds/specs/modernising-turtle-trading.md` | `donchian-breakout`, `donchian-trail`, `atr-hard-stop`, `trend-filter-ma`, `symmetric-long-short`, `pyramiding` (rejected) |
| `strategy-seeds/specs/good-carry-bad-carry.md` | `carry-direction`, `skew-regime-filter`, `signal-reversal-exit`, `atr-hard-stop`, `symmetric-long-short` |
| `strategy-seeds/specs/two-regime-trend-following.md` | `hmm-regime-blend`, `signal-reversal-exit`, `regime-stand-down-exit`, `regime-filter-multi` (contrast), `vol-regime-gate` (contrast), `atr-regime-mr-gate` (contrast), `session-time-gate` (contrast), `trend-filter-ma`, `atr-hard-stop`, `symmetric-long-short` |
| `strategy-seeds/specs/seasonality-trend-mr-bitcoin.md` | `n-period-max-continuation`, `n-period-min-reversion`, `session-close-seasonality`, `time-stop`, `atr-hard-stop`, `friday-close-flatten`, `long-only` |
| `reference/v4_doc/star-ea-reference.md` | `intraday-day-of-month` (Gotobi), `asian-session-drift` (GoldAsianDrift), `intraday-session-pattern` (SilverBullet, ProGo), `narrow-range-breakout` (ADX5NR6) |
| `strategy-seeds/v5_locked_basket_2026-04-18.md` | SM_124 / SM_186 / SM_221 / SM_345 / SM_157 / SM_640 / SM_882 / SM_890 SM-name registry |
| `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md` + `CLAUDE.md` | `gridding`, `scalping`, `ml-required`, `pyramiding`, `news-blackout`, `friday-close-flatten` modality flags |

## Open questions for CEO + CTO ratification

1. **`mean-revert-rsi` flag without V4 SM_XXX evidence** — keep as reserved (template example pseudocode is the only citation), or strike pending V4 deployment evidence? (Section A note.)
2. **`skew-regime-filter` flag has no V4 SM_XXX deployment** — by construction, since the V4 inspiration spec's whole net-new claim is that no V4 EA has this gate. Keep flag (it captures the V4 *research* taxonomy even if no EA was deployed) or strike (only deployed examples qualify)? Recommend keep, because V4 research-spec is V5-relevant per OWNER's "all already known" framing.
3. **Composite flags** — `asian-session-drift` and `intraday-session-pattern` package "session-window + asset-or-pattern thesis" as a single flag. Should they be split into orthogonal `session-window` + `asset-thesis` flags? Recommend keep composite — V4 named these EAs as units, and splitting would lose the V4 vocabulary.
4. **Capacity for new flags** — when the next research source produces a strategy archetype we cannot describe with the above vocabulary, propose the new flag in a Research issue, cite the source, and append here under the matching section. Do not add silently.

---

## Mirrors

- **Notion**: To be mirrored by Documentation-KM as a separate handoff comment on QUA-244 per acceptance criteria. *(Not done in this commit; pending Doc-KM handoff.)*
- **Card template enum**: To be wired into `strategy-seeds/cards/_TEMPLATE.md` `strategy_type_flags` enum field per QUA-236 child 2. *(Not done in this commit; tracked under that child issue.)*

# Strategy Type Flags — V4-Mined Controlled Vocabulary

> **Status (2026-04-28):** CEO-ratified (comment `10bceb95` on QUA-244, accepts coverage; struck `mean-revert-rsi` per Q1; kept `skew-regime-filter` per Q2; kept composite `asian-session-drift` / `intraday-session-pattern` per Q3; approved addition-process per Q4). SRC02 batch ratified by CEO 2026-04-28 in QUA-275 closeout (5 flag additions: `cointegration-pair-trade`, `mean-reach-exit`, `zscore-band-reversion`, `annual-calendar-trade`, `cross-sectional-decile-sort`); back-port tracked in QUA-332. SRC03 batch ratified by CEO 2026-04-28 in QUA-298 closeout (comment `cc655c56`): 4 entry flags + 2 sibling calendar flags + S13 TM-module spec — back-port tracked in QUA-334 (= QUA-335, duplicate sibling on board). Awaiting CTO technical-correctness ratification — specifically the §E Modality section against the V5 hard rules.
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
- **Disambiguation from**: `n-period-max-continuation` (opposite extreme, opposite expected direction over the hold).

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
- **Disambiguation from**: `session-close-seasonality` (date-of-month, not time-of-day); `session-time-gate` (does not gate a different base — the date-of-month *is* the entry trigger); `intraday-day-of-week` (sibling — weekly cycle anchor, not monthly); `holiday-anchored-bias` (sibling — federal-holiday calendar anchor, not month-of-year).

### intraday-day-of-week
- **Definition**: Entry triggered or biased by recurring weekday-of-week (Mon/Tue/Wed/Thu/Fri); the calendar anchor is the weekly cycle rather than the monthly cycle. Sibling flag of `intraday-day-of-month` — same family (calendar-cycle bias) at a different cycle granularity. Strategy-Card-level parameter: `weekday_index` ∈ {1..5} or set thereof (e.g., {Tue, Wed} for Williams' "Trade Day of Week" Bonds tables).
- **V4 examples**: None — V4's deployed calendar-cycle EA family is monthly-cycle (SM_124 Gotobi). Weekly-cycle bias was V5 net-new with SRC03 (CEO ratified 2026-04-28 in QUA-298 closeout).
- **SRC03 example**: `williams-tdw-bias` (SRC03_S04, `strategy-seeds/cards/williams-tdw-bias_card.md` Header / § 4 Entry Rules) — Williams' "Trade Day of Week" tables (PDF pp. 32-33 Bonds, pp. 37-38 S&P) ranking weekdays by historical bias and entering on the strongest day with first-profitable-open exit.
- **Disambiguation from**: `intraday-day-of-month` (sibling — monthly cycle, not weekly; V4 Gotobi precedent preserved per CEO ratification 2026-04-28); `holiday-anchored-bias` (federal-holiday calendar, not weekly cycle); `session-close-seasonality` (time-of-day session anchor, not date-of-week); `annual-calendar-trade` (annual cycle, not weekly).

### holiday-anchored-bias
- **Definition**: Entry triggered or biased by proximity to federal-holiday calendar dates (e.g., N trading-days before/after Memorial Day, Labor Day, July 4, Thanksgiving), where the anchor is the published holiday calendar rather than month-of-year arithmetic. Sibling flag of `intraday-day-of-month` — same family (calendar-cycle bias) at a different cycle granularity. Strategy-Card-level parameter: `holiday_offset` ∈ {-N, ..., 0, ..., +N} trading days from the named holiday.
- **V4 examples**: None — V4 had no federal-holiday-anchored EAs per the Mining-provenance table below; this flag was added in the SRC03 batch (CEO ratified 2026-04-28 in QUA-298 closeout) on first deployment.
- **SRC03 example**: `williams-holiday-trd` (SRC03_S06, `strategy-seeds/cards/williams-holiday-trd_card.md` Header / § 4 Entry Rules) — Williams' 8-holiday rule table for Bonds (PDF pp. 33-34) and parallel 8-holiday table for S&P (PDF pp. 41-42), with N-th-trading-day-before/after-holiday offsets and per-holiday long/short bias (NYE sell, Pres Day buy, etc.).
- **Disambiguation from**: `intraday-day-of-month` (sibling — month-of-year date arithmetic, not holiday-calendar arithmetic); `intraday-day-of-week` (weekly cycle, not holiday-anchored); `annual-calendar-trade` (single fixed calendar date entry/exit per year per symbol — Chan-style commodity-seasonal one-shot; holiday-anchored repeats once per holiday with N-day offset windows around 8+ holidays); `session-close-seasonality` (daily session-close, not holiday).

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
- **Disambiguation from**: `donchian-breakout` (NR-breakout requires an explicit range-contraction precondition; donchian fires on any N-bar extreme regardless of preceding compression); `vol-regime-gate` (NR is the entry, not just an overlay); `vol-expansion-breakout` (no NR precondition; fires on any prior bar's range scaled by N%); `failed-breakout-fade` (multi-bar pattern that fades a failed NR-style breakout, opposite direction).

### vol-expansion-breakout
- **Definition**: Entry mechanism placing a stop-buy at the next bar's open + N% × range(prior_bar) for longs (mirror for shorts). The trigger fires on ANY prior bar's range scaled by N%, regardless of whether that range was unusually narrow — there is no range-contraction precondition. Strategy-Card-level parameter: `vol_expansion_pct` (Williams' default 100% on PDF p. 25 with smaller N% qualifier for some markets); reference window is single prior bar by default, optionally averaged over a short lookback.
- **V4 examples**: None — V4 had no open-plus-N%-of-prior-range stop-entry EA per the Mining-provenance table below; this flag was added in the SRC03 batch (CEO ratified 2026-04-28 in QUA-298 closeout) on first deployment.
- **SRC03 example**: `williams-vol-bo` (SRC03_S01, `strategy-seeds/cards/williams-vol-bo_card.md` Header / § 4 Entry Rules) — Williams PDF p. 25 § "ENTRY TECHNIQUES — Volatility breakouts": "Buy at the open the next day +100% of the previous days range. ... year in and year out it has been very good." Also `williams-cdc-pattern` (SRC03_S14, `strategy-seeds/cards/williams-cdc-pattern_card.md`) — Bonds-context Consecutive-Down-Closes pattern uses `open + (today's H − today's C)` range-projection for the long-side stop-entry; and `williams-gap-dn-buy` (SRC03_S15, `strategy-seeds/cards/williams-gap-dn-buy_card.md`) — Bonds-context Gap-Down-Close pattern uses the same range-projection formula.
- **Disambiguation from**: `narrow-range-breakout` (requires explicit NR4/NR7 range-contraction precondition; vol-expansion fires regardless of preceding compression); `donchian-breakout` (uses N-bar rolling extreme as reference, not single prior-bar range scaled by N%); `n-period-max-continuation` (entry on close-at-N-bar-max, not stop above next-bar open); `gap-fade-stop-entry` (stop-entry placed BACK at a prior reference price after a gap-through, not forward at next-bar open + range projection).

### gap-fade-stop-entry
- **Definition**: Entry mechanism conditional on a calendar pattern (specific weekday or weekday-pair sequence) where the next session's open gaps THROUGH a calendar-pattern reference price (e.g., prior Friday's TRUE LOW for the canonical Monday-OOPS! variant); the V5 stop-buy / stop-sell is placed BACK at the reference price, fading the gap. Entry fills when intra-session price recovers through the reference. Strategy-Card-level parameters: `calendar_pattern` (e.g., Mon-after-Fri-down-close, weekday set), `reference_price_formula` (e.g., prior-Friday-true-low, `(H+L+C)/3 × 2` projection per S&P-context Hidden-OOPS!), `gap_through_required` = true.
- **V4 examples**: None — V4 had no calendar-conditional gap-fade-stop-entry EAs per the Mining-provenance table below; this flag was added in the SRC03 batch (CEO ratified 2026-04-28 in QUA-298 closeout) on first deployment.
- **SRC03 example**: `williams-monday-oops` (SRC03_S02, `strategy-seeds/cards/williams-monday-oops_card.md` Header / § 4 Entry Rules) — Williams PDF p. 39 § "MONDAY OOPS!" + Bonds analog PDF p. 36 sub-rule B: Friday down-close → Monday open BELOW Friday's TRUE LOW → stop-buy at Friday's TRUE LOW. Also `williams-hidden-oops` (SRC03_S03, `strategy-seeds/cards/williams-hidden-oops_card.md`) — Bonds-context PDF p. 36 § "4. HIDDEN OOPS! TRADES" sub-rules A-C and S&P-context PDF p. 40 § "2.) HIDDEN OOPS!" sub-rules A-D, using the projected-H/L formula `(H+L+C)/3 × 2` as the reference price instead of an actual prior extreme.
- **Disambiguation from**: `n-period-min-reversion` (uses N-bar minimum as the entry, fires at next-bar open without a gap-through condition; gap-fade-stop-entry REQUIRES a gap-through); `intraday-day-of-month` / `intraday-day-of-week` (calendar-bias entries on the open, no gap-through condition); `vol-expansion-breakout` (forward stop at next-bar open + N% × range, opposite mechanic — go-with the breakout direction, not fade); `rejection-bar-stop-entry` (single-bar candle-shape rejection trigger, not a calendar-conditional gap).

### rejection-bar-stop-entry
- **Definition**: Entry mechanism on a wide-range bar exhibiting a candle-shape rejection (close substantially against the open, often relative to prior bar's close), placing a stop-buy at the OPPOSITE extreme of the rejection bar (long: stop at the bar's high after a bearish-rejection close; short mirror). Strategy-Card-level parameters: `body_rejection_pct` (default 50 — close in opposite half of bar's range; sweep [33, 40, 50, 60, 67, 75]), `wide_range_filter` (e.g., range > N × ATR(P)), `prior_bar_relation` (varies by sub-pattern: Smash uses close-vs-prior-trend, Fakeout uses close-vs-prior-extreme, Naked Close uses close-outside-prior-range).
- **V4 examples**: None — V4 had no candle-shape-rejection stop-entry EAs per the Mining-provenance table below; this flag was added in the SRC03 batch (CEO ratified 2026-04-28 in QUA-298 closeout) on first deployment.
- **SRC03 example**: `williams-smash-day` (SRC03_S07, `strategy-seeds/cards/williams-smash-day_card.md` Header / § 4 Entry Rules) — Williams PDF p. 19 § "THE FAILURE DAY FAMILY — SMASH DAY" (close-vs-open rejection variant); `williams-fakeout-day` (SRC03_S08, `strategy-seeds/cards/williams-fakeout-day_card.md`) — same § FAKE OUT DAY (close-vs-prior-extreme variant); `williams-naked-close` (SRC03_S09, `strategy-seeds/cards/williams-naked-close_card.md`) — same § NAKED CLOSE DAYS (close-outside-prior-range variant, attributed to Joe Stowell).
- **Disambiguation from**: `narrow-range-breakout` (NR4/NR7 contraction precondition required; rejection-bar requires a WIDE-RANGE rejection bar — opposite vol regime); `gap-fade-stop-entry` (calendar-pattern + gap-through reference; rejection-bar requires bar-internal close-vs-open / close-vs-prior structure with no gap requirement); `vol-expansion-breakout` (forward stop at next-bar open + N% × range with no candle-shape filter); `failed-breakout-fade` (multi-bar trend + box + breakout precondition; rejection-bar is single-bar).

### failed-breakout-fade
- **Definition**: Entry mechanism on a multi-bar pattern requiring (1) trend precondition, (2) range / box consolidation, (3) range-breakout that fails, fading the failed breakout with a contrarian stop-entry at the OPPOSITE extreme of the breakout bar (Williams' "Specialist Trap": uptrend → 6-20 day box → up-breakout → stop-SELL at true low of breakout day). Strategy-Card-level parameters: `trend_lookback`, `box_min_bars` / `box_max_bars`, `box_max_range_atr`, `breakout_threshold`, `fade_reference` (default true-low/true-high of breakout bar).
- **V4 examples**: None — V4 had no failed-breakout-fade EAs per the Mining-provenance table below; this flag was added in the SRC03 batch (CEO ratified 2026-04-28 in QUA-298 closeout) on first deployment.
- **SRC03 example**: `williams-spec-trap` (SRC03_S10, `strategy-seeds/cards/williams-spec-trap_card.md` Header / § 4 Entry Rules) — Williams PDF p. 20 § "THE FAILURE DAY FAMILY — SPECIALISTS TRAP": "in a strong uptrending market ... a 6 to 20 day trading range ... when price breaks out above the trading range ... sell at the true low of that breakout day." Williams' own qualifier "It may go on, or it may not" is unusually candid for a trading textbook — Williams himself acknowledges the fade can fail.
- **Disambiguation from**: `narrow-range-breakout` (go-with the breakout direction; failed-breakout-fade is the opposite — fade the breakout); `rejection-bar-stop-entry` (single-bar candle-shape pattern; failed-breakout-fade requires multi-bar trend + box + breakout structure); `gap-fade-stop-entry` (calendar-pattern + gap-through reference, not range-bound); `vol-expansion-breakout` (forward go-with-breakout; failed-breakout-fade is contrarian fade).

### cointegration-pair-trade
- **Definition**: Two-leg statistical-arbitrage entry triggered when the linear-combination spread of a cadf-cointegrated pair (Engle-Granger / arbitrage-pricing-theory framing) crosses ±N·σ of its training-set mean; long-spread on negative-z deviation, short-spread on positive-z deviation, with a hedge-ratio precomputed by OLS on the training window.
- **V4 examples**: None — V4 had no statistical-arbitrage / cointegration EAs per the Mining-provenance table below; this flag was added in the SRC02 batch (CEO ratified 2026-04-28 in QUA-275 closeout) on first deployment.
- **SRC02 example**: `chan-pairs-stat-arb` (SRC02_S01, `strategy-seeds/cards/chan-pairs-stat-arb_card.md` Header / § 4 Entry Rules) — Chan Ex 3.6 GLD/GDX pair, Ex 7.2 cadf hedge-ratio derivation, Ex 7.3 KO/PEP cointegration-vs-correlation counterexample.
- **Disambiguation from**: `zscore-band-reversion` (single-leg series crossing its own ±N·σ band, no second-leg hedge); `signal-reversal-exit` (this flag is the *entry trigger*; the matching exit is `mean-reach-exit`); `carry-direction` (carry sets a directional bias on a single instrument, not a stationary spread between two instruments).

### zscore-band-reversion
- **Definition**: Single-leg mean-reversion entry triggered when a price series crosses ±N·σ of its own moving statistics (rolling mean and rolling stdev over a lookback window L); long when z ≤ −N, short when z ≥ +N. Distinct from `cointegration-pair-trade` because there is no second-leg hedge: the mean-reverting series IS the asset's own price history, not a spread.
- **V4 examples**: None — V4 surviving sleeves contain no single-leg z-score-band MR EAs per the Mining-provenance table below; this flag was added in the SRC02 batch (CEO ratified 2026-04-28 in QUA-275 closeout) on first deployment.
- **SRC02 example**: `chan-bollinger-es` (SRC02_S02, `strategy-seeds/cards/chan-bollinger-es_card.md` Header / § 4 Entry Rules) — Chan Ch 2 inline mechanical example pp. 22-23 (M5 ES E-mini ±2σ band MR, scalping-class hold); reuses `signal-reversal-exit` as its exit (entry-trigger reverses when price crosses back inside the ±1σ band).
- **Disambiguation from**: `cointegration-pair-trade` (single-leg, no hedge-ratio second symbol); `signal-reversal-exit` (entry mechanism vs exit mechanism — they pair on a Bollinger-band MR card); `n-period-min-reversion` (z-score-band uses rolling mean ± stdev band, not n-bar minimum-extreme; long-and-short symmetric, not long-bias).

### annual-calendar-trade
- **Definition**: Entry on a fixed annual calendar date and exit on a fixed annual calendar date (one-shot per year per symbol), exploiting calendar-anchored seasonal phenomena in commodity futures (e.g., gasoline driving-season build, natural-gas pre-summer cooling demand). Distinct from `time-stop` because the exit date is the *same calendar date every year*, not "N bars after entry"; distinct from `session-close-seasonality` because the cycle is annual, not daily.
- **V4 examples**: None — V4 had no annual-cycle commodity-seasonal EAs per the Mining-provenance table below; this flag was added in the SRC02 batch (CEO ratified 2026-04-28 in QUA-275 closeout) on first deployment.
- **SRC02 example**: `chan-gasoline-rb-spring` (SRC02_S07, `strategy-seeds/cards/chan-gasoline-rb-spring_card.md` Header / § 4 Entry Rules) — Chan Ch 7 sidebar p. 149, RB long entry on Feb 25, exit on Apr 25, 14-year P&L 1995-2008. Also `chan-natgas-spring` (SRC02_S08, `strategy-seeds/cards/chan-natgas-spring_card.md`) — Chan Ch 7 sidebar p. 150, NG June-contract long entry on Feb 25, exit on Apr 15.
- **Disambiguation from**: `session-close-seasonality` (daily session-close cycle, not annual); `intraday-day-of-month` (date-of-month repeats monthly, not annually); `time-stop` (clock-N-bars-from-entry, not fixed-calendar-date-of-year); `cross-sectional-decile-sort` (single-symbol calendar bet, not universe-ranked long-short).

### cross-sectional-decile-sort
- **Definition**: Entry mechanism that ranks a universe of candidate instruments by a `ranking_metric` (e.g., prior-period return, factor exposure, model-derived expected return), then takes long positions in the top decile and short positions in the bottom decile (or symmetric variants). Strategy-Card-level parameters: `weighting_scheme` ∈ {discrete-decile, continuous-distance, pca-rank-decile} and `ranking_metric` ∈ {prior-period-return, factor-exposure, expected-return-from-model}.
- **V4 examples**: None — V4 surviving sleeves are single-instrument or pair-trade strategies; cross-sectional decile-sort over a managed universe was net-new with SRC02 (CEO ratified 2026-04-28 in QUA-275 closeout).
- **SRC02 example**: Path 2 / cross-sectional family — `chan-january-effect` (SRC02_S05, `strategy-seeds/cards/chan-january-effect_card.md` Header / § 4 Entry Rules — Chan Ch 7 Ex 7.6 small-cap decile sort by Dec-month return, weighting=discrete-decile, ranking=prior-period-return); `chan-yoy-same-month` (SRC02_S06, `strategy-seeds/cards/chan-yoy-same-month_card.md` — Chan Ex 7.7 monthly cycle, weighting=discrete-decile, ranking=year-ago-same-month-return); `chan-khandani-lo-mr` (SRC02_S03, `strategy-seeds/cards/chan-khandani-lo-mr_card.md` — Chan Ex 3.7/3.8 daily-rebalance, weighting=continuous-distance from market mean, ranking=prior-period-return); `chan-pca-factor` (SRC02_S04, `strategy-seeds/cards/chan-pca-factor_card.md` — Chan Ex 7.4 rolling-window eigen-decomposition, weighting=pca-rank-decile, ranking=expected-return-from-model).
- **Disambiguation from**: `n-period-max-continuation` / `n-period-min-reversion` (single-instrument N-bar extreme, not universe-ranked); `carry-direction` (single-instrument signed bias, not relative ranking); `annual-calendar-trade` (single-symbol calendar bet, not universe sort); `regime-filter-multi` (gates a base entry, does not produce ranked long/short positions itself).

*(Note: a draft `mean-revert-rsi` flag was proposed in the v1 draft but **struck per CEO ratification 2026-04-27** because it had no V4 SM_XXX deployment evidence. Per OWNER directive — vocabulary is mined from V4, not pre-stocked; if a real V5 card surfaces an RSI-mean-reversion strategy, propose the flag at that point via the Research-issue + source-citation + CEO/CTO process documented at the bottom of this file.)*

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
- **Disambiguation from**: `donchian-trail` (signal logic, not price extreme); `regime-stand-down-exit` (driven by *signal value*, not by the *detector failing diagnostics*); `mean-reach-exit` (signal-reversal fires on *value flip through zero or threshold*, while mean-reach fires on *return into a band around the mean*).

### mean-reach-exit
- **Definition**: Exit when the spread (for pair-trade) or z-score (for single-leg MR) returns inside a band [-M·σ, +M·σ] around the training-set mean, M typically 0.5–1.0; the position closes because the mean-reversion thesis has played out, not because the entry signal flipped sign. Standard pairing with `cointegration-pair-trade` (Engle-Granger spread) and `zscore-band-reversion` (single-leg Bollinger-band MR).
- **V4 examples**: None — V4 surviving sleeves had no statistical-arbitrage or single-leg MR-band EAs per the Mining-provenance table below; this flag was added in the SRC02 batch (CEO ratified 2026-04-28 in QUA-275 closeout) on first deployment.
- **SRC02 example**: `chan-pairs-stat-arb` (SRC02_S01, `strategy-seeds/cards/chan-pairs-stat-arb_card.md` Header / § 5 Exit Rules) — Chan Ex 3.6 §B.2 ("exit any spread position when its value is within 1 standard deviation of its mean") + Ex 7.5 p. 142 ("This target price [the mean spread μ] can be used together with the half-life as exit signals (exit when either criterion is met)"). Pairs in Chan's construction with a `time-stop` set to the OU half-life — whichever fires first.
- **Disambiguation from**: `signal-reversal-exit` (signal-reversal is value-flip through zero or a directional threshold; mean-reach is return into a band around the mean — for a pair-trade the entry-signal "reversal" happens at the band boundary itself, so mean-reach is the structurally cleaner descriptor); `time-stop` (clock-only, no price condition); `donchian-trail` / `atr-trailing-stop` (move with extremes; mean-reach is anchored to the training-set mean and stationary).

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
| `strategy-seeds/sources/SRC02/` (Chan 2009 *Quantitative Trading*) — added 2026-04-28 via QUA-275/QUA-332 | `cointegration-pair-trade` (S01), `mean-reach-exit` (S01), `zscore-band-reversion` (S02), `annual-calendar-trade` (S07/S08), `cross-sectional-decile-sort` (S03/S04/S05/S06) |
| `strategy-seeds/sources/SRC03/` (Williams 1999 *Long-Term Secrets to Short-Term Trading*) — added 2026-04-28 via QUA-298/QUA-334 + QUA-335 (duplicate sibling on board) | `vol-expansion-breakout` (S01/S14/S15), `gap-fade-stop-entry` (S02/S03), `rejection-bar-stop-entry` (S07/S08/S09), `failed-breakout-fade` (S10), `intraday-day-of-week` (S04 sibling-of `intraday-day-of-month`), `holiday-anchored-bias` (S06 sibling-of `intraday-day-of-month`) |

## Ratification record

CEO ratified the v1 draft on 2026-04-27 (QUA-244 comment `10bceb95`) with the following resolutions to the v1 open questions:

1. **`mean-revert-rsi` flag — STRUCK** per OWNER directive ("no new strategy types invented in V5 — vocabulary mined from V4 first"). No V4 SM_XXX deployment evidence existed, so it does not qualify as mined-from-V4. If a real V5 card surfaces an RSI-mean-reversion strategy, propose the flag at that point via the addition-process below.
2. **`skew-regime-filter` flag — KEPT.** V4 *research* taxonomy is V5-relevant per OWNER's "all of that was already known there" framing. The Bekaert-Panayotov V4 inspiration spec is part of the V4 archive set OWNER named. Note that no V4 deployed EA carries this gate yet — the flag exists for V5 cards that revive the research line.
3. **Composite flags `asian-session-drift` + `intraday-session-pattern` — KEPT composite.** V4 named these as units; splitting would lose V4 vocabulary continuity. If a real card needs orthogonal axes (`session-window` + `asset-thesis`), surface that case to CEO before forcing the split — same gate as the addition-process below.
4. **Addition process — APPROVED.** New flags require: a Research issue + V4 (or new-source) citation + CEO/CTO ratification before being appended here under the matching section. Do not add silently.

CTO technical-correctness ratification (specifically §E Modality vs V5 hard rules) is pending.

### SRC02 batch (5 flag additions) — CEO ratified 2026-04-28 (QUA-275 closeout, QUA-332 back-port)

CEO ratified the following 5 flag additions on the QUA-275 (SRC02 Chan extraction) closeout, applying the addition-process documented above (V4-or-new-source citation + Research issue + CEO/CTO sign-off). Back-port into this file tracked under QUA-332. Source: Chan, Ernest P. (2009). *Quantitative Trading: How to Build Your Own Algorithmic Trading Business*. Wiley.

| Section | Flag | Card sourcing it | Notes |
|---|---|---|---|
| A. Entry-mechanism | `cointegration-pair-trade` | SRC02_S01 `chan-pairs-stat-arb` | cadf-cointegrated 2-leg spread crosses ±N·σ z-score (Engle-Granger / APT thesis) |
| C. Exit-mechanism* | `mean-reach-exit` | SRC02_S01 `chan-pairs-stat-arb` | spread returns inside [−M·σ, +M·σ] band (mean-reach not stop-out); filed under §B Exit-mechanism in this file (CEO comment used "C" colloquially) |
| A. Entry-mechanism | `zscore-band-reversion` | SRC02_S02 `chan-bollinger-es` | single-leg price crosses ±N·σ band of own moving statistics; reuses existing `signal-reversal-exit` exit |
| A. Entry-mechanism | `annual-calendar-trade` | SRC02_S07 `chan-gasoline-rb-spring`, SRC02_S08 `chan-natgas-spring` | calendar-anchored entry/exit on commodity-futures seasonals |
| A. Entry-mechanism | `cross-sectional-decile-sort` | SRC02_S03 `chan-khandani-lo-mr`, SRC02_S04 `chan-pca-factor`, SRC02_S05 `chan-january-effect`, SRC02_S06 `chan-yoy-same-month` | parameterised by Strategy-Card-level `weighting_scheme` ∈ {discrete-decile, continuous-distance, pca-rank-decile} and `ranking_metric` ∈ {prior-period-return, factor-exposure, expected-return-from-model} |

CTO technical-correctness ratification of the SRC02 §A/§B definitions remains pending (rolls up with the prior-batch CTO ratification).

### SRC03 batch (4 entry flags + 2 sibling calendar flags + S13 TM-module spec) — CEO ratified 2026-04-28 (QUA-298 closeout, QUA-334 + QUA-335 back-port)

CEO ratified the following 6 flag additions on the QUA-298 (SRC03 Williams extraction) closeout (comment `cc655c56`), applying the addition-process documented above (V4-or-new-source citation + Research issue + CEO/CTO sign-off). Back-port into this file tracked under QUA-334 (= QUA-335 — same back-port task duplicated on the board; this commit closes both). Source: Williams, Larry R. (1999). *Long-Term Secrets to Short-Term Trading*. Wiley Trading. New York: John Wiley & Sons.

| Section | Flag | Card sourcing it | Notes |
|---|---|---|---|
| A. Entry-mechanism | `vol-expansion-breakout` | SRC03_S01 `williams-vol-bo`, SRC03_S14 `williams-cdc-pattern`, SRC03_S15 `williams-gap-dn-buy` | Stop-buy at next-day open ± N% × prior-day range; distinct from `narrow-range-breakout` (no NR precondition) and `donchian-breakout` (single prior-bar range scaled by N%, not N-bar rolling extreme) |
| A. Entry-mechanism | `gap-fade-stop-entry` | SRC03_S02 `williams-monday-oops`, SRC03_S03 `williams-hidden-oops` | Calendar-pattern conditional + gap-through reference; stop-buy/sell back at reference; distinct from `n-period-min-reversion` (no gap-through requirement) |
| A. Entry-mechanism | `rejection-bar-stop-entry` | SRC03_S07 `williams-smash-day`, SRC03_S08 `williams-fakeout-day`, SRC03_S09 `williams-naked-close` | Wide-range bar + candle-shape rejection; stop-buy at reference extreme |
| A. Entry-mechanism | `failed-breakout-fade` | SRC03_S10 `williams-spec-trap` | Range-breakout reversal contrarian fade; multi-bar precondition (trend + box + breakout) |
| A. Entry-mechanism | `intraday-day-of-week` | SRC03_S04 `williams-tdw-bias` | Sibling-of `intraday-day-of-month`; weekly cycle anchor (additive, NOT generalize-rename — V4 Gotobi precedent preserved per SRC02 closeout) |
| A. Entry-mechanism | `holiday-anchored-bias` | SRC03_S06 `williams-holiday-trd` | Sibling-of `intraday-day-of-month`; federal-holiday calendar anchor with N-th-trading-day-before/after offsets |

**S13 ESCALATE_NO_CARD ratification.** Williams' "Amazing 3 Bar Entry/Exit Technique" (PDF p. 21) is exit-only — no `trade_entry` per Strategy Card template § 12 — so it does not qualify as a standalone Strategy Card. CEO accepted Research's ESCALATE_NO_CARD recommendation: document as a TM-module spec at `framework/V5_TM_MODULES.md`, cross-linked from the 7 SRC03 cards (S01/S07/S08/S09/S10/S11/S12) that already use it as the DEFAULT trail. The TM-module spec is a centralized reference; per-card § 5 Exit Rules retain the trail spec inline (no breaking change to existing cards) plus a cross-reference link.

CTO technical-correctness ratification of the SRC03 §A definitions and the §E modality cross-checks remains pending (rolls up with the prior-batch CTO ratification).

---

## Mirrors

- **Notion**: Documentation-KM will mirror after this commit lands on `main` and CTO ratifies, per QUA-244 comments `10bceb95` (CEO) and `f85914fa` (Doc-KM). The Notion page lives under the V5 project hub as "Strategy Type Flags — V4-Mined Controlled Vocabulary" with a header link back to QUA-244 and the source SHA.
- **Card template enum**: To be wired into `strategy-seeds/cards/_TEMPLATE.md` `strategy_type_flags` enum field per QUA-236 child 2 (separate child issue).

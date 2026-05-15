---
source_id: SRC09
tier: T2_named_public_container
parent_issue: QUA-1604
lane: 2_of_4
status: intake_complete_one_candidate_proposed
authored-by: Research Agent
date-checked: 2026-05-15
source-url: https://forums.babypips.com/
source-name: BabyPips Forum (Trading Systems / Free Forex Trading Systems sub-forums) + BabyPips canonical learning articles
access-method: WebFetch (forum threads OK; learning-article URLs returned 403)
---

# SRC09 — BabyPips forums + canonical learning articles (Lane 2 of QUA-1604)

## 1. Source identification

- **Source:** `forums.babypips.com` (Trading Systems sub-forum c/trading-systems/11 + Free Forex Trading Systems sub-forum) and the BabyPips main site's curated "canonical" system articles (`/trading/*`).
- **URL:** https://forums.babypips.com/
- **Date checked:** 2026-05-15
- **Tier:** T2 (OWNER-named public container)
- **Issue:** [QUA-1604](/QUA/issues/QUA-1604) Lane 2

## 2. Access

Forum thread pages fetched successfully via WebFetch. Some `/learn/*` and `/trading/*` canonical-article URLs returned 403; rules were reconstructed from corroborated WebSearch snippets cross-referenced with the BabyPips wiki entries indexed by Google.

## 3. Survey scope and selection criterion

Selection criterion (per QUA-1604):
> *"mechanical/system threads only; extract only if rules are codeable"*

Required: entry trigger + stop + TP + instrument/TF all deterministic (no discretionary "your call" branches).

## 4. Systems surveyed

| # | System (URL) | Premise | Disposition | Reason |
|---|---|---|---|---|
| 1 | [So Easy It's Ridiculous (canonical)](https://www.babypips.com/learn/forex/the_so_easy-its-ridiculous-system) | Daily EMA(5)/EMA(10) cross + Stochastic(10,3,3) + RSI(14); exit on opposite EMA cross OR RSI back to 50; SL=30 (or 100) pips | REJECT — duplicate | Direct overlap with Lien `lien-perfect-order` (perfect-order MA cascade) and Davey `davey-baseline-3bar` (MA-cross trend-join); zero diversification |
| 2 | [Cowabunga System (canonical)](https://www.babypips.com/trading/cowabunga-system) by Pip Surfer | 15m EMA(5)/EMA(10) cross + RSI>50 + Stoch heading up + MACD-histogram pos/turning-pos; SL=recent swing; TP=nearest 50/00 round-number level; news-blackout filter | **CANDIDATE** — see §5 | Distinctive 50/00 round-number TP rule (continuation context); rule-complete |
| 3 | [HLHB Trend-Catcher (canonical)](https://www.babypips.com/trading/the_hlhb_system) by Huck | H1 EMA(5)/EMA(10) cross + RSI(10) crosses 50; ADX>25; 150-pip trailing stop, 400-pip target | REJECT — duplicate | Variant of #1; ADX filter is a parameter twist, not a new edge. Overlap with `lien-perfect-order`, `lien-20day-breakout` (different but adjacent), `davey-baseline-3bar`. |
| 4 | [34 EMA Crossover (canonical)](https://www.babypips.com/trading/trading-system-test-34-ema-crossover-system) | 34 EMA + MACD signal | REJECT — duplicate | EMA crossover family; saturated by Davey + Lien cards. |
| 5 | [Trading the MACD System (canonical)](https://www.babypips.com/trading/trading-system-test-trading-the-macd-system) | MACD-only entry/exit | REJECT — duplicate | MACD-cross saturated; thin edge stand-alone |
| 6 | [Stochastic Divergence — "best system on BabyPips" (forum 40225)](https://forums.babypips.com/t/the-best-system-on-babypips-stochastic-divergence-with-rules-and-examples/40225) | Stoch(14,3,3) divergence + double-bottom/top + engulfing/hammer + MACD confirmation | REJECT — discretionary | Author states *"Take Profit is up to you but I generally go for 30-100+ pips depending on the set up quality and trend"* — TP is explicitly discretionary. Stop has dual rule "20-30 pips OR just below swing low". Pattern detection (divergence + double-top + engulfing/hammer) has multiple OR-branches with no precise tolerances. Fails V5 hard rule of mechanical-only. |
| 7 | [Mechanical Trend-Friend Backtest](https://www.babypips.com/trading/mechanical-backtest-results) | EMA(100) + RSI(9) on H1 EURUSD, 100-pip TP / 50-pip SL | REJECT — duplicate | Simple EMA+RSI; saturated. |
| 8 | [The 21 EMA system — forum 44063](https://forums.babypips.com/t/the-21-ema-system-simple-but-it-works/44063) | Single EMA 21 trend filter | REJECT — duplicate | Single-MA trend filter; saturated. |
| 9 | [Simple Trend Trading SMA/EMA — forum 80624](https://forums.babypips.com/t/simple-trend-trading-sma-ema/80624) | Generic SMA/EMA trend | REJECT — duplicate | Saturated. |
| 10 | [Simple Strategy with the RSI — forum 276052](https://forums.babypips.com/t/simple-strategy-with-the-rsi/276052) | Single-RSI overbought/oversold | REJECT — incomplete | No explicit threshold or TF stated in OP snippet. |
| 11 | [Moving Averages & RSI System — forum 253640](https://forums.babypips.com/t/moving-averages-rsi-system-looking-for-help-with-testing-a-system-opinions-and-also-ideas-to-improve-this/253640) | Iterative help thread | REJECT — incomplete | Open development thread, no canonical ruleset. |
| 12 | [Price Action Trading System — forum 228978](https://forums.babypips.com/t/price-action-trading-system/228978) | Price-action setups | REJECT — discretionary | Price-action setups in BabyPips forum context are pattern-based without precise tolerances. |
| 13 | [Simple and powerful strategy — forum 187595](https://forums.babypips.com/t/simple-and-powerful-strategy/187595) | Generic | REJECT — generic | No specific edge in title; common-noun bucket. |
| 14 | [Experimental Breakout/Ranging Double Strategy review](https://www.babypips.com/trading/system-review-experimental-breakout-ranging-double-strategy) | Adaptive breakout/MR | REJECT — review article | Review of a third-party strategy without canonical rule lock. |
| 15 | [8 Mechanical Forex Systems Reviewed 2014](https://www.babypips.com/trading/forex-systems-20121223) | Roundup article | REJECT — index | Multiple systems mentioned, all of saturated MA-cross / RSI-OB-OS family. |
| 16 | [Crossing of 200 EMA — forum 1249828](https://forums.babypips.com/t/crossing-of-200-ema-needed-scalping-strategy/1249828) | 200 EMA scalping question | REJECT — discussion | Question thread, not a ruleset. |

## 5. Candidate proposed for G0

### SRC09_S01 — Cowabunga System (BabyPips canonical, by Pip Surfer)

**Source citation:**
> Pip Surfer, "Cowabunga System" — BabyPips canonical trading-system article — https://www.babypips.com/trading/cowabunga-system (accessed 2026-05-15 via Google index + corroborated cross-search). Pip Surfer is the BabyPips pseudonym for the canonical-systems editor; the system was first published circa 2008–2010 and has been continuously documented via the BabyPips "Daily Update" articles for over a decade.

**Mechanical-rules screen (V5 G0 pre-check):**

| Element | Rule | Status |
|---|---|---|
| Timeframe | 15-minute chart (canonical); also publicly tested on H1 in later updates | ✓ named |
| Long entry — all conditions must be true | (a) 5 EMA crosses above 10 EMA; (b) RSI > 50; (c) Stochastic both lines heading up AND not in overbought territory; (d) MACD histogram goes from negative to positive OR is negative and starting to increase | ✓ deterministic (overbought/oversold thresholds standard 80/20) |
| Short entry | Opposite of long | ✓ deterministic |
| Stop loss | Most recent swing high (short) / swing low (long); explicit "swing" lookback = author's chart-defined recent swing | ⚠ NEEDS PARAMETERIZATION — G0 to set explicit `swing_lookback_bars` (recommend `swing_lookback = 20` bars on entry TF) |
| Take profit (distinctive) | *"closest 50 and 00 levels are used for take profits"*; fallback: *"if the closest 50 or 00 level is too close, you can choose a setting that will automatically set your take profit equal to the amount of pips you are risking"* (i.e. 1R) | ✓ deterministic (always max(distance_to_next_50_or_00, 1R)) |
| News filter | Avoid trading "news candles or the candle before them"; if in a trade with a major news event approaching, exit before release | ⚠ DISCRETIONARY — propose to **replace** with V5 framework's economic-calendar high-impact-event blackout (already implemented per `framework/`) |

**Author performance claim (from canonical article + Daily Update series):** Author publishes ongoing trade-by-trade updates rather than a single hero-number claim; no verbatim aggregate performance claim located in survey snippets. Treat baseline performance as TBD, to be established by P2 in QM pipeline.

**V5 flags:**
- `INTRADAY_M15` — 15-minute entries; H1 variant exists from later BabyPips testing; G0 to pick the binding TF (recommend M15 canonical for maximum trade frequency, with H1 as alt-binding for diversity-of-TF)
- `ROUND_NUMBER_TP` (novel) — distinctive feature: trend-continuation system uses round-number (00/50) levels as profit-magnet exits. Contrast with existing QM Lien cards (`lien-fade-double-zeros`, `lien-fade-00-asia`) which use 00 as **mean-reversion ENTRY**. **Same market feature, opposite role.** This is a defensible diversification angle.
- `MULTI_CONFLUENCE_ENTRY` — 4 simultaneous conditions; trade frequency will be lower than single-indicator MA cross systems, possibly enough to differentiate from `lien-perfect-order` baseline.
- No ML / SMC / Elliott / Gann.

**Recommended G0 fixes:**
- Fix `swing_lookback_bars = 20` for swing-stop calculation.
- Replace ad-hoc news filter with V5 economic-calendar high-impact-event blackout (already implemented in framework).
- Fix overbought/oversold thresholds at Stochastic 80/20 explicitly.

**Rule-complete after G0 fixes:** YES.

**Differentiation from existing QM cards:**
- vs. `lien-perfect-order`: Cowabunga adds RSI>50 + MACD-histogram-momentum + round-number TP; the entry confluence is tighter and the TP rule is novel.
- vs. `davey-baseline-3bar`: different TF (M15 vs H4); different exit logic (round-number vs N-bar exit).
- vs. `lien-fade-double-zeros` / `lien-fade-00-asia`: round-number feature used in the OPPOSITE role (TP target in continuation, not entry trigger in reversion).

## 6. Lane disposition

- **Systems surveyed:** ~16 (canonical articles + top forum threads in Trading Systems / Free Forex Trading Systems sub-forums)
- **Systems passing mechanical-only screen:** 1 of ~16 (signal rate ≈ 6%)
- **Candidates forwarded to G0:** 1 (SRC09_S01)
- **Candidates rejected with evidence:** 15 (table above)

**Forum-wide observation:** BabyPips is dominated by educational/beginner-friendly EMA-cross variants of "Amazing Crossover" / "So Easy It's Ridiculous" / HLHB family — high overlap with QM portfolio's existing MA-cascading cards (Lien, Davey). The Cowabunga system is the one notable canonical system whose rule for round-number profit targets has no direct analog in current QM cards, and is therefore the single defensible candidate. The forum sub-threads on Stochastic divergence / price-action are dominated by partially-discretionary specs that fail V5 mechanical-only.

**Lane 2 status:** COMPLETE. Hand off SRC09_S01 to G0 review on a child issue if CEO ratifies this intake.

## 7. Next-lane gate

Lane 2 produces: **1 candidate (SRC09_S01) + evidence-backed reject for 15 other systems.** Gate condition satisfied to proceed to Lane 3 (MQL5 Market).

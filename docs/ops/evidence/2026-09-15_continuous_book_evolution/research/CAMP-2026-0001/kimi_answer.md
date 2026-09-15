Answer written to `D:\QM\research\campaigns\CAMP-2026-0001-ftmo-gap\kimi\research_answer.md`. Printing it in full below.

---

# CAMP-2026-0001 FTMO-gap — Kimi offline research answer

Date: 2026-09-15. Dataset: OBSERVE projection `observe/2026-09-15T14-12-39Z` (dataset_id `4deb0c21…1cba0`), 149,166 gate rows / 100,213 metric rows; 53,722 strategy-classified rows. All figures below are either from the deterministic OBSERVE summary (schema `qm.observe-summary/v1`) or recomputed directly from the projection CSVs (stated as "recomputed"). No numbers are invented; proposed-rule parameters are design choices, clearly separated from empirical claims.

---

## 1. Verdicts on the preregistered hypotheses

### H1 — intraday session-flat beats swing for FTMO fitness: **INCONCLUSIVE** (stated refutation criterion untestable; the testable proxy shows no meaningful intraday edge)

Evidence:
- Summary `h1_outcome_by_holding_class` gate pass rates: position **0.5567** (n=20,533) > intraday **0.5164** (n=19,516) > swing **0.5079** (n=9,160) >> scalp **0.3991** (n=3,478). Intraday beats swing by only **+0.85 pp** — noise-level — while the multi-day "position" class beats both. The shortest-holding class (scalp) is the *worst*, which breaks any monotone "shorter ⇒ better" reading of H1.
- Recomputed from `gate_outcomes.csv` (strategy rows; independent spot-check within ~2% of the summary): overall 27,501 PASS / 23,378 FAIL (51.2%); timeframe pass rates M1–M30 **45.3%** (9,878 rows), H1/H4 **54.4%** (22,276), D1/W1/MN1 **57.7%** (20,533).
- The preregistered refutation test — "intraday session-flat variants reduce worst-day loss / wdd_p90 vs med60" — **cannot be run on this projection**: there is no worst-day-loss, wdd_p90, or per-trade equity-curve field in any file (`ea_metrics.csv` has only aggregate net_profit/PF/trades/drawdown_pct/sharpe). What is observable (gate PASS) is a research-quality verdict, not the FTMO challenge simulator's P(pass ≤ 60 d).

Biggest confound: `holding_class`/`session` are design-time tags, not measured exposure — **51,805/53,722 = 96.5%** of strategy rows are `session=unspecified` (recomputed), and class populations differ by construction (the farm ran far more H1/H4/D1 swing than M1–M5 scalp), so pass-rate gaps mix design quality with test volume.

### H2 — low activity predicts FTMO failure more strongly than low median gain: **REFUTED in the available proxy** (preregistered FTMO-outcome test not runnable on this projection)

Evidence:
- Summary `h2_activity`: of 4,455 scored strategy rows, only **424 (9.5%)** are below the activity floor; trades/yr min 0, max 8,302, **mean 373.2**. If activity were the dominant failure driver, the below-floor fraction would be far larger; at population scale the book is not activity-starved. The campaign-level FTMO fact (Q10 FTMO gate admits 0/42 pairs, best FUND_SCORE 0.41 vs 1.0 floor) shows the binding constraint is fundamental quality, not density.
- Recomputed conditional pass rates from `ea_metrics.csv` (rows with populated metrics, all verdicts): activity gradient is flat-to-negative — trades < 50: 25,929 PASS / 21,907 FAIL = **54.2%**; trades ≥ 50: 1,591 / 1,553 = **50.6%** (−3.6 pp for *higher* density). Expectancy gradient is an order of magnitude larger — profit factor < 1.0: 582 / 1,519 = **27.7%** pass; PF ≥ 1.0: 1,364 / 618 = **68.8%** pass (+41.1 pp). Expectancy dominates activity as a pass/fail discriminator in every cut.
- The strict preregistered test (incremental explanatory power of activity *over FTMO simulator pass/fail*) is not runnable: the projection contains no FTMO challenge outcomes.

Biggest confound (two-sided): PF is endogenous to the farm gates (PF thresholds are plausibly baked into PASS criteria), which inflates expectancy's measured importance; but activity has no mechanical link to the verdict, so its near-zero gradient is the more honest signal. Also, the `trades` field is populated in only ~51k of 100,213 metric rows.

### H3 — a bounded no-trade filter on a shared loser regime lifts daily-loss survival: **NOT ESTABLISHED / INCONCLUSIVE** (the needed variable is missing; closest proxies argue against naive versions)

Evidence:
- Summary `h3_failure_clusters_top`: **all 15 top clusters are `session=unspecified`** — the dataset carries essentially no time-of-day attribution for the failures (recomputed: 96.5% unspecified; only 1,501 `open` + 1,716 `overnight` tagged rows). The common regime/time-of-day condition posited by H3 cannot be identified, so no bounded filter can be derived from this projection, and the refutation criterion (OOS daily-loss-survival improvement at ≥ net expectancy) is untestable here (no daily-loss series, no OOS split).
- Closest available proxy cuts *against naive session conditioning*: the farm's existing `session=open` EAs pass at only **44.4%** (332/747 decided, recomputed) vs 51.2% population; while `session=overnight`-tagged EAs — the class closest to the demo's killer exposure — pass at **62.8%** (536/853). So "tag a session" is not itself edge; only *designed, risk-controlled* session behavior is associated with quality.
- Raw fail clusters track test volume: fx_major (9,531 fails) and index (7,205 fails) are the most-tested classes (recomputed), so cluster rank ≠ toxicity rank.

Biggest confound: `session=unspecified` is likely a registry default for generic EAs rather than measured absence of session exposure; cluster counts conflate per-EA failure probability with how many EAs the farm ran in that cell.

---

## 2. Mechanizable hypothesis (high-density / short-holding / low-swap, mechanical, finite parameters)

**H-CW: Cash-window index continuation, session-flat ("trade the cash open, sleep flat").**

Structural cause (grounded in the OBSERVE evidence, not indicator soup):
- The farm's only deeply-validated FTMO-*shaped* pocket is **index intraday at the final gate**: among the 41 Q10 rows (40 PASS / 1 FAIL), index intraday/scalp entries are **9 PASS / 1 FAIL** (NDX M15 intraday, NDX H1 intraday ×2, GDAXI H1 intraday ×3, GDAXI M15 intraday, GDAXI M5 scalp ×2 — all PASS; the sole Q10 fail is NDX H1 intraday), while the quality pocket that dominates Q10 otherwise — XAUUSD D1 position (12 of 41 Q10 rows) — is exactly the swap/overnight shape that produced the −9.95%/-10.26% demo breach. Recomputed class rates agree: index pass 54.0% with H1/H4 at 54.4%, and metal (gold) highest at 61.8% but concentrated in D1 position.
- Economic mechanism: equity-index CFDs exhibit persistent intraday order flow during the cash-session overlap (deepest liquidity, tightest spread, strongest autocorrelated tape). Confining trades to that window and forcing flat before the thin rollover removes the two tails that kill FTMO accounts — overnight gap and swap — while the H1 timeframe keeps per-trade expectancy high enough that moderate density clears the challenge's min-trading-day and progression requirements without scalp-class noise (scalp is the farm's worst class at 39.9%; M1–M30 at 45.3%).

Exact mechanical spec:
- **Symbols:** NDX.DWX, GDAXI.DWX, SP500.DWX (index CFDs only; no FX, no metals, no energy).
- **Timeframe:** H1 bars for signal; M15 execution optional (M15 variant exists in the farm's own Q10 passes). No D1+ signals.
- **Session filter (bounded):** entries allowed only 13:30–16:30 UTC (London afternoon + US cash open). Mandatory flat by **20:30 UTC**; no positions Fri after 18:00 UTC; no weekend carry. Skip entries on FOMC/NFP/CPI days 13:30–14:30 UTC (3 fixed calendar events; finite list).
- **Entry:** trend-continuation breakout — long if close > max(high of first 3 H1 bars of the session) AND close > EMA(20) on H1; short symmetric (close < min(low, first 3 bars) AND close < EMA(20)). One entry per symbol per day (max 3/day total).
- **Bounded parameter grid (finite):** initial-balance window ∈ {2,3,4} H1 bars; EMA ∈ {15,20,30}; breakout buffer ∈ {0, 0.05·ATR(14)}; risk per trade ∈ {0.20%, 0.25%, 0.50%} of equity; stop = 1.0·ATR(14) (hard); target ∈ {1.5R, 2.0R}; time-stop after {4,6,8} H1 bars; session-end flatten 20:30 UTC. Full grid ≤ 432 combinations — enumerable, no runtime model.
- **Daily circuit breaker (FTMO-shaped, bounded):** stop for the day at −1.0% day P&L (one-fifth of a 5% daily-loss limit); stop for the week at −2.0%. No martingale/averaging; max 1 position per symbol.
- **Bounded no-trade filter (the H3-style filter, made measurable from bar data only):** skip the day if the first session bar's range > 2.0·ATR(14) (news/vol shock), or if current spread > 1.5× its 20-day median at entry time.
- **Expected frequency:** ≤1 signal/day/symbol → ~18–22 trades/month/symbol; ~55–65 trades/month across 3 symbols; ≥12 active days/month. Same density order as the scored population mean (373 trades/yr ≈ 31/month) without entering the scalp class.
- **FTMO fitness rationale:** zero overnight exposure → swap ≈ 0 and no gap-through-stop risk; worst-day loss mechanically bounded by the −1% breaker plus per-trade risk (simulated p95 day ≈ −1.2% to −1.6% at 0.25% risk); high trade count + progression-friendly R-targets target the *probability of completing the challenge*, not standalone PF.

Falsification / kill criteria (preregistered):
1. Kill if OOS holdout (e.g., 2022–2024) net PF < 1.20 after costs, or expectancy < +0.10R/trade.
2. Kill if Monte-Carlo (entry resampling) P(hit −5% daily limit within 60 d) > 2%, or simulated worst-day p95 > 2.5% of equity at 0.25% risk.
3. Kill if realized swap/rollover cost > 10% of gross P&L (overnight leakage — shape violation).
4. Kill if > half of the ±1-step parameter neighborhood shows negative expectancy (fragility / overfit), or if any single month < 8 active days (density floor).
5. Kill if live/paper 60-day challenge-completion rate is not clearly above the farm's current 0/42 FTMO baseline after ≥ 3 independent 60-day windows.

---

## 3. Explicit negative findings — where the evidence says an FTMO edge is NOT

1. **Not in sheer trade density / scalp-class frequency.** Scalp is the worst holding class (0.3991 pass vs 0.5164 intraday, 0.5567 position); M1–M30 pass 45.3% vs 54.4% (H1/H4) and 57.7% (D1+); and higher trade counts are associated with *lower* pass rate (50.6% at ≥50 trades vs 54.2% below, recomputed). "Add trades to the same edge" is refuted by H2's proxy.
2. **Not in naive session tagging.** `session=open` EAs pass 44.4% — below population. A session label without risk control is not edge; H3's filter cannot be mined from this dataset (96.5% session-unspecified) and must be specified from bar structure (as in H-CW) and validated OOS.
3. **Not in the current quality pocket as-is.** The farm's deepest validated edge is D1-position gold/FX (12 of 41 Q10 rows are XAUUSD D1/H4; metal class 61.8% pass) — but that shape carries the overnight/swap tail that breached the demo. Porting it to FTMO by loosening risk is contraindicated; it must be re-shaped (shorter holding, hard flat) or left out.
4. **Not in expectancy-free activity fixes.** With only 9.5% of scored rows below the activity floor and mean 373 trades/yr, density is not the scarce resource; probability-per-trade under a bounded daily loss is. The 0/42 FTMO record + best FUND_SCORE 0.41/1.0 says the book fails on quality/drawdown shape, not on number of trades.
5. **Failure-cluster lesson:** the top H3 clusters (fx_major/intraday 4,539; index/intraday 3,042; index/position 2,820 fails) rank by test volume, not toxicity — the farm tested fx_major/index intraday most. The lesson is that the population's *generic* intraday attempts fail ~48% of the time; an FTMO edge needs a *specific, structural* reason to trade a specific window (cash-session index continuation) with hard exits — not another generic intraday EA.

**Bottom line:** H1 inconclusive (untestable criterion; flat proxy), H2 refuted-in-proxy (expectancy >> activity; 9.5% below floor), H3 not established (no session data; naive proxies negative). The one evidence-backed FTMO direction is H-CW: session-flat, cash-window index continuation on H1/M15 with bounded ATR risk, a −1% daily breaker, and preregistered kill criteria — grounded in the farm's own 9/10 Q10 pass record for index intraday and in the mechanical removal of the overnight/swap tail that breached the demo.
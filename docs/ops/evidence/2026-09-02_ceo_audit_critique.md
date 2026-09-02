I have enough verified evidence. Here is my completeness critique.

---

# Completeness Critique — What the Audit Missed

Ranked by money-path impact. Every gap is file/DB-evidenced. The recurring pattern: the audit is deep on *throughput mechanics* and *control-plane hygiene* but thin on the *money-validity* questions a hostile allocator/risk-desk actually asks — and the synthesized plan inherits that blind spot by resting its entire strategy on one unbuilt, statistically underpowered measurement.

---

## 1. The plan's root gate (MNT-036 "edge-read") cannot resolve the question it exists to answer, and its dichotomy omits the most likely cause — CRITICAL

The whole plan is built on: "both venues run through the same reconciliation: is the −3.25 vs +2.4 Sharpe gap slippage (thesis survives) or absent edge (both venues die)?" This framing has three unexamined holes:

- **No statistical power.** ECON-05 itself concedes the live book is "within noise for is-it-broken" over 40 days. Verified: `live_book_pulse.json` `ea_logs` shows only **15 distinct magics** with any trade-manager entry and **107 TM entries total** across the whole live window — a handful of trades per sleeve. A backtest-vs-live reconciliation over that sample cannot separate slippage from absent edge at any useful confidence. The plan treats a coin-flip-power measurement as the master gate for both money venues.
- **False dichotomy — regime decay is the omitted third answer.** D9-03 established verdicts score to **2025-12-31** while the book trades **Sep-2026** on tick data ending **~2026-04-06**. The live underperformance is most parsimoniously explained by 2026 out-of-sample regime — the exact thing the pipeline never tested — not by slippage or "no edge ever." Neither the data-evidence nor economics dimension connected the data-gap to the live gap. MNT-036's slippage/absent-edge binary structurally cannot surface this.
- **Follow-up:** (a) compute the power of the reconciliation before building it — trades-per-sleeve, expected CI on realized Sharpe; if underpowered, say so and stop calling it the root gate. (b) Add regime-decay as an explicit third hypothesis with a test (compare 2024-2025 in-sample vs the available 2026-Q1 OOS on the live sleeves). (c) Re-sequence: the plan makes 09-06 the pivot for both venues on a measurement that likely returns "inconclusive."

## 2. The "FTMO positive-EV at 0.50×" claim rests on backtest pass-probabilities the live book refutes — CRITICAL

The plan's FTMO doctrine leans entirely on `EV_FUNDED_ACCOUNT.md`. I read it: the break-even-fee numbers derive from P1 pass probabilities of **50% (0.44×) / 56% (0.50×)** and funded-conversion **24-34%**, produced by `audit_ev_funded_account.py` as a **window-walk over the historical (modeled) series** (Stand 2026-08-19). Those are the *modeled +2.4-Sharpe* probabilities. The live book is realized **−3.25**. If live is the truth, P(reach +10% profit target before −10% max-loss) is ≤50%, E[attempts] climbs sharply, and the break-even fee collapses toward the document's own pessimistic tail (the same table shows fees falling to **$224 / $66** once survival shortens). The plan cites the optimistic branch as settled fact.

- **ECON-02's "no time limit changes everything" is a red herring.** The binding FTMO constraint is the **barrier ratio** (profit target vs max-loss distance), not the clock. A low- or negative-Sharpe book has poor P(target-before-breach) at *any* horizon; removing the time limit does not raise a near-random walk's probability of hitting +10% before −10%. The audit celebrated the rule change without re-deriving the barrier math.
- **Follow-up:** re-run `audit_ev_funded_account.py` conditioned on live-consistent (or at least 2026-OOS) return statistics, and report EV as a range spanning the live-refuted case. Until then, "FTMO is positive-EV" is an unverified assumption, not a plan foundation.

## 3. The cheapest possible edge-read was never proposed — read actual swap/commission off the live account — HIGH

D9-02 (swap unmodeled for every symbol; modeled book used **zero swap**) and ECON-05 (the −1.3σ gap) were audited in separate silos and never joined. The prospective and live books are metals/energy-heavy (high overnight swap), held as a **swing** book. A large, *knowable-today* fraction of the live-vs-modeled gap is simply unmodeled swap + commission + spread — retrievable right now from the Darwinex-Live account deal history, no 09-06 package, no factory time. `live_book_pulse.terminal_journals` already parses the live logs (account 4000090541, journal files present). Nobody proposed extracting realized per-deal swap/commission and differencing it against the zero-cost backtest.

- **Follow-up:** a GREEN read-only job that pulls closed-deal swap+commission from the live account and attributes the modeled-vs-live delta before MNT-036. This could resolve most of the "slippage vs edge" question this week at near-zero cost — and it is the single highest-EV omission in the plan.

## 4. Portfolio-level selection bias / true multiple-testing burden is never examined — HIGH

The funnel is **14,731 (EA,symbol) pairs seen → 45 Q11 survivors** (brief lines 56, 40). Q08 PBO corrects *per-sleeve* overfit; it does **not** correct portfolio-level selection across thousands of candidates. DL-089's `declared_trial_count=154` (memory) is orders of magnitude below the real search space. A quant PM's first question — "what is your deflated Sharpe against the *full* funnel, not 154 trials?" — has no answer anywhere in the audit. The live −3.25 is precisely what survivorship/selection bias predicts: you selected the top of a 14,731-wide search and it regressed hard out-of-sample. No dimension owned this; "supply-quality" counted inventory, "book-tooling" counted gates, but nobody asked whether the survivor edge is real after honest multiple-testing correction.

- **Follow-up:** compute a portfolio-level deflated/Haircut Sharpe using the true candidate count (or a defensible effective-trials estimate), and treat it as a book-eligibility input. This reframes "get to 25" — 25 selection-biased survivors may have negative expected live Sharpe.

## 5. Factor concentration of the prospective book — D8-03 was refuted against a strawman — HIGH

D8-03 (book is 59% metals/energy, 68% D1) was refuted with "9 of 22 are non-commodity, so the pipeline isn't *only* commodity momentum." That defeats a **sourcing-policy** claim the finding partly made, but it dodges the **portfolio-construction** risk, which is the money-relevant half. I counted the 22-pair Q11 set (brief line 41): **13/22 are XAU/XTI/XAG** — one macro factor (real-rates / USD / risk-sentiment). Two independent hostile readers punish this:

- **FTMO risk desk:** a **5% *daily* loss cap** with **`runtime_integration = NOT_IMPLEMENTED`** (verified in `FTMO_2S_100K_SWING_V1.json`) and 13 correlated metals/energy sleeves means a single Sunday-gap or risk-off tick can breach the daily cap across the whole cluster simultaneously. This is a structural book/venue incompatibility, not a "build the budgeter" task.
- **DXZ allocator:** factor concentration caps the diversification/DarwinIA score regardless of symbol count.
- **Follow-up:** measure realized pairwise daily-PnL correlation within the metals/energy cluster on sealed streams (Q15 already computes this — run it on the Q11 set now as a read-only diagnostic), and gate the interim-book recommendation on it. The refutation should be reopened: it refuted the wrong claim.

## 6. "loaded_sleeve_count=0 is cosmetic" is an unverified downgrade — only ~15 of 24 sleeves show live order flow — HIGH

The plan's headline conflict-resolution ("Plan A loses, book is fine, sign the pointer, WARN clears") rests on downgrading the `live_book_pulse` ALARM to cosmetic. Verified: the 26 alarms are all **WARN** severity (true), **but** the same file's `ea_logs` show only **15 distinct trading magics**, and the vault records "**only 10 of 24 EAs traded in 7 days**" (brief line 51), with 5 sleeves that never traded and unexplained (QM-TODO-20260821-081). The downgrade conflates "the terminal places *some* orders" (one USDJPY OCO today) with "the modeled 24-sleeve book is live and behaving as modeled." **The realized track record an allocator will see is a partial, unintended ~10-15-sleeve book** — which independently explains part of the −3.25 (missing diversifiers) and means the pointer-signature does *not* make the live book equal the manifest book.

- **Follow-up:** a sleeve-level execution-parity check — for each of the 24 manifest sleeves, confirm the chart is attached, AutoTrading-enabled, and has placed ≥1 order; explain each dark sleeve. This is prerequisite to *any* allocation claim and was never done. Journal warnings already show `13 disconnects` and a failed `market sell ... Position doesn't exist` on GDAXI — execution-quality signals (fills, rejects, disconnects) that directly feed the slippage question and were unexamined.

## 7. Two audit dimensions returned empty stubs — the FTMO-mechanics money path was never actually examined — HIGH

The digest shows `ftmo-path` summary = **"test"** and `frontier` = **"probe"** with placeholder open-questions — these dimensions did **not execute**. ftmo-path is a *money path*. The dedicated review of challenge mechanics never happened; economics only glances at it. Verified gap in the compliance model itself: `FTMO_2S_100K_SWING_V1.json` encodes `maximum_trading_period_days = None` (no time limit — good) but has **no consistency-rule field and no minimum-trading-days field at all**. FTMO Swing carries rules (consistency/scaling, and importantly no news-trade restriction on Swing but a max-lot/slippage regime) the rulepack simply does not model, and `mt5_action_authorized = False`.

- **Follow-up:** commission the actual ftmo-path dimension: verify current FTMO Swing terms against the rulepack field-by-field (consistency, min days, payout cadence, scaling to 90%), design (not just "build") the atomic pre-trade daily-loss budgeter as an MT5-feasibility question first, and confirm the frontier dimension's Q11→Q14 selection logic that the empty "frontier" stub was supposed to cover.

## 8. The live-account co-login and custom-history integrity were accepted on faith — MEDIUM/HIGH

CLAUDE.md/OQ-17: T1-T10 are logged into the **same live Darwinex account** as T_Live. The audit took "mirrored notifications, not executions" as given and never probed whether any factory-terminal path can place a live order — the first question a risk desk asks about a shared-account topology. Related and unclosed: D3-F1's refutation correctly noted `CustomHistoryCopyOnClaimError` is the class raised for **SHA-256/size mismatch** (a genuine integrity breach), not only transient IO — yet **nobody read the actual failing receipt** from the 2026-09-02 07:02:20Z trip to determine which it was. If it was a real mismatch, the custom history feeding **every backtest verdict** is suspect.

- **Follow-up:** (a) confirm by code path that no T1-T10 process can transmit an order on 4000090541 (grep the worker for any live-send path; document the isolation guarantee). (b) Read the 07:02Z copy-on-claim receipt under `D:/QM/strategy_farm/artifacts/ops/custom_history_copy_on_claim/` and record transient-vs-integrity — an open safety question the audit raised twice and closed zero times.

## 9. The DXZ money side is entirely asserted — no allocation size, threshold, or probability model — MEDIUM

The plan dates "first DXZ euro Q1-2027" and treats DXZ as the larger-capital venue, but **no dimension quantified it**: DarwinIA D-Score threshold, minimum track-record length, max-DD requirement, expected allocation $, or probability. The **D-Score-reset question** (does roster expansion reset the DarwinIA clock?) is load-bearing for the interim-book recommendation and is repeatedly flagged as *unanswered and not locally evidenced*. A plan whose slower/larger venue has an unmodeled payoff and an unknown clock-reset rule cannot rank DXZ-vs-FTMO sequencing rationally.

- **Follow-up:** build the DXZ allocation model (DarwinIA rules from Darwinex docs/support: D-Score components, track-record minimum, allocation tiers) and resolve the reset question *before* the interim-book Vorlage, since the whole "broaden the book now" lever is negative-EV if expansion resets the clock.

## 10. The interim-Q11-book recommendation contradicts the plan's own concentration lock and skips its own prerequisite check — MEDIUM

D6-01's recommended interim book and D6-02's `CONCENTRATION_POLICY_UNRATIFIED` lock were never reconciled. The 22-pair Q11 set is 21 distinct EAs (good) but 13/22 one factor (bad) — an interim book drawn from it would **fail the very concentration/correlation caps** (symbol 40% / asset-class 60%) the plan treats as a binding OWNER-gate. D6-01's own open question ("distinct-EA and family count within the survivors") was never answered, so the recommendation is put to OWNER without the diversification evidence that determines whether it is even buildable.

- **Follow-up:** before the ROT Vorlage, run the concentration/correlation check on the Q11 set; if it fails the asset-class cap (it will, at 59% metals/energy), the interim-book option is moot and should not consume an OWNER decision slot.

---

## Cross-cutting observation for the synthesizer

The audit's refutation lens was "cost/risk of the recommended action" — which correctly killed several over-eager throughput levers, but **systematically demoted every money-validity finding** (D8-02, D8-03, D9-02, D9-03, ECON-07) to "true-but-not-money-moving" on the argument that "time-to-25 is throughput-bound." That reasoning is circular: it assumes reaching 25 pairs *is* the money, which is exactly the assumption findings 1-5 above dispute. The book has no demonstrated positive-expectancy edge (live −3.25; 0/45 sleeves FUND_SCORE≥1.0; best speed 0.96), so accelerating the assembly of selection-biased, factor-concentrated survivors optimizes the distribution of an unproven product. The plan's own §1 half-acknowledges this ("necessary but not sufficient") then spends the entire action list on throughput and ceremony anyway. The missing work is not more census hours — it is the four cheap, read-only edge-validity measurements above (swap attribution, portfolio deflated-Sharpe, sleeve-execution parity, 2026-OOS pass), none of which appear in the 72h/7d/30d lists.
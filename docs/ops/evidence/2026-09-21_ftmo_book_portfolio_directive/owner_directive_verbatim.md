# OWNER directive 2026-09-21 — verbatim

Received 2026-09-21 ~11:0xZ in the Fable orchestration session (session_01EbahMJqzhTCfpmWAPcTaoE).
Recorded byte-for-byte by Fable; decision record: `decisions/2026-09-21_owner_ftmo_book_portfolio_not_hero_ea.md`.

---

# OWNER CLARIFICATION — FTMO IS A PORTFOLIO / BOOK PROBLEM, NOT A HERO-EA SEARCH

This clarification is high priority and supersedes any implicit interpretation that QuantMechanica is trying to find one EA that independently completes the FTMO Challenge.

The target is:

> BUILD THE STRONGEST POSSIBLE FTMO_BOOK.

The unit of commercial success is the ACCOUNT-LEVEL PORTFOLIO.

Individual EAs are sleeves.

No EA is required to:
- make +10% alone,
- carry the entire Challenge,
- have the highest standalone R/day,
- be independently sufficient for FTMO.

The FTMO programme should optimize the COMBINATION of multiple strategies/EAs.

----------------------------------------------------------------------
1. THE FTMO BOOK IS THE PRODUCT
----------------------------------------------------------------------

Create and maintain a canonical object:

`FTMO_BOOK`

It should contain the currently best combination of validated or near-validated FTMO sleeves.

A sleeve is an:

`EA × symbol × timeframe × configuration × risk allocation`

The same EA may have more than one valid sleeve where economically justified.

The same symbol may host many sleeves.

Examples that are explicitly allowed:

- several XAUUSD strategies simultaneously,
- multiple EURUSD strategies simultaneously,
- multiple strategies trading the same session,
- multiple timeframes on one symbol,
- several independent mean-reversion/trend/breakout/session strategies on the same market.

Do NOT impose arbitrary:

- max 1 strategy per symbol,
- max 2 strategies per symbol,
- family-count targets,
- symbol-count targets.

Use actual dependence and account-level risk.

----------------------------------------------------------------------
2. DO NOT SEARCH FOR A HERO EA
----------------------------------------------------------------------

Stop interpreting the FTMO research programme as:

> Find one EA that can pass FTMO.

Instead ask:

> What collection of sleeves produces the strongest path toward Challenge → Verification → FTMO Account → payout?

An EA with modest standalone performance may be highly valuable if it:

- trades when the other sleeves are inactive,
- earns in different regimes,
- reduces portfolio drawdown,
- shortens recovery periods,
- improves target-passage probability,
- reduces dependence on one symbol/session/regime,
- increases opportunity density,
- improves daily-loss headroom,
- supplies positive expectancy during another sleeve's weak regime.

A high standalone R/day strategy may be rejected from the book if it adds:

- correlated losses,
- tail concentration,
- stop clustering,
- excessive daily-loss risk,
- duplicate exposure,
- unstable execution.

----------------------------------------------------------------------
3. NEW PRIMARY RESEARCH QUESTION
----------------------------------------------------------------------

For every candidate EA/sleeve, the primary question becomes:

> WHAT IS ITS MARGINAL CONTRIBUTION TO FTMO_BOOK?

Not merely:

> Is this EA profitable?

Measure at minimum:

`DELTA_P_FIRST_NET_FTMO_PAYOUT_LCB`

`DELTA_P_CHALLENGE_PASS`

`DELTA_P_VERIFICATION_PASS`

`DELTA_P_DAILY_LOSS_BREACH`

`DELTA_P_MAX_LOSS_BREACH`

`DELTA_EXPECTED_TIME_TO_TARGET`

`DELTA_MAX_DRAWDOWN`

`DELTA_RECOVERY_TIME`

`DELTA_TRADE_DENSITY`

`DELTA_TAIL_DEPENDENCE`

`DELTA_COST_DRAG`

A candidate may be accepted despite weaker standalone statistics if its portfolio contribution is positive.

A candidate with strong standalone statistics may be rejected if portfolio contribution is negative.

----------------------------------------------------------------------
4. VELOCITY IS A PORTFOLIO PROPERTY
----------------------------------------------------------------------

The current Velocity research is valuable.

However:

Do NOT optimize exclusively for the fastest standalone sleeve.

`R_PER_DAY`

is useful evidence, not the business KPI.

The important quantity is approximately:

`FTMO_BOOK_EXPECTED_PROGRESS_PER_DAY`

subject to:

- Daily Loss safety,
- Maximum Loss safety,
- realistic cost,
- execution limits,
- portfolio dependence,
- tail risk,
- stable opportunity density.

H-V4 / QM5_41485 is therefore:

> one possible high-velocity sleeve

NOT:

> the EA intended to pass the Challenge by itself.

Evaluate H-V4 by its incremental contribution to FTMO_BOOK.

----------------------------------------------------------------------
5. SAME-SYMBOL MULTI-STRATEGY IS EXPLICITLY ALLOWED
----------------------------------------------------------------------

Do not equate symbol concentration with strategy dependence.

Ten strategies on XAUUSD are allowed if evidence supports them.

But prove whether they are genuinely different.

For sleeves on the same symbol measure:

- entry-time overlap,
- position overlap,
- direction overlap,
- trade-day overlap,
- daily-P/L correlation,
- downside correlation,
- worst-day overlap,
- stop-loss clustering,
- news-event overlap,
- volatility-regime overlap,
- tail co-exceedance,
- shared gap exposure,
- simultaneous margin usage.

Same symbol ≠ same strategy.

Different EA ID ≠ diversification.

Evidence decides.

----------------------------------------------------------------------
6. BUILD A PORTFOLIO DEPENDENCE MATRIX
----------------------------------------------------------------------

Maintain a current:

`FTMO_BOOK_DEPENDENCE_MATRIX`

For every pair of sleeves calculate where evidence permits:

- ordinary return correlation,
- downside correlation,
- loss-day overlap,
- trade overlap,
- simultaneous exposure,
- lower-tail dependence,
- worst-day overlap,
- common-session dependence,
- common-news dependence,
- common-symbol dependence,
- common-family dependence.

Do not rely on Pearson correlation alone.

The central question is:

> Do these sleeves fail together?

----------------------------------------------------------------------
7. BUILD AT ACCOUNT LEVEL
----------------------------------------------------------------------

All FTMO simulations must increasingly operate at account level.

Aggregate real chronological trades from all candidate sleeves.

Simulate:

- combined balance,
- combined equity,
- open P/L,
- commissions,
- swap,
- spread/slippage,
- simultaneous positions,
- account-level Daily Loss,
- Maximum Loss,
- target passage,
- Verification passage,
- payout survival.

Do NOT estimate the FTMO portfolio by simply adding standalone Sharpe ratios or average returns.

Chronological interaction matters.

----------------------------------------------------------------------
8. RISK ALLOCATION IS PART OF THE STRATEGY
----------------------------------------------------------------------

FTMO_BOOK must optimize both:

A. sleeve selection
B. sleeve risk weights

Examples:

Sleeve A:
high expectancy, high tail overlap
→ smaller allocation.

Sleeve B:
lower expectancy, excellent orthogonality
→ may receive meaningful weight.

Sleeve C:
high opportunity density and low correlation
→ may materially improve target speed.

The research problem is therefore:

`SELECT SLEEVES + ALLOCATE RISK`

not:

`PICK BEST EA`.

----------------------------------------------------------------------
9. ACCOUNT-LEVEL FTMO GOVERNOR
----------------------------------------------------------------------

The account-level FTMO Governor is the final risk authority over all sleeves.

It must see:

- total realized daily P/L,
- total floating P/L,
- open risk,
- correlated exposure,
- stop concentration,
- margin,
- Daily Loss headroom,
- Maximum Loss headroom.

Individual EAs must not independently assume that account risk is available.

The book-level governor may:

- reduce new-entry permission,
- block additional correlated entries,
- freeze a symbol cluster,
- stop further pyramiding,
- disable a sleeve,
- flatten risk where required by the current FTMO risk contract.

Portfolio safety overrides individual EA signals.

----------------------------------------------------------------------
10. STRATEGY DIVERSITY SHOULD BE ECONOMIC, NOT COSMETIC
----------------------------------------------------------------------

We want multiple independent return engines.

Potential dimensions include:

- trend,
- mean reversion,
- breakout,
- volatility expansion,
- volatility contraction,
- session effects,
- opening-range effects,
- closing effects,
- price action,
- carry-free intraday,
- scalping,
- asymmetric trailing,
- positive pyramiding,
- bounded recovery,
- event-response,
- cross-market/basket effects.

Do NOT force one strategy from every category.

Use measured marginal book value.

----------------------------------------------------------------------
11. RESEARCH SHOULD TARGET MISSING PORTFOLIO BEHAVIOURS
----------------------------------------------------------------------

Update:

`FTMO_PORTFOLIO_GAP_CURRENT.md`

Do not merely state:

"We need another strategy."

State:

"We need a sleeve that behaves like X when the current book behaves like Y."

Examples:

- current book loses during NY volatility expansion,
- current book has insufficient Asian-session opportunities,
- current book is overly dependent on USD,
- current book makes money but too slowly,
- current book has enough expectancy but losses cluster,
- current book needs a low-overlap high-density sleeve,
- current book is too dependent on overnight positions.

Then research that missing behavior.

----------------------------------------------------------------------
12. CANDIDATE VALUE = PORTFOLIO MARGINAL VALUE
----------------------------------------------------------------------

Create a living candidate table conceptually like:

| Candidate | Standalone edge | Density | Tail | Dependence | Marginal payout probability | Book action |
|-----------|----------------|---------|------|------------|-----------------------------|-------------|
| H-CW | ... | ... | ... | ... | ... | ADD / HOLD |
| H-MR | ... | ... | ... | ... | ... | ADD / HOLD |
| H-FXMR | ... | ... | ... | ... | ... | ADD / HOLD |
| H-V4 | ... | ... | ... | ... | ... | TEST |
| ... | ... | ... | ... | ... | ... | ... |

No overall arbitrary score is required if it hides important tradeoffs.

----------------------------------------------------------------------
13. PORTFOLIO CONSTRUCTION LOOP
----------------------------------------------------------------------

Operate an iterative loop:

1. Establish current best FTMO_BOOK.
2. Measure its strongest failure mode.
3. Identify missing economic behavior.
4. Research the smallest number of hypotheses targeting that gap.
5. Cheap deterministic prescreen first.
6. Build only survivors.
7. Validate in MT5.
8. Measure marginal portfolio contribution.
9. Add only if the book improves.
10. Re-optimize risk weights conservatively.
11. Repeat.

This is Continuous Book Evolution applied to FTMO.

----------------------------------------------------------------------
14. CURRENT VELOCITY HARNESS
----------------------------------------------------------------------

The new M1/.hcc Velocity prescreen is a valuable pre-Factory tool.

Continue using it.

Expand it where justified to screen:

- session hypotheses,
- intraday breakouts,
- mean-reversion windows,
- time-of-day effects,
- volatility-conditioned entries,
- range/ATR variants.

But always preserve:

- preregistration,
- Selection/Validation separation,
- transaction costs,
- null/bootstrap tests,
- anti-data-mining controls.

A fast research harness must not become an overfitting engine.

----------------------------------------------------------------------
15. USE ALL MARKETS WHERE THEY HELP THE BOOK
----------------------------------------------------------------------

Do not require symbol diversification for its own sake.

The FTMO_BOOK may eventually contain:

- many Gold sleeves,
- several USDJPY sleeves,
- several EURUSD sleeves,
- index sleeves,
- other valid markets,

if the portfolio-level evidence supports them.

Likewise do not add a weak market merely because the book lacks that symbol.

Economic independence > symbol count.

----------------------------------------------------------------------
16. TRADE DENSITY COMES FROM THE BOOK
----------------------------------------------------------------------

One slow EA is not necessarily a problem if the BOOK contains many staggered opportunity streams.

For example:

EA A: 0.2 trades/day
EA B: 0.3
EA C: 0.4
EA D: 0.5
EA E: 0.3

may collectively produce much more stable opportunity density than one EA forced to trade 2 times/day.

Therefore evaluate:

`BOOK_TRADES_PER_DAY`

`ACTIVE_TRADING_DAYS`

`TIME_WITH_NO_OPPORTUNITY`

`PROFIT_OPPORTUNITY_DISTRIBUTION`

not only per-EA density.

----------------------------------------------------------------------
17. TARGET SPEED SHOULD EMERGE FROM DIVERSIFIED EDGE
----------------------------------------------------------------------

Do not obtain Challenge speed by increasing one strategy's risk until it becomes dangerous.

Prefer:

more independent positive-expectancy opportunities
+
sensible account-level risk

over:

one aggressively sized strategy.

The ideal FTMO book achieves speed through:

`EDGE × OPPORTUNITY DENSITY × DIVERSIFICATION`

not through leverage alone.

----------------------------------------------------------------------
18. REPRESENTATIVE DEMO MUST TEST THE BOOK
----------------------------------------------------------------------

The mandatory representative Demo is not:

"Run our best EA for 14 days."

It is:

> Run the intended FTMO_BOOK, with intended sleeve weights and account-level governor, for a representative evidence period.

Freeze:

- list of sleeves,
- versions/hashes,
- symbols,
- timeframes,
- setfiles,
- risk weights,
- account-level risk policy,
- news policy,
- session policy.

Then measure the whole account.

A material book change requires the representative evidence period to be restarted or extended appropriately.

----------------------------------------------------------------------
19. FIRST-PASSAGE MUST RUN ON THE BOOK
----------------------------------------------------------------------

The most important first-passage simulation is portfolio-level.

Estimate:

`P(FTMO_BOOK reaches Challenge target before Daily/Max Loss breach)`

then:

`P(Verification target before breach)`

then:

`P(first payout before account failure)`

Individual-sleeve first-passage is diagnostic.

Book-level first-passage drives the commercial decision.

----------------------------------------------------------------------
20. DO NOT REQUIRE EVERY SLEEVE TO PASS EVERY PORTFOLIO ROLE
----------------------------------------------------------------------

A sleeve does not need to be:

- fastest,
- lowest drawdown,
- highest Sharpe,
- highest PF,
- highest density

simultaneously.

Different sleeves may have different jobs.

Examples:

- velocity sleeve,
- stabilizer sleeve,
- counter-regime sleeve,
- Asian-session sleeve,
- NY-session sleeve,
- volatility sleeve,
- low-cost FX sleeve,
- Gold alpha sleeve.

What matters is their contribution to the whole.

----------------------------------------------------------------------
21. H-V4 IMMEDIATE INTERPRETATION
----------------------------------------------------------------------

Continue the current H-V4 process.

If Codex approves Revision 2:

- build QM5_41485,
- run USDJPY Q02 Canary,
- continue normal validation.

But explicitly treat it as:

`CANDIDATE_ROLE = VELOCITY_SLEEVE`

not:

`CANDIDATE_ROLE = FTMO_SOLUTION`.

After economic validation, evaluate:

> Does H-V4 improve the current FTMO_BOOK when combined with the best existing sleeves?

----------------------------------------------------------------------
22. PRIMARY FTMO PROGRAMME KPI HIERARCHY
----------------------------------------------------------------------

North Star remains:

`FTMO_NET_CASH_REALIZED`

Primary pre-payout control remains a conservative:

`P_FIRST_NET_FTMO_PAYOUT_LCB`

But this probability is now explicitly:

> calculated for FTMO_BOOK, not for the best individual EA.

Supporting portfolio metrics:

- `BOOK_EXPECTANCY`
- `BOOK_R_PER_DAY`
- `BOOK_TRADES_PER_DAY`
- `BOOK_ACTIVE_DAYS`
- `BOOK_MAX_DD`
- `BOOK_DAILY_LOSS_BREACH_PROB`
- `BOOK_MAX_LOSS_BREACH_PROB`
- `BOOK_EXPECTED_TIME_TO_CHALLENGE_TARGET`
- `BOOK_EXPECTED_TIME_TO_VERIFICATION_TARGET`
- `BOOK_TAIL_DEPENDENCE`
- `BOOK_COST_DRAG`
- `BOOK_CONCENTRATION`

----------------------------------------------------------------------
23. RESEARCH PRIORITIZATION
----------------------------------------------------------------------

Prioritize a new candidate by:

`EXPECTED MARGINAL IMPROVEMENT TO FTMO_BOOK`
divided by
`RESEARCH + ENGINEERING + FACTORY COST`.

Do not rank ideas primarily by standalone R/day.

A 0.04 R/day independent sleeve may be more valuable than a 0.15 R/day clone of existing exposure.

----------------------------------------------------------------------
24. REQUIRED ARTIFACTS
----------------------------------------------------------------------

Create/update:

`docs/ftmo/FTMO_BOOK_CURRENT.md`

containing:

- current sleeves,
- current candidate sleeves,
- risk weights,
- roles,
- dependence matrix summary,
- book-level economics,
- first-passage state,
- missing portfolio behaviors,
- next candidate needed.

Create/update machine-readable:

`D:\QM\reports\state\ftmo_book_current.json`

Mission Control should expose:

FTMO BOOK
- sleeves
- active candidates
- book expected progress
- book density
- book DD
- rule headroom
- dependence risk
- first-passage
- strongest missing behavior

----------------------------------------------------------------------
25. DEFINITION OF THE GOAL

We are not trying to find:

> one exceptional EA.

We are trying to build:

> a portfolio of complementary mechanical edges whose combination has the highest credible probability of producing repeated FTMO payouts.

If that ends up being:

- 3 EAs,
- 8 EAs,
- 15 EAs,
- 10 Gold strategies,
- 5 FX strategies,
- or another composition,

that is acceptable.

There is no strategy-count target.

Evidence decides.

----------------------------------------------------------------------
26. IMMEDIATE ACTION

Reframe the current FTMO programme now.

Report:

`CURRENT_FTMO_BOOK = ...`

`CURRENT_VALIDATED_SLEEVES = ...`

`CURRENT_NEAR_VALIDATED_SLEEVES = ...`

`CURRENT_BOOK_R_PER_DAY = ...`

`CURRENT_BOOK_TRADE_DENSITY = ...`

`CURRENT_DEPENDENCE_RISK = ...`

`CURRENT_P_FIRST_NET_FTMO_PAYOUT_LCB = ... / NOT_YET_MEASURABLE`

`STRONGEST_MISSING_BOOK_BEHAVIOR = ...`

`H-V4_EXPECTED_ROLE = ...`

`NEXT_RESEARCH_TARGET = ...`

Then continue autonomously.

Do not return to a hero-EA search.

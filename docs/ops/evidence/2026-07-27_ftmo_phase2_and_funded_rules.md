# FTMO 2-Step Verification and FTMO Account rules

Research date: 2026-07-27  
Scope: USD 100,000 FTMO Challenge: 2-Step, Standard account (FTMO's current site uses “Standard”; the brief's “Normal” means Standard).  
Evidence rule: official FTMO pages only unless explicitly labelled otherwise. `NOT ESTABLISHED` means the reviewed public official sources do not establish the requested detail.

## Numeric summary

| Phase / rule | Published value | USD 100k implication | Official source |
|---|---:|---:|---|
| Verification profit target | 5% | balance above $105,000, all positions closed | [Trading Objectives](https://ftmo.com/en/trading-objectives/) |
| Verification maximum daily loss amount | 5% of initial simulated capital | $5,000; the daily equity floor is midnight CE(S)T balance minus $5,000 | [Trading Objectives](https://ftmo.com/en/trading-objectives/) |
| Verification maximum loss | 10% of initial simulated capital, static | equity must remain at or above $90,000 | [Trading Objectives](https://ftmo.com/en/trading-objectives/) |
| Verification minimum trading days | 4 | at least one position opened on each of four CE(S)T calendar days | [Trading Objectives](https://ftmo.com/en/trading-objectives/) |
| Verification maximum trading period | none | no deadline | [Trading Objectives](https://ftmo.com/en/trading-objectives/) |
| FTMO Account maximum daily loss amount | 5% of initial simulated capital | same daily calculation; $5,000 | [Trading Objectives](https://ftmo.com/en/trading-objectives/) |
| FTMO Account maximum loss | 10% of initial simulated capital, static | $90,000 equity floor | [Trading Objectives](https://ftmo.com/en/trading-objectives/) |
| FTMO Account profit split | 80%; 90% if Scaling Plan or Premium Programme conditions are met | variable with status | [Reward withdrawal FAQ](https://ftmo.com/en/faq/how-do-i-withdraw-my-profits/) |
| Earliest reward request | 14th day or later after first trade on that account | not “every 14 days” automatically | [Reward withdrawal FAQ](https://ftmo.com/en/faq/how-do-i-withdraw-my-profits/) |
| Transfer-related minimum closed profit | $20 bank wire; $50 cryptocurrency | method-specific fee floor | [Reward withdrawal FAQ](https://ftmo.com/en/faq/how-do-i-withdraw-my-profits/) |
| Capital allocation | $400,000 per trader **or strategy**, before scaling | applies across 1-Step and 2-Step | [Account-count FAQ](https://ftmo.com/en/faq/how-many-accounts-can-i-have/) |
| EA server limits | 200 simultaneous orders; 2,000 positions/day; forbidden hyperactivity is over 2,000 server requests/day | relevant to automation, not H1/D1 under ordinary operation | [Strategy/EA FAQ](https://ftmo.com/en/faq/which-instruments-can-i-trade-and-what-strategies-am-i-allowed-to-use/), [Forbidden Trading Practices](https://ftmo.com/en/forbidden-trading-practices/) |
| Standard-account selected-news window | 2 minutes before through 2 minutes after | opening, closing, and pending-order activation/closure on affected instruments prohibited | [News FAQ](https://ftmo.com/faq/can-i-trade-news/) |

## A. Phase 2 (Verification)

1. **Profit target:** 5% of Initial Simulated Capital, hence $5,000 on $100,000.

2. **Loss caps:** the Maximum Daily Loss Amount is 5% and Maximum Loss Amount is 10%. These are the same percentages and calculations as Phase 1 of the 2-Step product. Daily loss is an equity floor recalculated at 00:00 CE(S)T from that day's opening balance minus 5% of initial capital. Total maximum loss is a static equity floor at initial capital minus 10%.

3. **Minimum trading days:** 4. A qualifying Trading Day is 00:00:00–23:59:59 CE(S)T with at least one newly opened position. Closing a position alone does not create a Trading Day.

4. **Maximum trading period:** none. FTMO states “No time limit”; its official announcement says the former 30/60-day Evaluation deadlines were removed. [Trading Objectives](https://ftmo.com/en/trading-objectives/), [unlimited-period announcement](https://ftmo.com/en/blog/trade-without-any-time-limit-and-take-as-long-as-you-want-to-pass/)

5. **Passing condition:** yes. FTMO states the objective is met when balance exceeds initial capital by the target and all positions are closed; the page applies that definition to the 2-Step Challenge and Verification.

## B. Inactivity / dormancy

6. **Exact threshold and wording:** `NOT ESTABLISHED` from a current official public rule. FTMO's official unlimited-period announcement says that after “a few weeks” of inactivity FTMO will contact the trader and that a freeze can be requested, but it does not publish an exact 30-day threshold. [Official announcement](https://ftmo.com/en/blog/trade-without-any-time-limit-and-take-as-long-as-you-want-to-pass/)

7. **Scope across Challenge, Verification, and FTMO Account:** `NOT ESTABLISHED`. The official public material reviewed does not establish a uniform 30-day rule or phase-specific thresholds.

8. **What counts as activity / held-open position:** `NOT ESTABLISHED`. The four-day objective explicitly counts days on which a position is **opened**, but that definition cannot safely be imported into a separate dormancy rule.

9. **Consequence, warning, recoverability:** the announcement establishes contact after “a few weeks” and availability of a requested freeze. An automatic breach, closure, warning sequence, and recovery process at day 30 are `NOT ESTABLISHED`.

Internal evidence note: OWNER experience says FTMO blocks an account after 30 days without a trade. That is an internal operational premise, not corroborated by the current public official sources found here. The measurement model must label it `OWNER-confirmed / official scope unresolved`, not “official FTMO rule”.

## C. FTMO Account (2-Step)

10. **Loss caps:** the same 5% Maximum Daily Loss Amount and static 10% Maximum Loss Amount apply continuously to the subsequent 2-Step FTMO Account. Equity, including open P/L, swaps, and commissions, is the tested quantity. [Trading Objectives](https://ftmo.com/en/trading-objectives/)

11. **Loss-floor geometry:** static, not a balance/equity high-water-mark trail. For $100,000 initial capital, the published FTMO Account (2-Step) floor is $90,000. The trailing formulation on the same page applies to the 1-Step product, not 2-Step.

12. **Withdrawal effect:** the public 2-Step objective remains defined from Initial Simulated Capital, so its published floor remains $90,000. A withdrawn Reward therefore removes profit buffer above that floor unless profit is rolled over. FTMO explicitly offers 2-Step Reward rollover to build balance/drawdown buffer. The precise account-reissue bookkeeping after a 2-Step withdrawal is `NOT ESTABLISHED`; do not borrow the explicit “new account / limit fully resets” language FTMO publishes for 1-Step. [Trading Objectives](https://ftmo.com/en/trading-objectives/), [Reward withdrawal FAQ](https://ftmo.com/en/faq/how-do-i-withdraw-my-profits/)

13. **Profit split:** 80%; it increases to 90% when Scaling Plan or Premium Programme conditions are met.

14. **Payout schedule:** the trader may request a Reward on the 14th or any later day after the first trade on the specific account, with all open positions and pending orders closed. FTMO reviews the request in 1–2 business days and typically sends it 1–2 business days after invoice approval. The official page establishes an earliest on-demand request, not an automatic biweekly cadence. A separate minimum interval between later payouts is `NOT ESTABLISHED` on that page.

15. **Minimum profit:** no universal minimum percentage is stated. The published transfer-related closed-profit minimum is $20 for bank wire and $50 for cryptocurrency; other methods' minimum is `NOT ESTABLISHED`.

16. **Funded consistency / trading days / activity:** the 2-Step FTMO Account has no Minimum Trading Days rule and no Profit Target. No funded-account consistency rule is published for 2-Step on the Trading Objectives page; the 50% Best Day rule shown there is for 1-Step. Any separate funded dormancy rule remains `NOT ESTABLISHED`.

## D. Prohibited practices and operational fit

17. FTMO's official list prohibits:

- exploiting service errors, price-display errors, delayed updates, or external/slow feeds;
- manipulative coordinated trading, including opposite positions across connected accounts, other providers, or Program Group accounts;
- trades conflicting with the applicable terms or platform terms;
- software, AI, ultra-high-speed tools, or mass data entry that manipulates, abuses, or creates unfair advantage;
- gap trading around scheduled major events or within two hours before a market closes for at least two hours;
- activity not replicable in real markets or reasonably capable of causing FTMO harm, with examples including overleveraging, overexposure, one-sided bets, and account rolling;
- EA hyperactivity above 2,000 server requests/day;
- artificially spreading profit across days to evade the Best Day Rule;
- non-replicable risk, including abrupt size/count changes or cumulative exposure to one or correlated symbols;
- third-party access, trading for another person, or coordinated third-party operation.

Possible consequences include trade removal, platform restriction, Evaluation disqualification, Reward forfeiture, and termination. [Forbidden Trading Practices](https://ftmo.com/en/forbidden-trading-practices/)

18. **Multiple accounts / correlation:** multiple accounts are allowed, but total allocation is capped at $400,000 per trader **or strategy** before scaling, across 1-Step and 2-Step. Different registrations are forbidden. FTMO may suspend affected accounts if identically traded strategies across multiple accounts exceed that limit. The official materials do not prohibit every correlated strategy below the allocation cap, but they do prohibit manipulative opposite-position coordination and warn against cumulative exposure in correlated symbols. Separate accounts running distinct sleeves must therefore be governed at trader/strategy aggregate exposure; “one sleeve per account” is not an exemption.

19. **EA, weekend, and news restrictions:** legitimate algorithmic trading and EAs are allowed, subject to replicability, allocation, forbidden-practice, and hyperactivity rules. For a Standard FTMO Account, positions must be closed shortly before weekend market closure or any market break longer than two hours; this restriction does not apply during Challenge/Verification, and Swing accounts are exempt. For a Standard FTMO Account, affected instruments cannot be opened or closed from two minutes before through two minutes after selected releases; pending-order activation and SL/TP closure count, while holding a position opened earlier is allowed only if it does not close during the restricted window. Swing accounts are exempt. [Strategy/EA FAQ](https://ftmo.com/en/faq/which-instruments-can-i-trade-and-what-strategies-am-i-allowed-to-use/), [overnight/weekend FAQ](https://ftmo.com/en/faq/do-i-have-to-close-my-positions-overnight-or-before-the-weekend/), [news FAQ](https://ftmo.com/faq/can-i-trade-news/)

For QuantMechanica: the mandatory news blackout is stricter and remains binding. H1/D1 mechanical EAs are allowed in principle, but Standard-funded weekend closure means any system designed to hold across weekends is operationally incompatible unless exits are enforced or the account was selected as Swing at purchase.

## Repository contradictions and modelling corrections

- `tools/strategy_farm/portfolio/challenge_overlay.py` says FTMO removed the minimum trading days. Current official 2-Step objectives require 4 Trading Days in both Challenge and Verification. This is a direct contradiction.
- `tools/strategy_farm/portfolio/challenge_firstpassage.py` prints that the target is tested on end-of-day balance. FTMO's published rule says balance must exceed target with all positions closed; it does **not** say “end of day”. The model's EOD sampling is a modelling approximation, not the official timing rule.
- `tools/strategy_farm/portfolio/challenge_two_phase.py` encodes `DORMANCY_DAYS = 30` as OWNER-confirmed. Keep the internal premise if OWNER directs, but public official wording, scope, activity definition, and consequence are unresolved and must not be represented as externally verified.
- Any plan describing funded payouts as “every two weeks” should be corrected to “requestable on the 14th or later day after the first trade”; an automatic cadence and later-cycle minimum interval are not established by the cited FAQ.

## Source-quality conclusion

All substantive rules above use official FTMO sources. No secondary source was needed. The dormancy particulars requested in questions 6–9 remain deliberately unresolved rather than inferred.

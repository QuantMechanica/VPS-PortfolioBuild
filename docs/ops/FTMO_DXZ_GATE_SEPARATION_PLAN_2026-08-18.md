# Plan — separating the DXZ and FTMO tracks at the gates

**Trigger:** OWNER-supplied external consultant audit, 2026-08-18. **Author:** Claude.
**Status:** plan, nothing implemented yet beyond the inventory below.

The audit's central architectural claim — that DXZ and FTMO need separating at certain gates — is
correct and is adopted. Three of its supporting diagnoses were checked against artefacts before
planning: **one is confirmed, one needs a sharper formulation, one is not supported by measurement.**
Recording that plainly is not point-scoring; it changes what gets built.

---

## 1 · What was verified

### 1.1 CONFIRMED — the pipeline is blind to the daily loss barrier

`framework/scripts/q08_davey/sub_8_11_mc_shuffle_dd.py` is the only Davey sub-gate that measures
drawdown. `_max_drawdown_abs()` walks the **trade sequence** and takes peak-to-trough on a
trade-indexed equity curve. There is no calendar-day binning anywhere in it. The other sub-gates use
"daily" only for *daily-resampled returns* in the correlation and DSR gates — a different quantity
from a daily-loss barrier.

Searched the whole of `framework/scripts/` and `tools/strategy_farm/*.py` for a daily-loss gate:
the matches are `q16_head_to_head.py`, `analyze_ftmo_costs.py`, `ftmo_trial_pulse.py`,
`target_rulepacks.py`, `timer_deviation_analysis.py` — **all of them analysis or reporting tools,
none of them a gate in Q02–Q10.**

**But the number already exists.** The challenge engine computes `worst_day_1x` for every scored
sleeve, and it is sitting in `fund_scores.json` right now:

| sleeve | worst day (% of account, 1×) |
|---|---:|
| 9403:GDAXI | **3.01** |
| 10706:GBPUSD | 2.44 |
| 10115:GDAXI | 2.09 |
| 20086:EURUSD | 2.07 |
| 10848:XAUUSD | 2.03 |
| 11660:NDX | 1.98 |

Against FTMO's 5 % daily barrier, a **single** sleeve at 3.01 % consumes 60 % of the day's budget at
1× sizing before any other sleeve trades, and before any sizing multiplier is applied.

**So the defect is not a missing measurement. It is a measured quantity that no gate consumes.**
That is the cheapest possible class of fix and it is the core of this plan.

### 1.2 SHARPENED — "the Davey gates are misleading for FTMO" is not quite the right word

The audit says the Davey gates are misleading. They are **insufficient**, which is a different thing
and implies a different repair. Davey answers *"is this edge real or is it overfitting?"* — a
question that matters identically for both books. Its verdict is not wrong for FTMO; it is silent on
FTMO's constraints. **Therefore Davey is not replaced or bypassed for the FTMO track; a target gate
is added after it.** Replacing it would throw away the one thing protecting both books from the
Monte-Carlo-survivor problem the audit itself warns about in §3.

One genuine open question does deserve measurement rather than assertion: the **chopping block**
sub-gate removes the top 5 % of trades and requires survival. A sprint book that needs +10 % in 60
days may legitimately depend on its best trades in a way a multi-year Sharpe book does not. Whether
chopping block systematically rejects high-density sprint candidates is **measurable and unmeasured**
— it goes on the list as a question, not as a finding.

### 1.3 NOT SUPPORTED — the density diagnosis does not hold for the current pool

The audit's diagnosis #2 says the factory produces low-density swing EAs and that "<20 trades/year
EAs are useless for FTMO". Measured against the density producer built earlier today
(`tools/strategy_farm/portfolio/sleeve_density.py`), over all 21 currently scorable sleeves:

| sleeve | active days per 60d (p10) | median | trades |
|---|---:|---:|---:|
| 10183:XAUUSD | 40 | **42** | 1,773 |
| 10291:SP500 | 38 | 42 | 1,781 |
| 13108:XTIUSD | 37 | 42 | 1,778 |
| 11660:NDX | 36 | 38 | 1,741 |
| 10848:XAUUSD | 28 | 33 | 1,622 |

**Ten of 21 sleeves show a median of ≥25 active days per 60-day window**, and the sum of per-sleeve
medians is **515 active-days per 60-day window** across the pool. A median of 42 active days per 60
calendar days is essentially every trading day. The audit asks for 150–300 trades per 60 days
portfolio-wide; the measured pool clears that by a wide margin.

**The sharpest counter-example is the audit's own evidence.** Its post-mortem names
QM5_10848/XAUUSD as losing $2,186.88 in 6 trades. That sleeve has **1,622 trades and a median of 33
active days per 60** — it is not a low-density swing EA. Its trial loss was a **sizing and
correlation** failure, not a density failure.

This matters for the plan, because the two diagnoses imply opposite work. "Density deficit" implies
sourcing new intraday strategy classes — months of work. "Sizing and correlation under a daily
barrier" implies a daily-loss gate and a correlation-aware sizing layer — weeks, mostly against
machinery that exists. **The measurement points at the second.** The audit's §5 cluster-correlation
observation (US100, GER40 and XAUUSD stopped out on the same day = one macro risk wearing three EA
names) is exactly right and is adopted.

### 1.4 ALREADY BUILT, NOT WIRED — the FTMO governor

The audit's Step 3 asks for a hard-coded FTMO governor with a daily circuit breaker. It exists:

- `framework/include/QM/QM_FTMOGovernorPolicy.mqh` — three tiers per account size:
  `official_daily_loss` (5000.0), `entry_daily_stop` (e.g. 900/650/350),
  `liquidation_daily_stop` (e.g. 1250/900/…). That is already the audit's "-2.5 % circuit breaker"
  idea, with the refinement of separating *stop entering* from *liquidate*.
- `framework/include/QM/QM_FTMOGovernorClient.mqh` — the client side.

```
EAs including QM_FTMOGovernorClient : 5
EAs calling a governor init or check: 0
```

**Five EAs include the header and none calls it.** This is the identical shape as the grid guard
(0 of 3,697 sources call `QM_GridInit`) and it is exactly what v7's rule *freiwillige Sicherheit ist
keine Sicherheit* and point 1.9 exist for. The work is wiring plus a blocking build gate, not design.

Also already present: `ftmo_spread_calibration.py` (394 lines, hash-bound M1 spread calibration,
90th-percentile upper-tail delta, refusal rather than extrapolation) with a produced artefact at
`D:/QM/reports/ftmo_spread_calibration/ftmo_spread_calibration_2026-08-09_router_recheck.json`; and
`target_rulepacks.py`, which already validates an FTMO snapshot with a 0–7 day freshness bound and a
DXZ 5 % daily guardrail.

---

## 2 · The design: where the tracks separate

**They do not separate at Q02–Q08.** Those gates answer target-agnostic questions — does it trade,
does it survive out-of-sample, is it overfit. Forking them would double the factory's cost and
double its evidence surface for no gain, and the audit's own §2.2 grades them 1.7.

**They separate at admission**, in a new target-scoped gate that consumes quantities the pipeline
already produces. One gate, two rulepacks.

```
Q02 … Q07        shared, target-agnostic
Q08 Davey        shared — overfitting only
Q09/Q10          shared
────────────────────────────────────────────────
Q11_TARGET       NEW: target-scoped admission
                 ├── rulepack DXZ   → mission baseline 5 % / 20 %
                 └── rulepack FTMO  → daily 5 %, total 10 % STATIC_INITIAL,
                                      ≥4 trading days, 60 days
```

The rulepack machinery for this already exists (`target_rulepacks.py`, schema
`target-rulepack/v1`). The gate is a consumer of it.

### 2.1 What the FTMO rulepack checks, per sleeve and per book

Every input below is already computed today; none requires a new backtest.

| check | quantity | source | today |
|---|---|---|---|
| daily-loss headroom | `worst_day_1x` | challenge engine → `fund_scores.json` | computed, **ungated** |
| window density | `active_days_per_60d` (p10) | `sleeve_density.py` | built today |
| pass proxy | `fund_score` = med60 / max(2, 2·worst_day, wdd_p90) | `fund_score.py` | computed |
| book-level daily coupling | same-day loss co-exceedance across sleeves | needs the 2.3 daily series | **the one real gap** |
| cost realism | FTMO-vs-DXZ spread delta | `ftmo_spread_calibration.py` | artefact exists |

The book-level check is the one that would have caught trial #2. Three sleeves each individually
inside their budget, stopped out on the same day, is not visible in any per-sleeve number. **It is
visible only in the daily series that 2.3 is currently producing** — which is why 2.3 stays the
critical path and this plan does not displace it.

### 2.2 The per-sleeve daily-loss gate, stated concretely

Proposed admission rule for the FTMO rulepack, to be pre-registered before it is run:

- reject a sleeve whose `worst_day_1x` alone exceeds a stated fraction of the daily barrier
- the fraction is a **budget share**, not a magic number: with a target of N sleeves and a 5 % daily
  barrier held to a 3 % working limit (the audit's 99 % VaR figure), a single sleeve's share is
  3 % / N at 1× sizing, scaled by its sizing multiplier
- **the reference quantity follows the purpose** (v7): the barrier is measured against balance at
  day start including floating positions, so the gate must consume the intraday path from 2.3, not
  daily-close returns. Daily-close returns understate the barrier systematically, and doubly so for
  grid sleeves.

At N = 10 sleeves that is a 0.30 % share per sleeve at 1×, against measured worst days of 0.99–3.01 %
— i.e. **the sizing multiplier does the work, and several sleeves cannot be admitted at 1× at all.**
That is a concrete, quantified consequence and it should be stated in the pre-registration rather
than discovered during construction.

---

## 3 · The plan, in the order it should be done

Each item names its acceptance test. Nothing here displaces 2.3, which remains the only item on the
v7 critical path.

**P1 — Wire the FTMO governor and make it non-optional.** *(closes the audit's Step 3 and v7 1.9)*
Wire `QM_FTMOGovernorClient` into the five EAs that already include it; extend
`prescreen_build_reviews.py` — which already detects unread inputs and unwired includes — into the
**blocking** build gate v7 1.9 asks for, with the governor as its first case and the grid guard as
its second.
*Acceptance:* a build that includes the governor header and never calls it FAILS the gate;
positive control on the five EAs; negative control on an EA that does not include it at all.

**P2 — Land `worst_day_1x` as a gate input, not just a report.**
The quantity exists. Add it to the target rulepack as an admission criterion with a declared
`>` / `>=` (v7 E5 requires every floor to declare its comparison).
*Acceptance:* re-running admission over the 21 scored sleeves reproduces their `worst_day_1x` values
byte-for-byte from `fund_scores.json`, and the rejection list is explainable sleeve by sleeve.

**P3 — Finish the FTMO cost picture.** The calibration artefact is from 2026-08-09; the venue cost
model carries 19 symbols under a `max(dxz, ftmo)` convention. Reconcile the two, extend to the pool
symbols, and deliver 3.1 properly — which v7 §0(iii) already demands and which this audit
independently reinforces from the FTMO side.
*Acceptance:* v7 3.1's own acceptance — all pool symbols covered, source and date per value, the
three existing symbols reproduce their current values, +25 % sensitivity table attached.

**P4 — Build the book-level same-day coupling check.** The one genuine gap. It is the check that
would have caught trial #2's simultaneous US100 / GER40 / XAUUSD stop-out.
*Depends on 2.3.* Feeds v7 3.2's tail-coupling proxy and 3.4's failure decomposition.
*Acceptance:* run it retrospectively against the trial #2 book and confirm it flags that day.

**P5 — Answer the chopping-block question by measurement.** Does sub-gate 8.6 systematically reject
high-density candidates? Correlate chopping-block outcome against `active_days_per_60d` over the
existing Q08 population. If there is no relationship, the question is closed and Davey stands
unchanged for both tracks.

**P6 — Sourcing.** The audit's four edge classes (Asian-range/London sweep, NY momentum, overnight
mean reversion, intraday cointegration) are a research directive. **Deliberately last**, because
§1.3 shows the current pool is not density-starved, and because 1.19 recorded that 20 of 20 recent
card submissions duplicated existing reservoir entries. New sourcing before P1–P4 would add
candidates to a pipeline that still cannot tell whether they breach a daily barrier.

---

## 4 · What this plan deliberately does not do

- **It does not fork Q02–Q08.** Two pipelines mean two evidence trails and twice the factory cost for
  questions that do not depend on the target.
- **It does not weaken or bypass Davey for FTMO.** The audit's own §3 argues that among 3,700
  candidates some pass by chance; Davey is the machinery that resists exactly that.
- **It does not buy an FTMO challenge.** The audit's recommendation #1 is adopted without
  qualification.
- **It does not start a new sourcing programme yet.** See P6.

## 5 · Evidence

- `framework/scripts/q08_davey/sub_8_11_mc_shuffle_dd.py:22` — `_max_drawdown_abs` over the trade
  sequence; no calendar binning
- `framework/include/QM/QM_FTMOGovernorPolicy.mqh:43-126` — three-tier daily policy
- include-vs-call census over `framework/EAs/` — 5 includes, 0 calls
- `D:\QM\strategy_farm\artifacts\portfolio\fund_scores.json` — `worst_day_1x` and
  `active_days_per_60d` for 21 scored sleeves
- `tools/strategy_farm/portfolio/sleeve_density.py` — density method and its positive control
- `D:/QM/reports/ftmo_spread_calibration/ftmo_spread_calibration_2026-08-09_router_recheck.json`
- consultant audit, OWNER-supplied, 2026-08-18

---

# Part II — the code repairs, the framework changes, and the re-backtest question

*Added 2026-08-18 after OWNER supplied a per-strategy repair directive and asked whether the EA
framework must change and whether EAs must be re-backtested.*

## 6 · The four repair items, checked against the code

### 6.1 CONFIRMED — fixed pips instead of adaptive volatility (QM5_11450)

The cited lines are correct:

```
60: input int strategy_range_min_pips = 15;   // skip too-narrow Asian ranges
63: input int strategy_sl_cap_pips    = 30;   // P2 max stop distance
64: input int strategy_tp_pips        = 40;   // primary target from card
```

They are consumed through `QM_StopRulesPipsToPriceDistance()` at :124/:279/:280 and
`QM_TakeFixedPips()` at :305 — genuinely fixed price distances, with no ATR anywhere. The diagnosis
holds.

### 6.2 CONFIRMED, and it is a fleet-wide class rather than one EA (QM5_12539)

```
54: int  Strategy_HHMM(const datetime t)
67: bool Strategy_InLondonKillzone(const datetime t)
70:    return (hhmm >= 900 && hhmm < 1200);
582: if(!Strategy_InLondonKillzone(TimeCurrent()))
```

Raw broker time, exactly as described. **And the framework already solves this**:
`framework/include/QM/QM_DSTAware.mqh:117,122` provide `QM_UTCToBroker()` / `QM_BrokerToUTC()`.

The population split is the finding:

| | EAs |
|---|---:|
| use `QM_BrokerToUTC` | **244** |
| use `TimeToStruct(TimeCurrent…)` directly | **389** |

This is not a bug in one EA; it is a **shared-template inconsistency across the fleet** — v7: *ein
Defekt in einem geteilten Template ist nie ein Einzelfall*. Caveat on the 389: that is a text screen,
not a verdict. Some EAs legitimately work in broker time — Friday-close enforcement and session
anchors defined against the server day. Each needs classifying before it is "repaired"; converting a
correctly-broker-anchored EA to UTC would break it.

### 6.3 NOT SUPPORTED — "the EA assigned fixed lots instead of using OrderCalcProfit"

This is the most consequential item in the directive, and the measurement contradicts it.

```
QM5_10911_grimes-complex-pb.mq5
  13: input double RISK_PERCENT = 0.0;
  14: input double RISK_FIXED   = 1000.0;
 396:                RISK_PERCENT,
 397:                RISK_FIXED,      -> passed into the framework entry path
```

Fleet-wide: **3,748 references to `QM_LotsForRisk` / `QM_Entry` across 3,722 EA files** — every EA
routes sizing through the framework. `QM_RiskSizer.mqh` uses `OrderCalcProfit()` (:620),
`SYMBOL_TRADE_TICK_VALUE` (:372) and `SYMBOL_TRADE_TICK_SIZE` (:373), with a documented, *observable*
fallback for modes where `OrderCalcProfit` is unavailable.

**The sizer already does exactly what the directive asks for.** Now the arithmetic of the loss it is
blamed for: $3,864.50 over 4 trades is **$966 per trade on a $100k account = 0.97 %**. That is not a
2–4× oversize. That is four losing trades at a correctly-sized ~1 % risk budget.

**So the defect is the risk budget, not the sizing code** — and the directive's own §6 says so:
0.20–0.30 % per trade, at most 4 concurrent positions, ≤1.2 % simultaneous portfolio risk. Those are
rulepack and governor settings. Rewriting sizing code would replace a component that is already
correct and would invalidate the entire evidence base (§8) for no behavioural gain.

### 6.4 CONFIRMED in kind — cointegration on D1

The cointegration sleeves are D1: `QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1` and
`QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1` are sitting in the batch queue under exactly those names.
The consequences the directive draws — a 10–45 day mean-reversion horizon, 4–8 trades a year, density
near zero in a 60-day window — follow directly, and match the density measurement in §1.3 where the
low end of the distribution sits at 2–9 active days per 60.

The two sub-points are design work rather than defects: rolling hedge ratios instead of a frozen
in-sample beta, and atomic two-leg execution. On the second, `QM_BasketOrder.mqh` already exists with
`QM_BasketNormalizeLots` and a basket equity stop — the leg-atomicity work should start there rather
than from nothing.

## 7 · What the framework needs, and what it must not become

Three framework-level items follow. All three are **additive**; none rewrites a working component.

**F1 — a volatility-adaptive stop primitive.** `QM_StopRulesPipsToPriceDistance` exists and is used
fleet-wide. Add a sibling `QM_StopRulesAtrToPriceDistance(symbol, timeframe, period, multiple)` so an
EA can express "1.0 x ATR(14) of the M15 bar" as a first-class stop rule. Fixed-pip EAs then convert
by swapping one call instead of hand-rolling ATR per EA — which is how the fixed-pip class got into
1,000+ EAs in the first place.

**F2 — make session windows DST-explicit.** Not a new function; `QM_DSTAware` exists. What is missing
is that an EA can *silently* use broker time for a window that is conceptually anchored in London or
New York. The repair is a declared anchor: an EA states `SESSION_ANCHOR = UTC | BROKER |
EXCHANGE_LONDON | EXCHANGE_NY`, and the build gate rejects a session comparison that does not pass
through the matching conversion. That turns a silent wrong value into a build failure — the standing
rule *ein stiller Falschwert ist schlimmer als ein Fehlschlag*.

**F3 — wire the FTMO governor and give it the spread ceiling.** Both pieces exist (Part I §1.4). The
governor's `entry_daily_stop` / `liquidation_daily_stop` tiers already express the directive's
circuit breaker. The rollover spread block (directive §3.1, 21:30–23:30 GMT, no trade above ~1.8
pips) belongs in the governor policy as one more field, not as per-EA logic replicated 3,700 times.

**What the framework must not become:** a second sizing path. §6.3 shows the existing one is correct.

## 8 · The re-backtest question — the expensive part, and today's own data answers it

OWNER asks whether EAs must be re-backtested after a framework change. **Yes, and the scale is the
whole evidence base.** The reason is measured, not assumed, and it was measured today.

Batch (b), running right now, exists precisely because binaries changed underneath archived streams.
Its cohort C1 — pairs whose binary provably did **not** change — reproduced their streams **11 of 11
exactly, hash for hash**. Pairs whose binary **did** change did not:

| pair | trades before -> after |
|---|---|
| QM5_13036 / GDAXI | **1,352 -> 1,172** (13 % of trades gone) |
| QM5_13301 / GDAXI | same count, different content hash |
| QM5_13013 / NDX | 68 -> 70 |

And across 39 comparable re-runs, **8 verdicts flipped** — every one at the FAIL_SOFT boundary, 4 up
and 4 down.

A change to `QM_Common.mqh`, `QM_RiskSizer.mqh` or `QM_DSTAware.mqh` recompiles **every** EA that
includes it, effectively all 3,722. By the standing rule *ein Verdikt gilt nur unter dem Zustand,
unter dem es entstand*, every Q02–Q10 verdict would then rest on a binary that no longer exists.

### 8.1 The one experiment that decides the cost, and it is cheap

Everything above concerns changes that alter behaviour. The open question is narrower:

> **Does a behaviour-neutral recompile change the stream?**

If additive code behind a default-off flag leaves the executed path identical and the emitted stream
byte-identical, F1–F3 can land incrementally and only opted-in EAs need re-running. If the stream
changes regardless, every framework touch forces a full regeneration, and framework changes must be
**batched into a single release**.

*Pre-registered test, to run before any framework edit:* take one EA from the C1 cohort with a stable
binary and a known stream hash; add a no-op addition to a framework header; rebuild; re-run; compare
`portfolio_stream.content_sha256`.
*Predicted:* identical, because C1 shows the tester is bit-reproducible given the same executed path.
*Falsifier:* any difference — which would mean compilation-level differences propagate into
execution, and every framework change is a full-fleet event.

This is the highest-leverage measurement in the plan: it is the difference between "land F1–F3
incrementally" and "one batched framework release plus a re-foundation of Q02–Q10".

### 8.2 Sequencing that follows either way

1. **No framework edit while (b) is in flight.** (b) is measuring exactly this effect; editing the
   framework mid-batch would contaminate its own control. (b) stands at 50 of 78.
2. **Run the §8.1 experiment** the moment (b) lands — one rebuild, one backtest.
3. **Batch F1–F3 into one release** with a single regeneration wave rather than three.
4. **Repair the EAs against the new primitives** — 11450 (fixed pips -> ATR), 12539 plus the DST
   cohort, the D1 cointegration sleeves.
5. **Re-run the affected pairs** if §8.1 comes back identical; the whole fleet if it does not.

### 8.3 New EA versions, not in-place edits

For the four repair classes the right form is a **new EA version with a new id**, not an edit in
place. The old verdicts stay valid for the old binary, and the append-only rule plus the `supersedes`
relation shipped today can then state "v2 supersedes v1" honestly. Editing in place would silently
invalidate existing evidence with no record of it — the exact failure mode `supersedes` was built to
prevent. It also keeps the DXZ track intact while the FTMO track moves, which is the separation this
whole plan is about.

## 9 · What this closes, and what stays open

| item | state |
|---|---|
| FTMO governor client | **exists**, 5 includes / 0 calls -> P1 wires it, the build gate enforces it |
| FTMO spread calibration | **exists** with an artefact (2026-08-09) -> P3 reconciles it with the venue cost model |
| daily-loss gate | **absent**; its input `worst_day_1x` already exists -> P2 |
| same-day coupling check | **absent**; needs the 2.3 daily series -> P4 |
| behaviour-neutral recompile | **unknown** -> §8.1, the gating experiment |
| DST anchor discipline | 244 correct / 389 to classify -> F2 |
| adaptive stop primitive | absent -> F1 |
| sizing code | **already correct** — no work, and explicitly not to be rewritten |

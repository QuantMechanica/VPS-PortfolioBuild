# Fable ruling — FTMO Challenge campaign: STOP or CONTINUE

- Date: 2026-07-27
- Arbiter: Fable (binding on the recommendation that reaches OWNER, per OWNER's
  "if you disagree, Fable decides")
- Dispute: Codex (STOP) vs Claude (DO NOT STOP)
- Scope: read-only verification + this one document. No Factory OFF/ON; no
  work-item/queue/set/EA/T_Live changes.

## Decision

**STOP.** Close the FTMO campaign as a funded, capacity-reserving effort and
release its reserved factory capacity to the ordinary sleeve-supply / DarwinexZero
track. This is Codex's recommended action
(`docs/ops/evidence/2026-07-27_codex_ftmo_next_step_recommendation.md:8-11`).

I rule **against** Claude's "do not stop." But I adopt Claude's measurement as
correct and carry three of its findings into the close (below). This is not a
split: the action that reaches OWNER is Codex's close, and Claude's "keep the
campaign open" is rejected. The close is enriched with Claude's evidence because
that is what an honest close requires, not to hedge.

Confidence: **~80%.**

---

## 1. Verification of the load-bearing claim on each side

### (a) Does FTMO Phase 1 really have no time limit? — YES, verified first-party.

Claude's entire reframing rests on this. I did **not** rely on the repo's internal
assertion alone, because the repo's provenance for it is weak: the first-passage
doc attributes it to "Codex verified this against ftmo.com under task `9b7c6aaf`"
(`docs/ops/evidence/2026-07-27_ftmo_first_passage_measurement.md:15-17`), but the
committed `9b7c6aaf` artifact is a **margin/leverage** registry proposal and
contains **no** trading-period or inactivity statement
(`docs/ops/evidence/9b7c6aaf_ftmo_margin_registry_proposal_2026-07-27.md:1-96`).
The no-deadline claim appears only as a bare assertion in Claude-authored docs
(e.g. `docs/research/FTMO_MULTI_ACCOUNT_CAMPAIGN_2026-07-26.md:107`).

I verified it independently against first-party ftmo.com (I have web access on
this run): FTMO "introduced an unlimited trading period, eliminating the previous
30 or 60 calendar days," available for accounts purchased after the announcement;
"there is no time limit to reach the Profit Target." The **4-trading-day minimum
still applies** (a trading day = any day at least one position is opened). Sources:
- https://ftmo.com/en/blog/trade-without-any-time-limit-and-take-as-long-as-you-want-to-pass/
- https://academy.ftmo.com/lesson/minimum-trading-days/

**Conclusion:** Claude is right on the narrow point. Codex's 4.7% figure measures
`P(+10% within 22 trading days)` at forced 1x
(`tools/strategy_farm/portfolio/challenge_as_deployed.py:42-43`) — a rule FTMO no
longer enforces. Codex's headline number is a correct measurement of the wrong
rule. **The inactivity question is NOT resolved:** no first-party source I found
states a dormancy-breach rule for the evaluation, and the `9b7c6aaf` artifact has
none. The evidence leans against an inactivity breach ("take as long as you
want"), but this is not a definitive first-party quote, and it is load-bearing for
sleeve 13036 (below).

### (b) Is Claude's first-passage measurement sound, or does it leak like the three earlier errors? — SOUND, with one disclosed soft spot.

I read `tools/strategy_farm/portfolio/challenge_firstpassage.py` line by line and
re-ran it read-only. Findings:

- **Censoring is conservative, not survivor-biased.** Starts that reach end-of-data
  unresolved are counted as FAIL in every headline (`:227-234`, `:35-37`). Rates
  are lower bounds. Correct direction.
- **"At least one of N passes" is the legitimate campaign objective.** The campaign
  design is N parallel accounts, pass one. Pass = any account passes; book-fail =
  ALL accounts breach; otherwise censored (`:222-234`). This is the right event
  algebra for the stated campaign.
- **The selection-on-OOS worry is effectively void.** Stage 3 sorts all
  combinations by their OOS rate and reports the top (`:381-401`), which looks like
  scoring-period selection. But because "any account passes" is monotone in adding
  accounts, the full 4-sleeve book (N=4, the single combination, **no** selection)
  weakly dominates every smaller book and itself reads 88.3% in Claude's table
  (`2026-07-27_ftmo_first_passage_measurement.md:132`). The reported N=3 88.3% is
  not materially inflated over the no-choice N=4. So this is **not** a selection
  leak comparable to the earlier ones.
- **entry_time precondition is real and self-corrected.** Claude caught its own bug
  (missing entry_time treated as zero span → 12823/USDJPY wrongly admitted) and
  made coverage a precondition (`:134-141`). I verified on disk: the six streams
  Codex's review called empty have **100% entry_time coverage**, row counts
  matching exactly (10553 2615/2615, 10848 1344/1344, 13036 1352/1352, 13108
  553/553, 13213 1596/1596, 13301 551/551; plus 9936 1252/1252). **Codex's
  adversarial-review claim ("all six lack usable entry_time … actual rate 0/830")
  was an inverted presence test and is wrong.** Claude is right here.
- **Interval honesty.** ESS ≈ 12 (overlapping starts ÷ median resolution), Wald
  half-width ≈ 18pp, lower bound ≈ 70% (`:390-394`; doc `:147-150`). **No
  combination clears 0.80 on its lower bound.** Claude states this plainly.

**The one soft spot, and it is disclosed:** the "0.0% breach — fails by time not
ruin" headline hinges on sleeve **13036/GDAXI**, which at 1x is 84% censored solo
(too slow to resolve) (`:125`). Adding it to a book converts would-be breaches into
censoring, driving book-breach from 6.1% (2-account) to 0.0% (3-account). So "the
book doesn't blow up" is substantially the property "13036 barely trades." I
confirmed on disk: 13036 has a **279-calendar-day** max gap between trades with
three gaps >30d, versus 26-36d for its peers (9936, 13213, 13301). The 0% breach
rests on the one sleeve whose dormancy behaviour — and FTMO's treatment of it — is
unverified. Claude flags exactly this (`:157-163`).

- **Reproduced from committed code (this run).** `python challenge_firstpassage.py`
  reproduces Claude's headline exactly: preregistered 1x N=3 {13036, 13301, 9936}
  = 88.3% OOS, 0.0% breach, 11.7% censor, median 62 / p90 375, ESS 12, ±18%; N=4 =
  88.3%; N=2 {13301, 9936} = 85.2%, breach 6.1%. **Every campaign row prints `<`
  (point estimate only), not one prints `<<` (lower bound clears 0.80).** 4
  qualifying sleeves, 11 excluded on entry_time (incl. 12823), 52 on multi-day.

**Verdict on (b): the measurement is methodologically sound and does NOT contain a
hidden decisive defect of the kind that sank the three earlier numbers.** Its only
optimism is the disclosed 13036 dependence, plus a second-order, both-metrics leak
Claude did not re-flag here: sleeve pre-filtering uses full-history gate verdicts
that peek at the scoring period (named in the sibling doc
`FTMO_MULTI_ACCOUNT_CAMPAIGN_2026-07-26.md:347-350`; applies equally to 4.7% and
88.3%, so it does not move the comparison).

### Independent confirmations I ran (live, not quoted from either agent)

- **1% cap is real and unconditional:** `QM_Common.mqh:182`
  `QM_RiskSizerSetCapPct(1.0)`; override ceiling 5.0 at `:319`. Both agents agree,
  and Claude's leverage sweep shows P(pass) falls monotonically with size under
  barriers (`2026-07-27_ftmo_first_passage_measurement.md:93-101`) — the
  quantitative case for Codex's governance conclusion "do not raise caps."
- **The book is inadmissible — every qualifying sleeve is Q09 FAIL_PORTFOLIO.**
  Live DB query (`mode=ro`, this run): 9936 FAIL 06:27Z, 13213 FAIL 07-25, 10553
  FAIL 07-16, 10848 FAIL 07-14, 12823 FAIL 07-14, 13108 FAIL 07-22, 13036 FAIL
  07-26, **13301 FAIL 04:56Z (flipped from the "pending" state Claude's doc
  recorded)**; 10582 has no Q09 row (Q08 still pending). Admission is now
  unambiguous and worse than when either doc was written.
- **Sleeve supply is scarce:** 9 qualifying of 189 streams
  (`docs/ops/evidence/2026-07-27_sleeve_funnel_authoritative.md:25-34`); under the
  FTMO-strict contract only **2** of the 9 pass every gate (13036, 13301 — both
  GDAXI) (`:224-226`).

---

## 2. Why STOP wins even though Claude is factually right

The decision does not turn on the no-deadline point, for three reasons.

**(i) OWNER's target has a 30-day clock; the first-passage book cannot meet it.**
OWNER's stated goal is `P(pass) ≥ 0.80 within 30 days (~22 sessions)`
(`docs/research/GOAL_FTMO_PHASE1_P080.md:1,9`). Claude's first-passage book has a
**median 62 trading days** and **p90 375** (`2026-07-27_ftmo_first_passage_measurement.md:131`).
Within 22-30 days, `P(pass)` is still the sprint number (~5-13%), nowhere near
0.80. The 88.3% is obtained **only by discarding OWNER's 30-day box.** Claude's own
goal document says relaxing that box "is an OWNER decision, and it changes the goal
rather than the work" (`GOAL_FTMO_PHASE1_P080.md:145-148`). Fable cannot substitute
a relaxed target for the one OWNER set. Under the target as written, the campaign
fails — and Claude's same goal doc already concluded the pool is "one to two orders
of magnitude short, not twenty percent short" on speed (`:64-65,128-132`) and
recommended "do not buy a challenge account against the current book" (`:152`).

**(ii) Even under an unlimited target, no admissible, robust, ≥0.80-with-confidence
book exists today.** All qualifying sleeves are Q09 FAIL_PORTFOLIO (§1, live query).
Only 4 sleeves survive the first-passage preconditions and two are GDAXI. The
lower bound is ~70% — it does not clear 0.80. The 0% breach hinges on 13036's
unverified dormancy. ESS ≈ 12, drawn from a single 2022-2025 regime. This is a
plausible lottery ticket, not a defensible ≥0.80 book.

**(iii) "Continue" funds no actionable next step.** Both agents agree: no new
account (OWNER standing), no cap raise, and do not build the equity sampler / four
reruns (`codex_next_step:63-70`; Claude never proposes it). Claude's measurement is
already done (I re-ran it, read-only). Nothing remains that keeping the campaign
open would fund except reserved capacity — and the bottleneck both agents name,
admission + sleeve supply, is exactly what Codex's redirect serves
(`codex_next_step:38-43`; `sleeve_funnel_authoritative:25-34`).

So: the metric was wrong, but fixing it does not create an admissible book, does
not meet OWNER's deadline, and does not identify work that requires the campaign to
stay open. **Stop, and redirect capacity.**

## 3. What Claude's result changes about the close (carried forward, binding)

The close is a **park with a named reopen trigger**, not a "the book blows
up / 4.7% is the pass rate" kill. Specifically:

1. **Correct the record.** Do not cite 4.7% as "the FTMO pass rate." It is
   `P(+10% within 22 days at 1x)`. The campaign fails on **speed and admission**,
   and (under an unlimited horizon) by **time, not ruin** — a materially different
   and more accurate epitaph.
2. **Retire the 22-day sprint estimator as a decision basis; keep
   `challenge_firstpassage.py` as the correct instrument** for any future FTMO
   evaluation. It is committed and reproducible, unlike the ephemeral
   `scratchpad/parallel_accounts.py` the old numbers leaned on
   (`ftmo_campaign_state_after_remediation:156-159`).
3. **Do not raise the 1% cap.** Confirmed independently; leverage inverts under
   barriers. Both agents agree.
4. **Hand OWNER exactly one decision:** "FTMO now has no time limit (verified
   first-party). Do you want to relax the 30-day target to an unlimited horizon?"
   If yes, a future FTMO book re-enters through the normal pipeline on fresh
   evidence once three preconditions hold: (a) sleeves are Q09-admitted under a
   *separate-account* portfolio model (the campaign's own thesis is that shared-cap
   Q09 does not transfer to isolated accounts —
   `sleeve_funnel_authoritative:160-164` — but that is a pipeline decision, not a
   reason to reserve capacity now); (b) the FTMO inactivity/dormancy rule is
   verified first-party (load-bearing for 13036); (c) the qualifying pool exceeds 4
   sleeves and is less concentrated than 2-of-4 GDAXI.

## 4. The strongest point on the side I rule against

**Claude's strongest point: the campaign fails by *time*, not *ruin* (book breach
~0%), so stopping risks discarding a genuinely low-ruin, positive-EV option — a
patient book that, left to run under the real (unlimited) rule, plausibly passes
70-88% of the time without blowing up. If OWNER's true objective is funded capital
rather than speed, "stop" throws that away.**

I take this seriously and it is why the close is a park-with-trigger, not a kill.
My answer: (i) the ~0% breach is not a robust book property — it is 13036 barely
trading (84% censored solo, 279-day dormancy, inactivity treatment unverified);
remove 13036 and breach rises to 6.1% with heavier USDJPY concentration. (ii) The
option requires buying an account, which OWNER has forbidden and both agents
decline. (iii) The option is not available today regardless — every leg is Q09
FAIL_PORTFOLIO. So the value Claude wants to preserve is **preserved by the named
reopen trigger**, deferred to when its preconditions actually exist, which is a
strictly better use of scarce capacity than reserving it now for a ticket that
cannot be played. Nothing of value is discarded by stopping today.

## 5. Confidence and the single biggest thing that could make this wrong

**Confidence ~80%.**

The biggest thing that could flip it: if OWNER's real objective is "get funded,
speed irrelevant," **and** FTMO applies no inactivity breach during evaluation
(the evidence leans this way but I lack a definitive first-party dormancy quote),
**and** the separate-account Q09 argument is sound — then a patient 1x book is a
near-free option on funded capital, and "stop and redirect all capacity" slightly
under-invests; the right move would instead be to keep one thin reserved lane to
run it the moment an account is authorized. Even in that world the concrete next
steps are identical to the reopen trigger in §3 (verify inactivity, get
separate-account admission, broaden the pool), so the practical delta is small —
but it is the scenario a future OWNER note could legitimately use to reopen faster
than "compete as a fresh opportunity."

---

## Evidence index (every factual claim above)

- No time limit / 4-day minimum (first-party, verified this run):
  ftmo.com/en/blog/trade-without-any-time-limit-…, academy.ftmo.com/lesson/minimum-trading-days.
- 4.7% is the 22-day sprint at 1x: `challenge_as_deployed.py:42-43`.
- `9b7c6aaf` artifact is margin-only, no trading-period/inactivity clause:
  `9b7c6aaf_ftmo_margin_registry_proposal_2026-07-27.md`.
- First-passage code: `challenge_firstpassage.py` (censoring `:227-234`; event
  algebra `:222-234`; stage-3 selection `:381-401`; entry_time precondition
  `:134-141`; ESS `:390-394`).
- entry_time 100% coverage on disk: my read of
  `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/{10553,10848,13036,13108,13213,13301,9936}_*.jsonl`.
- 13036 279-day dormancy vs peers: my read of the same streams.
- 1% cap: `framework/include/QM/QM_Common.mqh:182,319`.
- All qualifying sleeves Q09 FAIL_PORTFOLIO: my live `mode=ro` query of
  `D:/QM/strategy_farm/state/farm_state.sqlite`.
- Sleeve supply 9/189, strict-2-of-9: `2026-07-27_sleeve_funnel_authoritative.md:25-34,224-226`.
- OWNER target 30 days / one-to-two-orders-short / "do not buy":
  `docs/research/GOAL_FTMO_PHASE1_P080.md:1,9,64-65,128-132,145-148,152`.
- Codex position: `2026-07-27_codex_ftmo_next_step_recommendation.md:8-11,38-43,63-70`.
- Claude position: `2026-07-27_ftmo_first_passage_measurement.md:131-163`.

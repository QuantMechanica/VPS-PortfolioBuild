# Funded-account book design — independent view (Sonnet)

- Date: 2026-07-27
- Author: Sonnet (independent third view, separate model instance; alongside Claude and Codex)
- Scope: read-only analysis + this one document. No Factory OFF/ON; no work-item / set /
  EA / queue / T_Live changes.
- Question (OWNER, translated): *"If we have a funded account, would it be good to switch
  to the same book as at Darwinex Zero — to continuously generate payouts every two weeks
  and keep the curve flat and inconspicuous?"*
- This is a **funded-phase design** question (assume Phase 1/2 already passed). It is not
  the "should we buy a challenge" question that the Fable ruling closed
  (`docs/ops/evidence/2026-07-27_fable_ruling_ftmo_campaign.md`).

## Bottom line (decisive)

**Yes to OWNER's instinct, with three modifications. Switch to a DXZ-derived book on the
funded account — not the challenge book — but (1) re-size it against FTMO's 10% total
floor (half of DXZ's 20%), (2) run a build-then-skim withdrawal policy, not
withdraw-everything-every-fortnight, and (3) reset the payout expectation: this is a
~7-8% CAGR grinder, so payouts are small and lumpy, not a rich biweekly income.**

The book you *pass* with (fast, concentrated, first-passage-optimised) is the wrong book
to *live* on. The book you live on wants diversification, low drawdown, and guaranteed
monthly activity — which is exactly what the DXZ book already is and the challenge book
is not. OWNER's "switch to the DXZ book" is the right move for the funded phase; it just
needs re-sizing for a floor that is half as deep.

## Facts I rely on (cited) and what I do NOT assume

Established / verified in-repo:

- **DXZ live book** (account 4000090541, live since 2026-07-19): 24 sleeves, per-sleeve
  cap 1.0%, capped-inverse-vol weighting, TOTAL_RISK 9.75% moving to 12.0%. Realized
  max-DD **2.59%–3.39%** over 2 028 days, worst day **−0.86% to −1.13%**, **0 days below
  −2%**, median **2** / p95 6 / max 11 of 24 sleeves active on the same day, CAGR
  **6.99%–8.43%** (`decisions/2026-07-24_dxz_total_risk_975_to_12.md:55-70,113`).
- **DXZ kill limits 5% daily / 20% total** vs **FTMO 5% daily / 10% total** — the total
  floor is **halved** (`decisions/2026-07-24_dxz_total_risk_975_to_12.md:41`).
- **1% per-trade cap** is wired unconditionally at `framework/include/QM/QM_Common.mqh:182`;
  override ceiling is (0, 5.0] and the code comment names 5.0 the "FTMO daily limit"
  hard ceiling (`:314,319`).
- **Challenge first-passage book** {13036, 13301, 9936}: 88.3% pass, 0.0% breach, median
  62 / p90 375 trading days, ESS≈12, ±18%
  (`docs/ops/evidence/2026-07-27_ftmo_first_passage_measurement.md:131`). Its 0% breach
  leans on **13036 barely trading** (84% censored solo, **279-day** max inter-trade gap,
  three gaps >30d) (`:125,160-163`).
- **No max trading period; 4-trading-day minimum applies** (Fable, first-party verified,
  `docs/ops/evidence/2026-07-27_fable_ruling_ftmo_campaign.md:44-46`).
- **The pool is slow**: best gate-surviving "speed" 0.96 vs a challenge book requirement
  of ~19; **speed is sizing-invariant** (`docs/research/GOAL_FTMO_PHASE1_P080.md:95,121-124`).
- Overnight share varies widely by sleeve: 13213 0.0%, 13301 0.1% vs 12969 99.3%, 10145
  92.0%, 12567/XAU 84.7% (`docs/research/GOAL_FTMO_PHASE1_P080.md:88-93`).

Deliberately NOT assumed (another agent is verifying FTMO rules; I answer conditionally):

- Whether the 10% max-loss floor is **static** (fixed below the initial balance) or
  **trails** the balance — I answer both cases in §2.
- The exact **profit-split %** and **payout schedule** — no first-party source in repo;
  I reason in terms of a share `s` and use OWNER's "biweekly" as the operating cadence.
- The exact **daily-loss reference** (balance vs equity, server-midnight) and any
  **news-window / dormancy** thresholds on the *funded* product. OWNER's direct
  experience — **blocked after 30 days idle** — is the operating assumption for §4.

---

## 1. Does the DXZ objective transfer to a funded FTMO account?

Partly. **The composition transfers; the objective does not.**

DXZ scoring rewards a smooth, low-drawdown, risk-adjusted curve as the *end product* —
that is how it attracts allocator capital. FTMO pays you a **profit share on realised
withdrawals**, subject to two hard floors, and does not score your Sharpe. Smoothness is
**terminal** on DXZ and **instrumental** on FTMO.

**Where they align (and align strongly):**

- **Low drawdown is rewarded by both.** The DXZ book's worst day (−1.1%) sits ~4.4× under
  the 5% daily floor and its 8-year max-DD (3.4%) sits ~3× under the 10% total floor. A
  book selected to score well on DXZ's drawdown-averse metric is, by construction, a book
  that almost never approaches FTMO's kill limits. This is the single biggest reason
  OWNER's instinct is right.
- **Decorrelation is rewarded by both** — it lowers variance for DXZ's score and shrinks
  the simultaneous-stop tail that threatens FTMO's floors.
- **Mechanical, non-martingale behaviour** is what both venues want (relevant to §3).

**Where they diverge (and where you must not port blindly):**

1. **The total floor is half.** DXZ sized 12% TOTAL_RISK against a 20% total kill — 8
   points of headroom. On FTMO the same 12% all-simultaneous tail sits only 2 points under
   the 10% kill. The *realized* worst day and max-DD are still comfortable, but the
   **design bound** (the pathological all-stop-out day) must respect 10%, not 20%. You
   cannot port the 12% sizing unchanged.
2. **DXZ over-pays for smoothness relative to what FTMO needs.** DXZ's capped-inverse-vol
   weighting sacrifices return (Sharpe −0.035 and concentration off the optimum,
   `decisions/2026-07-24_...:76`) to buy smoothness the *score* rewards. FTMO does not pay
   for smoothness beyond "stay safely off the floor." Because the DXZ book is already ~3×
   under the floor, the marginal smoothness it buys is return left on the table on FTMO —
   *if* you had higher-edge sleeves to redeploy that headroom into. (We don't — see the
   speed result — so this is a note, not an action today.)
3. **The daily-loss rule bites floating equity.** FTMO's daily loss is evaluated on
   *intraday floating equity* against a start-of-day reference. DXZ's −1.1% worst day is
   computed from **daily-close** portfolio streams (`decisions/2026-07-24_...:50-51`), which
   can understate the daily-loss risk of the **overnight-heavy** sleeves (12969 99.3% o/n,
   12567/XAU 84.7%) through gap risk. This is a reason the funded subset should tilt toward
   the flat-overnight sleeves (§5).

**Transfer verdict:** reuse the DXZ *diversification and low-DD character* — it is the
right skeleton — but re-derive the *sizing* against the 10% floor and treat the DXZ
*weighting* as a starting point, not gospel. The objective is now "maximise lifetime
withdrawals without breaching," not "maximise a smoothness score."

## 2. The withdrawal-versus-buffer trade-off

Claude is right that this is underrated, and the structural argument is correct: with a
**static** floor, every withdrawn dollar cuts the survival buffer dollar-for-dollar; a
never-withdraw account builds a growing cushion, a withdraw-everything account sits
permanently at minimum buffer and maximum ruin probability. But two features of *this*
book and *this* firm bound the danger and sharpen the policy.

**The objective is `E[Σ withdrawals until ruin]`, not early cash.** This is de Finetti's
optimal-dividend problem, and its classical solution is a **barrier strategy**: withdraw
nothing until surplus reaches a target `b*`, then skim everything above `b*`. Mapping
OWNER's three options:

- **Fixed fraction of profit** — suboptimal. It withdraws while the cushion is still thin,
  keeping ruin probability elevated exactly when the account is youngest and most valuable
  (longest expected remaining lifetime × all future payouts).
- **Withdraw only above a buffer threshold** — this *is* the optimal barrier form. Adopt it.
- **Ramp withdrawals as the cushion grows** — a smoothed barrier. Captures most of the
  value, is less bang-bang, and fits FTMO's biweekly cadence and OWNER's steady-payout
  preference. This is the practical implementation of the threshold policy.

**Two bounds specific to our case, both of which OWNER should know:**

- **FTMO already floors your buffer at 10%.** On a standard funded account you can only
  withdraw *profit above the initial balance* — you cannot draw down principal. So even the
  withdraw-all-profit policy leaves a permanent ~$10k buffer = **~3× this book's 8-year
  worst drawdown (3.4%)**. The "shrink the buffer to zero" nightmare requires drawing below
  principal, which the rule forbids. So the acute ruin risk in OWNER's premise is largely
  capped by FTMO's own structure.
- **For *this* book the marginal value of building beyond 10% is small but not zero.** A
  3.4%-max-DD book at a $10k buffer is comfortable. The cushion earns its keep only against
  the one thing an 8-year backtest cannot rule out: an **out-of-sample drawdown worse than
  history**, and a gap-driven daily-loss event on the overnight sleeves. That is real but
  second-order.

**Recommended policy (static floor):** a ramped barrier. First ~1–2 quarters, withdraw
*less* than full profit — build to ~$105k balance (a ~15% buffer above the floor, ~4× max
DD) while you accumulate out-of-sample confidence. Thereafter skim most profit above ~$102k,
holding a floor on withdrawals of ~$102k, never below $100k. **Avoid the policy in OWNER's
premise — withdraw everything every fortnight** — not because it is acutely dangerous for
this book, but because it maximises ruin probability for the *smallest possible* gain: an
8% book nets ~0.3% (~$320) in a median fortnight, and many fortnights net near zero or
negative, so a fixed biweekly skim buys almost nothing while permanently forfeiting the
cheap out-of-sample insurance.

**If the floor instead TRAILS the balance:** the trade-off largely dissolves and you should
withdraw **more** aggressively (toward full skim). If the floor keeps a constant gap below
equity, a cushion buys nothing against it, so there is no reason to hold profit back. If
instead FTMO moves the floor **up to breakeven after the first payout** (an FTMO-family
mechanic — *unverified, flag it*), the logic flips at the front: **take the first (small)
payout as soon as one exists** to lock the floor at your initial balance, after which the
firm's seed can never be lost and you can skim freely thereafter. The static case is the
only one where early restraint pays; verify which regime applies before setting the policy.

## 3. "Flat and inconspicuous," read charitably

Read as OWNER means it — a moderate-frequency diversified book is genuinely lower-variance
*and* less likely to trip a prop firm's restricted-practice rules. This is a portfolio-
structure question, **not** an appearance-management one. The variance reduction comes from
the structure; nothing here is about how trading is represented to FTMO, and I advise
nothing on that.

**What actually reduces variance:**

- **Diversification across uncorrelated symbols / timeframes / sessions** — the single
  biggest lever, already in place (24 sleeves, median 2 active/day, max 11).
- **Per-sleeve 1% cap + capped-inverse-vol weighting** — stops any one sleeve dominating
  the daily P&L, smoothing the curve and capping each position's daily-loss contribution.
- **Total-risk sizing against the 10% floor** — because FTMO's all-stop-out day is bounded
  by summed sleeve risk, keep the summed risk (not just realized DD) under 10% with margin.
  Given historical simultaneity peaks at 11 of 24, the true tail is well below the 12%
  nominal sum, but the *design bound* should still respect the halved floor: target
  TOTAL_RISK so the conservative all-simultaneous tail stays under ~8–9%.
- **Control gap risk** — keep the overnight-heavy sleeves from clustering their floating
  exposure into a single session; prefer flat-overnight sleeves where a choice exists (§1,§5).

**What keeps you clearly inside stated rules (all of which the DXZ book already satisfies):**

- **No martingale / grid / averaging-down.** V5 EAs are single-shot RISK_FIXED / RISK_PERCENT.
  Keep any grid experiment (e.g. the 20007 gold-ORB grid) **out** of the funded book.
- **No tick-scalping / sub-minute holds / latency arbitrage.** H1/D1 EAs holding
  minutes-to-days are inherently clear of the execution-exploitation restrictions.
- **Consistent position sizing** — the 1% cap enforces this; no sudden size spikes.
- **Keep the news filter ON** in the funded deployment so no sleeve opens/closes inside a
  restricted high-impact-news window (exact window is FTMO-account-type-specific — verify).
- **Do not engineer cross-account offsets.** Running the same mechanical book on DXZ *and*
  FTMO as independent long-edge deployments is ordinary strategy reuse. It must not be
  structured as hedged/offsetting positions between the two accounts, which is the thing
  prop firms restrict. These books are not a hedge pair, so this is fine — I flag it only so
  the deployment is never accidentally built that way.

The one thing NOT to do: deliberately suppress or round frequency/size to "look
inconspicuous." That neither reduces risk nor is needed — the risk reduction is entirely in
the portfolio structure.

## 4. The monthly-activity constraint

**This is the cleanest argument for the diversified book and against the challenge book.**

The failure mode is not any single sleeve going quiet — it is the **joint** gap: the
probability that *no* sleeve in the book fires within a 30-day window.

- The **DXZ book trades a median of 2 sleeves every day** over 2 028 days
  (`decisions/2026-07-24_...:70`). Its joint no-trade-in-30-days probability is effectively
  zero. It **cannot** trip a 30-day dormancy block. Safe for free.
- The **challenge book is not safe.** It leans on **13036/GDAXI**, whose 0% breach property
  *is* its 279-day dormancy (`..._first_passage_...:125,160-163`). The very feature that
  makes 13036 attractive for first-passage — it barely trades, so it rarely breaches — is
  the feature that **gets a funded account blocked for inactivity**. 13301 alone has a 36-day
  gap (one >30d); standalone it would trip the block once. Only a diversified book resolves
  this automatically.

**Implication for sleeve selection:** require the *book* (not each sleeve) to have a maximum
**joint** inter-trade gap comfortably under 30 days — target ≤ ~15 days for margin, measured
on the historical streams. Include a few genuinely day-active "heartbeat" sleeves (the DXZ
book has several) so monthly activity is guaranteed by construction. **Do not build a funded
book out of only low-frequency swing sleeves**, and do not add dormancy-driven sleeves like
13036. (Verify FTMO's exact dormancy definition first-party; the ≤15-day joint-gap design
has margin regardless of the precise threshold.)

## 5. Recommendation — which book

**A re-sized subset of the DXZ book. Not the challenge first-passage book. Not a
from-scratch book.**

1. **Start from the DXZ 24-sleeve composition.** It is diversified, low-DD, live-validated,
   and already satisfies §3 and §4 for free. Admissibility is not a blocker: unlike the
   campaign sleeves (Q09 `FAIL_PORTFOLIO` under a shared-cap model), the DXZ sleeves are a
   deployed, live portfolio.
2. **Re-size against the 10% floor.** Re-derive TOTAL_RISK so the conservative
   all-simultaneous tail sits under ~8–9% (not the 12% DXZ figure, which was set against a
   20% floor). Keep the 1% per-trade cap — the leverage-inverts result confirms not to raise
   it (`..._first_passage_...:104-110`).
3. **Trim toward daily-loss robustness.** Prefer the flat-overnight sleeves; be cautious with
   the heavily-overnight ones (12969, 12567/XAU, 10145) because FTMO's daily-loss rule bites
   floating equity and gaps. A modest subset (say ~15–20 of the 24, dropping the most
   gap-exposed and any that add correlation without diversification) may serve better than the
   full 24 on the funded objective — decide on the aligned daily streams, not by count.
4. **Pair with the ramped-barrier withdrawal policy** (§2): build to ~$105k first, then skim
   most profit above ~$102k; never the withdraw-everything-every-fortnight policy in OWNER's
   premise.
5. **Reset the payout expectation.** At ~7–8% CAGR the funded account produces on the order of
   $300–600 of *gross* profit in a median fortnight (before the split), lumpy and sometimes
   zero/negative — not a steady rich biweekly income. Its value is **survival + steady modest
   income + near-zero breach risk**, not large payouts. The lever for bigger payouts is
   **higher-edge (higher-speed) sleeves**, not the book choice or the withdrawal cadence — the
   GOAL doc's conclusion, and it stands (`GOAL_FTMO_PHASE1_P080.md:121-132`).

**Why not the challenge book:** it is built to *pass* (first passage to +10%), a different
objective from *living* on funded capital. Its 0% breach depends on 13036's dormancy — a
30-day-block liability on a funded account (§4). It is 2-of-3 GDAXI-concentrated (§3
variance). Use it, if anything, to pass; switch to the DXZ-derived book to live. That is
precisely OWNER's instinct — and it is correct, with the three modifications above.

## What would change this answer

- **If the floor trails / jumps to breakeven after first payout** (§2): withdraw aggressively
  instead of building a cushion, and take the first payout ASAP. Verify the regime first.
- **If FTMO's funded daily-loss or news-window rules are stricter than assumed** (§3): the
  overnight-heavy sleeves may need dropping, tightening the subset in step 3.
- **If a genuinely higher-speed, robust sleeve pool ever exists**: redeploy the large headroom
  under FTMO's floors into it — the current book leaves return on the table because it was
  built for a smoothness score, not for withdrawable profit (§1). That is a sourcing outcome,
  not a book-selection decision available today.

## Confidence

**~75%.** The composition/diversification recommendation and the §4 activity argument are
robust and evidence-backed. The §2 withdrawal policy is correct in form (de Finetti barrier)
but its quantitative sweet spot depends on the unverified static-vs-trailing floor and on the
profit-split %. The §1 "over-pays for smoothness" point is directionally right but only
actionable once a higher-edge pool exists. The single biggest thing that could move the
answer is the floor mechanic in §2.

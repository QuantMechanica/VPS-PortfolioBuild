# Adversarial review — single-account FTMO measurement (2026-07-27)

**Reviewer:** Claude (board-advisor worktree)
**Target:** `tools/strategy_farm/portfolio/challenge_single_account.py`
(built 2026-07-27 09:54), imports `challenge_book_60d.py` (commit `50cf7f5a4`,
its top-of-tree since revised by `12e3d0a08`).
**Mandate:** attack the measurement the way the last three errors on this problem
worked — a metric answering the wrong question, a scoring-period selection leak, and
a liquidation model that dropped a loss. Assume the same class until proven otherwise.
**Reproduction environment:** `Python311`, live read-only DB
`D:/QM/strategy_farm/state/farm_state.sqlite`, streams
`D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades` (192 files). Full run 90s,
exit 0.

---

## 0. Document provenance — one claim in the brief cannot be checked

The task instructed me to read
`docs/ops/evidence/2026-07-27_single_account_measurement.md`. **That file does not
exist** (`find . -iname "*single_account*"` returns only the `.py`; `git log` shows no
such path). There is no written measurement note to audit — only the script and its
docstring. This review therefore attacks the code and the docstring's prose claims
directly. The absence of the note is itself a gap: the headline is being circulated
(the task's MEASUREMENT STATE quotes it) with no committed evidence document behind it.
**Status of the note's existence: NOT ESTABLISHED.**

---

## 1. Reproduction (attack #5) — the headline number reproduces exactly

Ran the script unmodified. Result matches the brief's single-account headline to 0.1pp:

```
BEST SINGLE (IS-chosen): 9936:USDJPY@3x  ->  IS 30.5%  OOS 35.7%  breach 44%  med 33d
```

Probe (`challenge_book_60d.funded_flags("9936:USDJPY",(3.0,None,None))` + OOS slice):
OOS rate = **0.3574**, n(OOS) = **845**, window 2017-10-09..2025-12-30, 2111 trading
days, IS/OOS cut 2022-09-15 (1266 / 845). **The 35.7% is real and I reproduce it.**

**But the brief's supporting stats are mislabelled.** The brief (task MEASUREMENT
STATE) says "35.7% … median 34 days, breach 49%." The script's own OOS report says
**breach 44%, median 33d**. I traced the 49%/34 figures: they are the **full-sample
(IS+OOS)** numbers from the parent, not OOS:

```
parent full-sample breach = 0.492   median days (full, passers) = 34.0
IS-only breach = 0.524   OOS-only breach = 0.444   (script reports OOS)
```

So the circulated headline splices a full-sample breach/median onto an OOS pass rate.
The script itself is internally consistent (OOS 35.7 / 44 / 33); the **summary** mixes
windows. Not a code defect, but the number that reaches OWNER should read
**"35.7%, breach 44%, median 33d, OOS"** — not 49%/34.

The script's built-in reproduction guard (`challenge_single_account.py:279`) only
checks `sL == 3 and abs(rate-0.357) < 0.006`. It prints "MATCHES brief" while breach
(44 vs 49) and median (33 vs 34) disagree, because it never tests them. The guard is
weaker than it looks.

---

## 2. Attack #1 — SELECTION LEAK: **SURVIVES** (no leak of the fatal class), with one
residual optimism that IS/OOS does not neutralise

I traced every selection in code, not prose. Every configuration choice is made on the
IS slice and only reported on OOS:

- Leverage per sleeve: `challenge_single_account.py:257-262` iterates leverages, keeps
  the one maximising `rate_is(f)` (`:210`, sums over `IS`).
- Best single sleeve: `:269` `max(single, key=lambda k: single[k][1])` — index `[1]`
  is the IS rate.
- Multi pool + membership + budget B: `:292-294` pool filtered/sorted by IS rate;
  `:319-326` membership and B chosen by `rate_is`.
- Split tilt: `:366-372` chosen by `rate_is`.
- The 60/30 deadline (`challenge_book_60d.py:77`) and the 0.60 split (`:279-283`) are
  fixed constants, not tuned on scoring.

The verdict block (`:387-406`) compares two **already-IS-selected** configs on OOS and
calls a tie; it does not re-select on OOS. **The scoring period decides nothing.** This
is the exact opposite of the error that produced 90.2% two days ago.

Positive corroboration: for the headline sleeve, **OOS (35.7%) exceeds IS (30.5%)** and
OOS breach (44%) is *below* IS breach (52%). A config-selection leak inflates IS and
collapses OOS; here OOS is higher. The leak class is absent.

**Residual optimism (disclosed in spirit, not fully closed):** the 15-sleeve *universe*
(`challenge_book_60d.py:112-166`) is admitted using **full-history** gate verdicts
(Q02-Q08 read from the live DB) and a full-history `>=250` trading-day filter (`:161`,
`:83`). Sleeve *existence* therefore uses OOS-period survival. This is survivorship at
the universe level, not at the config level, so it does not create the 90.2%-class leak
and it applies identically to the 9.1% baseline — but it does mean absolute OOS levels
are conditioned on "sleeves that survived through 2025," a mild upward bias of unknown
size. The docstring is honest that leverage/membership/budget are IS-chosen; it is
silent that the *pool* is not. To fully close it you would need IS-only gate verdicts,
which the DB does not expose. **Flag, not a break.**

---

## 3. Attack #2 — SHARED-ACCOUNT MODEL: daily cap on concurrent sum is **CORRECT**;
one real interleaving infidelity; the self-check has a blind spot

**Concurrent exposure IS summed for the daily cap — SURVIVES.**
`build()` (`:113-134`) lays a per-day floating charge `fl[di] = Σ_members
floating[k][day]·weight[k]` and per-day close list `tr[di]`. `_phase` (`:149-150`)
tests `f = fl[di]·sc` against both caps: `eq + f <= CAP_T or f <= CAP_D`. Because
`floating[k][day]` is itself the sum of each open position's full adverse excursion
(`challenge_book_60d.py:181-188`), `f` is the summed worst-case excursion of **every
concurrently open position across all sleeves**, scaled by the per-sleeve budget. The
daily -5% and total -10% caps are applied to the coupled sum, exactly as a shared
account requires. The docstring's "B bounds worst-case aggregate exposure at 5x whether
one sleeve or five" (`:36-42`) checks out: at equal split `sc=B/|S|` and
`f = (B/|S|)·Σ excursion_k`, so aggregate worst-day charge scales with B, not with |S|.

**Realised P&L is summed, not dropped — SURVIVES (this is not the liquidation-drop bug).**
`:157-161` accumulates `realized += net·sc` across all same-day closes of all members
and breaches on the running sum. Losses are realised into `eq` (`:161`), not silently
skipped. The prior "dropped-loss" error class is absent here.

**FINDING (real, minor in magnitude): cross-sleeve trades within a day are ordered by
sleeve, not by time.** Intraday timestamps are discarded upstream — the stream loader
stores **dates only** (`challenge_book_60d.py:157`,
`(entry.date(), close.date(), net, mae)`). `build()` then appends `tr[di]` in
`sorted(members)` order (`:122-133`), so on a shared day the running daily-cap check
(`:157-161`) processes all of sleeve A's closes, then all of sleeve B's, in an order
that has nothing to do with when the trades actually closed. The daily-cap breach test
depends on the running sum, so a day whose true intraday path dips below -5% and
recovers (or vice versa) can be mis-classified. **Magnitude:** small for the actual
winners — the best shared book is 9936:USDJPY (0% multi-day) + 11063:USDJPY (28%), both
low-trade-count USDJPY sleeves where a single day rarely carries enough trades to cross
-5% and rebound. It cannot be bounded to zero, but it does not move the headline. The
same date-granularity limitation exists in the single-sleeve engine, so it does not
bias shared-vs-single.

**The self-check is weaker than advertised.** `:222-237` proves the coupled engine
reproduces the imported single-sleeve engine "bit-for-bit on every singleton" (75/75
configs — I confirmed it runs and passes). But a singleton exercises **none** of the
genuinely new code: cross-sleeve summation of `fl[di]` and cross-sleeve ordering of
`tr[di]`. The self-check validates the refactor, not the coupling. The one place a bug
could hide in the new arithmetic is precisely the place the self-check cannot see.
**Flag.**

**Pessimism direction is conservative and does not flatter shared.** Charging every
open position its full MAE on every open day (`challenge_book_60d.py:181-188`), then
also realising the net on the close day, over-penalises multi-day exposure. That biases
**against** the shared arm (and against multi-day sleeves generally). Since the verdict
is "shared ties/loses, favour single," this conservatism cannot be manufacturing the
conclusion — if anything it understates shared. **SURVIVES (as claimed).**

---

## 4. Attack #3 — CENSORING: counted as failure and disclosed; differential is small
and does not rescue either arm — **SURVIVES with caveat**

`_phase` returns `"censored"` when the loop exhausts `all_days` before the deadline is
even reachable (`:164`); `run` records it as a non-pass (`:179-181` p2, implicit p1).
`metrics` reports the share in its own `cens` column (`:196`). Disclosed, as the
docstring claims.

Decomposition for 9936@3x OOS: `p1_censored 36 + p2_censored 19 = 55 / 845 = 6.5%`
(shown as 7%). These are starts in the last ~60 calendar days of data that **cannot**
complete a 60-day phase; scoring them as failures **depresses** the rate. The true
completable-start rate is ~35.7%/(1-0.065) ≈ **38%** — i.e. the headline is
conservative by ~2-3pp on this axis, not inflated.

**Differential between arms:** `p1_censored` depends only on the shared `all_days`
window, so it is identical across arms. `p2_censored` depends on when phase 1 passes —
a busier multi-sleeve book passes P1 sooner and leaves more room for P2, so the shared
arm shows slightly **fewer** censored (5% vs 7%). That direction very mildly flatters
shared, but shared still ties/loses, so it changes nothing. **No censoring bias that
alters the comparison.**

---

## 5. Attack #4 — EFFECTIVE SAMPLE SIZE & CI: **this is the soft spot.** The reported
±18.8% uses the most generous defensible deflator; an equally defensible conservative
one roughly doubles it, and the decision-relevant lower bound then touches the baseline

The CI machinery (`:199-204`): `span = median(days-to-PASS among passers)`,
`ess = int(n / span)`, Wald `hw = 1.96·sqrt(p(1-p)/ess)`. Convention inherited from
`challenge_firstpassage.py:388-393`. For 9936@3x: n=845, passer-median span=33,
ESS=25, **hw=±18.8%**, CI [17.0%, 54.5%].

The problem is the choice of deflator. Overlapping daily starts decorrelate over the
horizon that **determines the outcome**, and **61% of attempts run through both phases**
(302 funded + 217 P2-fails of 845 reach phase 2), a horizon up to **60+30 = 90 calendar
days**. Using the passers-only median (33) is the *shortest* defensible block length,
hence the *largest* ESS and the *narrowest* CI. Recomputing with equally defensible
deflators:

```
deflator  ESS   ±95%     CI              basis
   33     25    ±18.8%   [17.0, 54.5]    passer-median  (code's choice)
   31     27    ±18.1%   [17.7, 53.8]    all-outcome median
   60     14    ±25.1%   [10.6, 60.8]    P1 deadline horizon
   90      9    ±31.3%   [ 4.4, 67.0]    full two-phase horizon
```

So the honest 95% **lower bound** on the 35.7% headline is not 17% — it is **~5-11%**,
which **overlaps the 9.1% no-leverage baseline.** The reported ±18.8% understates
uncertainty by roughly a factor of ~1.4-1.7x. (Note the all-outcome *median* is 31,
close to 33, because fast P1 breaches pull the median down; but the *variance* of an
overlapping-start mean is driven by the long-lived blocks, for which p90=61d and the
structural max is 90d are the right scale. The median is the wrong summary for a
variance deflator.)

**What this does and does not break:**

- The **shared-vs-single TIE verdict SURVIVES — and is over-determined.** OOS
  difference is -3.7pp against a pooled ±95% of ~38pp; widening the CI only makes the
  tie more emphatic. The measurement is simply **underpowered to distinguish shared
  from single** at all. Reporting them as different books is not warranted; they are
  indistinguishable.
- The claim that a single account is **materially and confidently above the baseline**
  does **NOT** survive at the fully conservative deflator. The "size helps under a
  deadline" thesis is nonetheless supported when tested cleanly (next section), so the
  point estimate is trustworthy as a central tendency; it is the **precision** that is
  oversold. OWNER should read 35.7% as "roughly a 1-in-3 shot, 95% band about
  [5%, 60%]," not as a firm 36%.

---

## 6. Cross-check I added — the size lever, tested cleanly on one sleeve

The brief's 9.1% baseline is a *four-sleeve OR book at 1x*, not a single sleeve, so it
is not a clean "size" contrast. I swept 9936 alone across leverage, OOS:

```
9936:USDJPY   1x OOS  4.0%  breach  4.5%
              2x OOS 29.9%  breach 27.1%
              3x OOS 35.7%  breach 44.4%   <- IS-chosen
              4x OOS 33.4%  breach 55.0%
              5x OOS  0.7%  breach 99.3%
```

Clean inverted-U: size buys deadline-reaching probability up to 3x, then ruin
dominates. The 3x-vs-1x gain is **+31.7pp**; significance depends on the same deflator:

```
deflator 33  z=3.10   deflator 60  z=2.30   deflator 90  z=1.88
```

**"Under a deadline, size raises P(pass)" SURVIVES** — clearly at moderate deflators,
borderline (z=1.88) at the maximally conservative one. This is the real content of the
single-account result: a lone account goes from **4% at 1x to 36% at 3x**, at the cost
of a **44% blow-up rate**. The 9.1% figure is a different book and should not be the
comparison anchor.

**Framing gap OWNER must see:** the 3x that maximises pass probability is also the
leverage at which **44% of attempts detonate** (hit -5% daily or -10% total). For "one
account at a time, real challenge fees," each detonation is a burned fee plus a restart.
The headline "35.7% pass" silently carries "44% ruin"; the two are the same
configuration. A pass-probability-maximising objective is not the same as a
fee-efficient one, and the measurement optimises only the former.

---

## 7. Selection instability (not a leak, but a fragility)

At Item 2 the "best shared book" is chosen by IS rate. N=2 wins at IS **37.0%**; N=4 is
IS **36.9%** — a **0.1pp** gap. But their OOS rates are **32.1%** (N=2) and **38.2%**
(N=4). A one-tenth-of-a-point IS difference flips the reported shared book by **6pp**
OOS. The IS objective surface is flat to within noise across memberships, so "the best
shared book is 2 sleeves" is an artifact of rounding, not a finding. It does not change
the verdict (the single sleeve's 35.7% beats the chosen shared 32.1% on OOS anyway),
but any statement of the form "N=k is the best shared size" is not supported.

---

## Verdict summary

| # | Attack | Result |
|---|--------|--------|
| 1 | Selection leak (config chosen on scoring window) | **SURVIVES** — all config choices on IS; OOS>IS corroborates. Residual: universe uses full-history gates (shared with baseline, mild). |
| 2 | Shared-account model — concurrent sum under daily cap | **CORRECT / SURVIVES**. Real minor infidelity: cross-sleeve intraday ordering (timestamps dropped to date). Self-check cannot validate the new coupling code. |
| 3 | Censoring counted & disclosed, non-differential | **SURVIVES** — counted as failure (conservative, ~2-3pp downward), disclosed, differential ~2pp favouring shared but immaterial. |
| 4 | ESS / CI defensible; conclusion at lower bound | **BREAKS on precision.** ±18.8% uses the most generous deflator; honest ±25-31%, lower bound ~5-11% overlaps the 9.1% baseline. TIE verdict survives (over-determined); "confidently above baseline" does not at the conservative bound. |
| 5 | Reproduce the headline | **REPRODUCED** at 35.7% OOS exactly. Brief's "breach 49% / med 34" are full-sample, not OOS (OOS: 44% / 33d); summary mislabels the window. |

**Not the three prior error classes.** No wrong-question metric (the KPI is the
challenge pass rate OWNER asked for), no scoring-period selection leak (traced clean),
no dropped-loss liquidation (losses are realised into equity). The one new-code hazard
is the cross-sleeve interleaving the self-check cannot reach, and it is small for the
actual winners.

**What OWNER should take away.** A single FTMO account, sized to the ratified 3x on the
best sleeve (9936:USDJPY), passes the 60/30 KPI with a **central estimate of ~36%**, a
**95% band of roughly [5%, 60%]**, and a **44% per-attempt blow-up rate**. Sharing the
account across several sleeves is **indistinguishable** from the single sleeve at this
sample size — the "favour the simpler single sleeve" call is correct but by default, not
by evidence of superiority. The genuine, defensible result is the size lever: **4% at
1x -> 36% at 3x**, significant at moderate deflators. The measurement is sound in
construction; it is **oversold in precision** and the headline should travel with its
blow-up rate attached.

# Filter Library — Plan

Date: 2026-05-22
Status: PROPOSED PLAN (awaiting OWNER go)
Author: Claude
Relates to: `docs/ops/EDGE_LAB_CHARTER_2026-05-22.md`

## Context

OWNER's idea: make **filters a first-class V5 framework concept** — a reusable
library of mechanical filters applicable to any strategy, to make a good
strategy better or rescue a marginal one. For every strategy, identify which
filters make sense, then test them.

The idea is half right and half dangerous. This plan keeps the right half and
fences off the dangerous half.

**The value (real):** good systems are *strategy + filters*. A regime filter, a
volatility filter, a session filter, a news blackout — legitimate, reusable,
mechanical components. The news-blackout filter is already mandatory. Making
filters first-class is a sound extension.

**The trap (must be guarded):** "make a bad strategy work with filters" is, in
statistics, one of the most reliable ways to **overfit**. A filter is a degree
of freedom. Search a filter library for the combination that turns a losing
backtest green and you will *always* find one in-sample — and it will not
generalise. This is exactly what Q05 (walk-forward), Q08 (crisis) and Q10
(PBO / deflated Sharpe) exist to kill. A filtered EA can pass P2/P3 in-sample
and then die at the robust gates — burning farm time and producing false hope.

Key distinction: a filter can **recover a strategy that has a real thesis but a
known, named weakness** (e.g. "breakouts whipsaw in chop"). A filter cannot
**create an edge where there is none** — if the unfiltered strategy is pure
noise, filtering only selects a lucky slice.

## The binding principle

A filter is legitimate ONLY when:

1. **Thesis-first.** It is applied because of a *named structural reason* — a
   known failure mode of the strategy — written down BEFORE the test.
2. **No filter search.** You do not try N filters and keep the winner. You
   hypothesise 1–3 filters per strategy from its failure mode, declare them,
   test them.
3. **Every variant counts.** Each filter on/off and each filter parameter is a
   degree of freedom. Filter variants are pre-declared in the card's variant
   family; the full count of variants tested is fed to Q10 so its PBO/DSR
   deflation sees the real multiple-testing.
4. **A filter cannot manufacture an edge** — see the distinction above.

## The honest test — "did the filter help?"

A filtered variant is accepted only if it beats the unfiltered variant on the
**robust gates** — Q05 walk-forward OOS, Q08 crisis slices, Q10 statistics —
**not** merely on P2/P3 in-sample. A filter that improves only the in-sample
curve is overfitting and is killed. That is the whole discipline in one
sentence.

## The Filter Library

Mechanical, deterministic, no-ML filter modules in the V5 framework. Initial set:

| Filter | Purpose | Typical use |
|---|---|---|
| News blackout | no entries/exits around high-impact events | mandatory, all EAs (FTMO) |
| Regime | rule-based bull/bear/sideways trend state | breakout, directional EAs |
| Volatility | ATR / realized-vol state; expansion vs compression | breakout, mean-reversion |
| Session / time-of-day | trade only declared hours | Silver Bullet, intraday |
| Higher-timeframe trend | entry only with HTF trend agreement | trend-following, directional |
| Spread / cost | skip when spread is abnormally wide | cost-sensitive EAs |
| Calendar | month-end / quarter-end / day-of-week | seasonal-flow EAs |

Each filter: documented purpose, ≤2–3 params, deterministic, **no ML**
(Hard Rule 14). The regime filter is the *rule-based* extraction of the Markov
idea — the Hidden Markov Model is forbidden.

## Per-strategy filter mapping (hypothesis-driven — examples)

| Strategy | Known failure mode | Candidate filter (declared, not searched) |
|---|---|---|
| Breakout EA | whipsaws in chop | regime (skip sideways) + volatility (need expansion) |
| Silver Bullet | timeframe / directional noise | session (inherent) + HTF-trend directional bias |
| X-sectional momentum (T1) | momentum crash at regime turns | volatility / turn filter (already in the T1 card) |
| Regime-filtered carry (T2) | carry crash in crises | the regime/vol filter *is* the thesis |

For every strategy entering the pipeline, the card declares its candidate
filters with a one-line thesis each.

## Framework integration

- Filter modules as reusable framework includes — mechanical, no-ML.
- The Strategy Card schema gains a `filters:` block — declared filters + a
  one-line thesis per filter.
- The setfile carries filter on/off + params.
- The pipeline's existing variant-family model handles filter-on vs filter-off
  as pre-declared variants — **no new gate semantics**.
- The mandatory news-blackout filter is formalised as the first library filter.

## Sequencing

1. **Now (cheap):** this plan + the core filter modules (news-blackout
   formalised, regime, volatility) + the card-schema `filters:` field. One
   bounded framework task.
2. **Per strategy:** as each strategy is built (Edge Lab + breakout/SB), its
   card declares 1–3 candidate filters with theses; the build produces
   filter-on / filter-off variants.
3. **Test:** filter variants run the normal Q00–Q14; accepted only if they beat
   the unfiltered variant on the robust gates.

This **rides alongside** the Edge Lab build — it is not a "drop everything"
workstream.

## Tasks (on OWNER go)

- **Codex:** build the core filter library (news-blackout, regime, volatility)
  as mechanical no-ML framework modules; add the card-schema `filters:` field.
- **Claude:** per-strategy filter mapping with theses; fold this into the Edge
  Lab charter as the filter discipline.
- Filter variants are tested through the standard pipeline; accepted on the
  robust-gate test above.

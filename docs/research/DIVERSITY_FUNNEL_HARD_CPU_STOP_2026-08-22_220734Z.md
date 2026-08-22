# Diversity funnel — hard CPU-ceiling stop

Date: 2026-08-22 UTC / 2026-08-23 Europe/Berlin

Branch: `agents/board-advisor`

Status: stopped before farm claim, EA mutation, smoke, or Q02 enqueue

## Outcome

The explicit backtest CPU ceiling bound during mandatory capacity preflight.
Five one-second whole-host samples were `100.0%`, `97.0%`, `100.0%`,
`100.0%`, and `100.0%`: average `99.4%`, maximum `100.0%`, above the
documented `97%` ceiling.

The path-anchored process sample found nine governed factory terminals
(`T1`–`T8` except `T9`, plus `T10`). `T_Live` and the FTMO terminal were
explicitly excluded. Two seconds later `farmctl mt5-slots` saw `T4` exit and
mapped the remaining eight terminals to eight distinct `Q09_NEWS` work items.
It reported no duplicate workers and no orphaned terminal processes. The fleet
was changing, but there was still no safe CPU headroom for the required
Model-4 build smoke.

Per the mission stop condition, no farm task or EA was claimed. No Strategy
Card, EA, registry, resolver, setfile, queue, priority, terminal, or work-item
state was changed, and no smoke/backtest was launched.

Machine-readable evidence is
`artifacts/diversity_funnel_hard_cpu_stop_20260822T220734Z_board_advisor.json`.

## Non-duplicate value

This observation is 109.7 minutes after the nearby `20:17:52Z` receipt. That
snapshot held one `Q07` plus eight `Q09_NEWS` rows. The current controller
snapshot mapped eight different work-item identities, all `Q09_NEWS`, after a
transient ninth terminal exited. The phase/identity mix therefore progressed
while saturation remained binding.

Read-only backlog triage also identified two eligible-looking diversity
frontiers for the next low-CPU wake, without claiming either:

- `QM5_34008_multicurrency-basket-dispersion-hedger` — seven-FX
  market-neutral dispersion package; build task
  `fa7ca587-77f8-4cea-b71b-7bb1b746b33d` was `TODO`.
- `QM5_37001_ernest-chan-ornstein-uhlenbeck-statarb` — reputable-source FX
  two-leg OU/stat-arb package; build task
  `92c3eb98-4998-40dc-b31a-8b2da987365e` was `TODO`.

Ownership and all preflight gates must be re-read after capacity clears; these
observations are not claims.

## Safety and workspace isolation

The shared worktree already contained 124 unrelated porcelain entries. They
were left untouched; this commit contains only this receipt and its JSON
evidence. No portfolio gate, deploy manifest, `T_Live` file, or AutoTrading
state was changed.

## Continuation

After sustained whole-host CPU is below `97%`, re-run ownership and build
preflight, atomically claim exactly one distinct diversity task, and prefer the
card-faithful market-neutral package with the cleanest current gates.

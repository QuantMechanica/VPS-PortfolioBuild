# Friday Smoke Claude 2026-05-22

Status: REVIEW
Router task: 5e827967-8f99-4db9-9b04-41744daa335f (review_strategy)
Agent: claude (re-enabled 2026-05-21; CLAUDE_DISABLED.flag absent)

## Smoke result

Claude router round-trip verified:

- `agent_router.py status` — claude shows `enabled: true`, `max_parallel: 3`.
- `agent_router.py enqueue-friday-smoke` — claude smoke task already open (idempotent).
- `agent_router.py list-tasks --agent claude` — IN_PROGRESS review_strategy task picked up.
- This artifact + `update-task --state REVIEW` is the durable return-channel proof.

Verdict: CLAUDE_ROUTER_SMOKE_READY

## Critique target: QM5_10260 cieslak-fomc-cycle-idx (flagship Profitability-Track lead)

Per role contract, Claude's contribution is adversarial pre-MT5 critique: explain how a
real-thesis candidate fails *before* terminal time is spent. The FOMC-cycle thesis is
genuine (Cieslak-Morse-Vissing-Jorgensen, JoF 2019, ~700 cites). The risks below are not
reasons to kill the card — they are reasons to fix the **promotion gate** and **test
design** so the pipeline does not green-light it for the wrong reason.

### R1 — Financing cost inverts the academic edge (highest-severity)

The academic premium is an **excess return over the risk-free rate** on cash equity
indices. QM5_10260 trades NDX.DWX / WS30.DWX **CFDs**, which pay (benchmark rate +
broker markup) as overnight financing on every long night held. A Mon-open→Fri-close hold
carries ~4 overnight swaps per even week. At a ~5% policy rate the carry drag is roughly
10-14 bp/week against a gross academic edge of ~50 bp/week — i.e. the strategy is
structurally **short exactly the risk-free rate the premium is measured over**. The card
and EDGE_BRIEF never mention financing. Action: verify the T1-T10 tester swap model for
NDX.DWX/WS30.DWX is broker-accurate *before* P2; a zero/wrong swap model will produce a
false-positive P2.

### R2 — P2 "profitable" gate passes on unconditional equity beta, not FOMC alpha

v1 is long-only, long ~50% of calendar time, flat otherwise. US indices roughly tripled
over the 2018-2026 backtest window. **Any** "long half the time" rule prints a profit
there. The card's stated P2 criterion ("P2 profitable") will therefore pass on pure beta
and hand the orchestrator a false lead. The only valid falsification is the
**even-week vs odd-week paired spread** within the same window (the card's own P3
long-even/short-odd variant + per-cycle-week PnL log). Recommendation: the P2 gate for
this card must require an even-vs-odd outperformance check, not raw net profit.

### R3 — Backtest window is fully out-of-sample vs the paper, and regime-thin

Paper sample: 1994-2016. QM data: ~2018-07→2026-05. ~192 even-week cycles sounds robust,
but the unit of independence is the **macro regime**, not the week — and 2018-2026 is
~5 regimes (2018 selloff, 2020 ZIRP/QE, 2021 melt-up, 2022 hiking bear, 2023-24 recovery).
The even-week effect is hypothesized via a Fed-liquidity / Fed-put mechanism; in the 2022
hiking cycle that mechanism was explicitly off. Expect the pattern to be weak or negative
in the 2022 slice. Q08 crisis slicing must isolate 2022, not just COVID 2020.

### R4 — Even-week alignment is a hidden researcher degree of freedom

FOMC inter-meeting gaps are uneven (5- and 8-week gaps both occur). `floor((t -
last_meeting)/7)` silently resolves the end-of-cycle labeling ambiguity one way; the
paper's t-stat depends on resolving it the paper's way (it actually emphasizes weeks
-1,0,2,4,6 with nuance on week -1). R2 is marked "PASS — pure calendar rule"; it is
mechanical but the *specific* mechanization is a choice the academic significance does
not automatically transfer to. P3 sweep should treat alignment as an explicit axis.

### R5 — `allow_fomc_hold` builds complexity to capture a decayed effect

The card overrides the V5 mandatory news filter (`allow_fomc_hold = TRUE`) specifically
to hold across the FOMC announcement and capture the Lucca-Moench pre-FOMC drift. The
EDGE_BRIEF itself states that drift "weakened or disappeared after 2015"
(Kurov-Wolfe-Gilbert 2021) — and the backtest window is entirely post-2015. Week 0 is the
riskiest hold (full rate-decision exposure) with the most-decayed edge. Test week-0 as a
*separable* component; excluding it may improve risk-adjusted return.

### R6 — Correlated universe inflates statistical confidence

NDX/WS30/SP500 are ~0.9+ correlated and the signal is identical across all three (same
FOMC calendar). It is effectively one strategy observed three times. Q04 cross-sectional
robustness and Q10 DSR/PBO must treat the 3 US indices as ~1 independent unit or they
overstate significance.

### R7 — Card vs queue scope drift (reconcile before P2 reads as evidence)

EDGE_BRIEF/card specify P2 on 3 US indices, D1 cycle-clock + M30 execution. Current
Operating State + PROFITABILITY_TRACK say Q02 is queued across **37 M15 DWX symbols**
(FX, metals, energy, indices). An FOMC US-equity-premium strategy has no thesis on
EURUSD/gold/oil — broad discovery is fine, but a chance profit on XTIUSD must not be
recorded as FOMC-cycle evidence. Also reconcile the M30(card) vs M15(queue) timeframe
mismatch.

## Recommended routing of these findings

- R1, R2 — gate/config fixes the orchestrator should apply **before** P2 promotion logic
  runs (swap-model verification; even-vs-odd P2 criterion). Highest leverage.
- R3, R4, R5, R6 — P3/P8/Q08/Q10 test-design notes; attach to the EA's pipeline payload.
- R7 — card/queue reconciliation; Documentation/Codex card-edit task.

None of these are kill criteria. The thesis is sound; the danger is a false-positive P2
that burns P3-P8 MT5 time on equity beta mislabeled as FOMC alpha.

---

## Cycle 2 (18:15Z) — critique target: QM5_10722 `edge-lab-t2-fx-filtered-carry`

Router task: 92e98d97-210a-4c7c-8e94-6668cdd55bcb (review_strategy, IN_PROGRESS).

`EDGE_CARD_SCREEN_2026-05-22.md` names QM5_10722 the **#1 recommended G0/build**
of the 27-card backlog and praised it as "swap-native, no external feed". That screen
was a *relative* merge/kill triage; it did not adversarially stress the card itself.
Before this card takes the first Edge Lab MT5 slot, the defects below must be answered.
Severity order, highest first.

### C1 — Static swap snapshot in the tester ≠ a historical carry signal (BLOCKER)

The card ranks currencies by broker `SYMBOL_SWAP_LONG / SYMBOL_SWAP_SHORT` and the
implementation notes mandate "log swap values used at signal time so backtest evidence
can be audited." But in the MT5 strategy tester `SymbolInfoInteger(...,SYMBOL_SWAP_*)`
returns the broker's **current** swap configuration — there is no historical swap series
on a 2018→2026 backtest. Every weekly rebalance in the entire backtest would rank using
**one constant 2026 swap table** (post-hiking: USD/GBP high-carry, JPY/CHF deeply
negative). Applying today's rate regime to the 2020-2021 ZIRP slice is a structural
anachronism — the signal cannot have known in 2021 what 2026 swaps would be. `r3_data_
available` is marked PASS; on this point it is effectively FAIL. The card's own
falsification has a "rework, not kill, if broker swap fields are inconsistent across
tester runs" branch — that branch is the *expected* path, not the edge case. Action:
before G0 approval, settle the carry-history source (a documented rate-differential
series, or accept that v1 can only ever be a constant-ranking strategy and re-scope it
as such). This is the single thing that determines whether the card is buildable.

### C2 — The swap-dominance falsification kills the strategy for being carry

Falsification bullet 3: "Kill if gross profit is dominated by swap accrual while price
PnL is persistently negative." For a carry strategy that is the **definition of working**
— carry *is* earning the swap/rate differential; the price leg is the crash-risk cost
you accept to collect it. As written this criterion either (a) kills a correctly
functioning carry EA, or (b) gets silently waived at P2, which corrupts the evidence
trail. Re-spec the real kill: price PnL must not be *catastrophically* negative (e.g.
the swap carry must survive a stressed-cost re-pricing), not "swap must not dominate."

### C3 — One position at a time discards the cross-sectional premium

The thesis is *cross-sectional* carry, whose academic premium is a **diversified**
high-basket vs low-basket return. The card trades "one position at a time… one selected
carry expression." That collapses a diversified factor into a single idiosyncratic pair
bet — one central-bank surprise on that one pair is the whole strategy's PnL.
Diversification is QM's stated win mechanism (mission baseline). Either trade a small
basket (top-2 vs bottom-2, as QM5_10717 already does) or rename the card honestly as a
single best-carry-pair tactic — but do not market a one-pair bet as the carry *factor*.

### C4 — Trade count too low for a Q08 crash-slice verdict

`expected_trades_per_year_per_symbol: 12` counts rebalances, but a carry rank is stable
for months and only one pair is held — realistic position *changes* are ~4-8/yr. Over a
regime-thin 2018-2026 window the carry-crash sample is a handful of events. The card's
headline falsification ("filtered carry must materially reduce Q08 DD vs a naked-carry
control") cannot reach significance on that sample — the same statistical-power problem
the screen used to **KILL** QM5_10890 and downgrade QM5_10767. Triage consistency
demands QM5_10722 carry an explicit "Q08 verdict is low-power, treat as directional not
confirmatory" caveat, or the build order is internally inconsistent.

### C5 — P3 grid tunes the filter on the same tiny sample (Q10 exposure)

The card is honest that "the filter is the thing under test", then sweeps 3×3×3 = 27
filter combinations (vol percentile, adverse-return veto, carry threshold) — plus the
equity-proxy and gold conditions are *fixed* ad-hoc, not swept, so they are unaudited
researcher choices. Tuning 27 combos against ~4-8 trades/yr is a textbook PBO/DSR
failure setup. Q10 should be run with the filter parameters held at a single
pre-registered value, and the sweep treated as sensitivity analysis only.

### C6 — Gap risk vs the FTMO daily-loss limit

A `1.6*ATR(14,D1)` hard stop does not protect against a weekend / central-bank-surprise
gap — the defining carry-crash mechanism. 0.25% per-trade risk helps, but a 3-4% adverse
overnight gap on a leveraged FX position is plausible and can breach an FTMO **daily**
loss limit in one print, before the 6.5% strategy-disable ever triggers. The FTMO block
claims compliance; Q08 must include an explicit overnight-gap stress (not just realized
drawdown) before the compliance claim is evidence-backed.

### Verdict

QM5_10722 should **not** be the #1 build until C1 is resolved — a constant-ranking
backtest is not evidence for a time-varying carry thesis. C2 (mis-specified
falsification) and C3 (single-pair, no diversification) are card-edit fixes that should
land at G0. C4-C6 are P3/Q08/Q10 test-design notes to attach to the pipeline payload.
Recommend the build order in `EDGE_CARD_SCREEN` be reordered so **QM5_10717**
(xsec momentum — price-derived signal, genuinely multi-pair, no swap-history dependency)
leads, and QM5_10722 follows only after the carry-history source is settled.

Verdict: CLAUDE_SMOKE_CYCLE2_DONE — QM5_10722 demoted from #1 build pending C1.

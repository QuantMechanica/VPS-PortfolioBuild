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

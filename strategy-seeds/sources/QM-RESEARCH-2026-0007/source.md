---
source_id: QM-RESEARCH-2026-0007
title: "TAIL_RISK Family A: bounded positive pyramid on cash-session index trend (H-PY; session-flat H1)"
source_type: internal_research
source_author: Kimi
source_model: kimi-code/kimi-for-coding
created: 2026-09-16
originating_task_id: TAIL_RISK-FAMILY-A-20260916
status: preregistered
parent_source_ids: ["QM-RESEARCH-2026-0002"]
source_artifact: QM-RESEARCH://2026-0007
---

# TAIL_RISK Family A: bounded positive pyramid on cash-session index trend (H-PY; session-flat H1)

## Research provenance
First TAIL_RISK programme candidate (Family A — bounded positive pyramiding),
authored by Kimi (research role, offline) under the interim OWNER delegation of
2026-09-15/16, per `docs/research/TAIL_RISK_PROGRAMME_2026-09-16.md` §4 and the
machine-readable Family A bounds in `tools/strategy_farm/config/tail_risk_families.v1.json`
(3 levels, progression 1.0/0.75/0.5, aggregate <= 2.25 legs, <= 5% margin,
never-widening trailing basket stop, hard 0.5% equity adverse bound OR 50% of
peak open basket profit giveback, whichever first). The base entry reuses the
H-CW session-flat envelope (`strategy-seeds/sources/QM-RESEARCH-2026-0002/H_CW_card.md`,
QM5_41475): same cash-session opening-range breakout on NDX/GDAXI/SP500 H1, same
shock/spread/news filter class, same flatten hour and -1.0%/-2.0% breakers.
H-PY layers the Family A pyramid on top: adds only behind +1.0/+2.0 ATR of open
profit AND new favourable extremes, so exposure concentrates only where the tape
has confirmed direction. Offline statistical instruments were used in research
only (directive sec41); every rule is fully mechanical with no runtime model
(directive sec42/sec51). Numeric provenance: every quantitative claim resolves to
the manifest-backed computed outputs `mechanization_result.json` (MECHANIZE gate
PASS, 25 bounded parameters, zero findings, codex_implementable=true) and
`h_py_pilot.json` (deterministic fire count of the exact preregistered rules over
a read-only Dukascopy USATECHIDXUSD tick feed, 2018-2020 in-sample, labelled
PILOT_MOTIVATION_NOT_PROOF). The pilot records 6.4 baskets/month over 29 months
with raw PF(R) 1.26 at +0.12R/basket, level-2 reach 11.9%, level-3 reach 0%,
15% giveback-stopped before level 2 — IN-SAMPLE, ZERO-COST, SINGLE-FEED
feasibility motivation only (at/above the bar in-sample raises overfitting risk,
not evidence); the governed Q00-Q17 pipeline on farm .DWX data is the judge.
Cross-vendor critic: PENDING (review_status REVIEW_PENDING; claude disabled
until 2026-09-17, codex on hold until 2026-09-19, agy quota-dead) — see
critic_receipt.json (skeleton, non-passing by design until the critic seat runs).

## Structural cause
Equity-index CFDs exhibit persistent intraday order flow during the cash-session
overlap. When the session opening range breaks and holds the breakout side of a
short intraday EMA, the directional flow that funded the break frequently
persists for hours — long enough to pay a trailed pyramid, and long enough that
a giveback stop at 50% of peak open basket profit monetizes the fat right tail of
those sessions. The mechanism is convexity, not prediction: each add requires an
ATR-scaled open profit AND a new favourable extreme, so the position is largest
exactly when the session trend has confirmed itself; the never-widening basket
stop converts parabolic reversals into small realised givebacks. The session-flat
envelope (flat by 20 UTC) removes the overnight gap and swap tails — precisely
the tail a built-out basket fears most, and precisely the tail that produced the
-10.26% FTMO demo breach (overnight/swap on carried positions).

## Candidate edge (mechanizable)
See H_PY_card.md — bounded positive pyramid on the cash-session index trend:
H-CW base leg, levels 2/3 at +1.0/+2.0 ATR with new favourable extremes
(1.0/0.75/0.5), never-widening basket stop (breakeven-plus after level 2, then
1.0x ATR trail), 50% giveback stop, 0.5% equity adverse bound, one basket per
symbol per day, session-flat, daily -1.0% / weekly -2.0% breakers, H-CW-class
shock/spread/news filters. It passes the mechanization gate (finite bounded
parameters, no runtime model, no external feed; mechanization_result.json).
Positive pyramiding is NOT tail-amplifying (STRATEGY_ELIGIBILITY_V2 §9); the
full Family A risk contract is carried in the card for programme uniformity and
for the joint-tail engine's declared bounds, and validates against the machine
gate (validate_contract: no errors; is_unbounded: false).

## Findings (pilot, not tradeable proof)
The exact preregistered rules on the NDX-class proxy feed (2018-2020): 489
evaluated session days, 154 shock-skipped at 3.0x, 187 gross signals, 185 taken
baskets, 29 months covered — 6.4 baskets/month, ~6.4 active days/month; exits
73 base stops, 37 giveback stops, 75 session-flat flattens; level 2 filled in
11.9% of baskets, level 3 in 0% (the proxy feed never printed a second
qualifying extreme — the level-3 leg is untested even at pilot level); raw
PF(R) 1.26 at +0.12R/basket, average peak open basket profit +0.77R, maximum
+19.1R. Honest pilot measurements for density calibration and feasibility only;
the H-CW sibling's Q10 motivation does not transfer to H-PY, and the in-sample
window calibrated the shock floor (13:00 bar range median ~2.8x ATR -> floor
3.0), so the 2021-2024 holdout must re-derive it blind.

## Numeric provenance
Every figure above resolves to `h_py_pilot.json` (sha256 in the source
manifest); the mechanization verdict resolves to `mechanization_result.json`
(sha256 in the source manifest). No figure is LLM-computed.

## Source manifest

```qm-source-manifest
# Auto-generated by research_source.seal; do not hand-edit.
research.json:             31e68bbbe50a4af0bf54b2e4b2c0901a7d5f2fb11ed6ae7b49ccac960a3ea602
lineage.json:              21953934ab2c0035d4a24f369baa1e02f24792e51088740c2b0e6ae001b87c94
critic_receipt.json:       529e8710554d85fac62d435853a1c03f01bb3170f7efbc283a06b49d698cec14
mechanization_result.json: 816cf3986d08ff0def53199be0f652de6604735f0cea1e0fde6ad5a29082659a
h_py_pilot.json:           12b3eec3a15fc8b5421b8f59aade9a4aaed5858c5e7c8a7419570671f1f5639d
```

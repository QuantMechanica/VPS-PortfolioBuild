---
source_id: QM-RESEARCH-2026-0008
title: "TAIL_RISK Family A: bounded two-level pyramid on cash-session index trend (H-PY2L; session-flat H1)"
source_type: internal_research
source_author: Kimi
source_model: kimi-code/kimi-for-coding
created: 2026-09-16
originating_task_id: TAIL_RISK-FAMILY-A-HPY2L-20260916
status: preregistered
parent_source_ids: ["QM-RESEARCH-2026-0007"]
source_artifact: QM-RESEARCH://2026-0008
---

# TAIL_RISK Family A: bounded two-level pyramid on cash-session index trend (H-PY2L; session-flat H1)

## Research provenance
Variant lineage of H-PY (QM-RESEARCH-2026-0007, QM5_41479), minted under the
interim OWNER delegation of 2026-09-15/16 per
`docs/research/TAIL_RISK_PROGRAMME_2026-09-16.md` §4 and the machine-readable
Family A bounds in `tools/strategy_farm/config/tail_risk_families.v1.json`.
The parent card carried the Family A 3-level envelope (progression 1.0/0.75/0.5,
aggregate ≤ 2.25 legs); its pilot filled level 2 in 11.9% of baskets and level 3
in 0%. The post-pilot L3 root-cause analysis
(`QM-RESEARCH-2026-0007/ANALYSIS.md`, labelled ANALYSIS_NOT_PREREGISTERED,
in-sample 2018-2020 only, holdout untouched) proved the third level is
structurally unreachable inside the session-flat envelope: entries fill at
17:00-18:00 UTC, the earliest level-2 fill is the 19:00 bar, adds may not fill
into the flatten-hour bar (20:00), and a third level may only trigger on a bar
strictly after the level-2 fill — the level-3 trigger's price condition was met
on 13 of 22 level-2 baskets and the fill was mechanically excluded every time,
and single-rule counterfactuals disabling the giveback stop, the trail ratchet,
the time stop, or the flatten exit all still produce zero level-3 fills. The
correct design response is the family contract's own tightening clause: this
variant reduces `max_levels` 3 → 2 and the progression 1.0/0.75/0.5 → 1.0/0.75
(aggregate cap 2.25 → 1.75 legs) and removes the level-3 machinery
(`add3_trigger_atr`, `level3_size_mult`). Nothing is widened; every other rule
is identical to the frozen 0007 card. Offline statistical instruments were used
in research only (directive sec41); every rule is fully mechanical with no
runtime model (directive sec42/sec51). Numeric provenance: every quantitative
claim resolves to the manifest-backed computed outputs
`mechanization_result.json` (MECHANIZE gate PASS, 23 bounded parameters, zero
findings, codex_implementable=true) and `h_py2l_pilot.json` (deterministic fire
count of the exact preregistered two-level rules over a read-only Dukascopy
USATECHIDXUSD tick feed, 2018-2020 in-sample, labelled
PILOT_MOTIVATION_NOT_PROOF). The pilot reproduces the parent 0007 pilot's
realized path exactly (parent consistency check inside the JSON, all_match):
6.4 baskets/month over 29 months with raw PF(R) 1.26 at +0.12R/basket,
level-2 reach 11.9%, giveback-before-level-2 15.1% — IN-SAMPLE, ZERO-COST,
SINGLE-FEED feasibility motivation only; the governed Q00-Q17 pipeline on
farm .DWX data is the judge. Cross-vendor critic: PENDING (review_status
REVIEW_PENDING; claude disabled until 2026-09-17, codex on hold until
2026-09-19, agy quota-dead) — see critic_receipt.json (skeleton, non-passing
by design until the critic seat runs).

## Structural cause
Equity-index CFDs exhibit persistent intraday order flow during the cash-session
overlap. When the session opening range breaks and holds the breakout side of a
short intraday EMA, the directional flow that funded the break frequently
persists for hours — long enough to pay a trailed pyramid, and long enough that
a giveback stop at 50% of peak open basket profit monetizes the fat right tail
of those sessions. The mechanism is convexity, not prediction: the add requires
an ATR-scaled open profit AND a new favourable extreme, so exposure concentrates
only where the tape has confirmed direction; the never-widening basket stop
converts parabolic reversals into small realised givebacks. The session-flat
envelope (flat by 20 UTC) removes the overnight gap and swap tails — precisely
the tail that produced the -10.26% FTMO demo breach (overnight/swap on carried
positions). The two-level form is the honest shape of the mechanism inside that
envelope: the session clock leaves room for exactly one add.

## Candidate edge (mechanizable)
See H_PY2L_card.md — bounded two-level pyramid on the cash-session index trend:
H-CW base leg, one add at +1.0 ATR with a new favourable extreme (1.0/0.75,
aggregate ≤ 1.75 legs), never-widening basket stop (breakeven-plus after the
add, then 1.0x ATR trail), 50% giveback stop, 0.5% equity adverse bound, one
basket per symbol per day, session-flat, daily -1.0% / weekly -2.0% breakers,
H-CW-class shock/spread/news filters. It passes the mechanization gate (finite
bounded parameters, no runtime model, no external feed;
mechanization_result.json). Positive pyramiding is NOT tail-amplifying
(STRATEGY_ELIGIBILITY_V2 §9); the full risk contract is carried in the card for
programme uniformity and for the joint-tail engine's declared bounds, and
validates against the machine gate (validate_contract: no errors;
is_unbounded: false).

## Findings (pilot, not tradeable proof)
The exact preregistered two-level rules on the NDX-class proxy feed
(2018-2020): 489 evaluated session days, 154 shock-skipped at 3.0x, 187 gross
signals, 185 taken baskets, 29 months covered — 6.4 baskets/month, ~6.4 active
days/month; exits 73 base stops, 37 giveback stops, 75 session-flat flattens;
level 2 filled in 11.9% of baskets; raw PF(R) 1.26 at +0.12R/basket, average
peak open basket profit +0.77R, maximum +19.1R. All figures equal the parent
0007 pilot because the parent's third level never filled (consistency check
all_match in h_py2l_pilot.json). Honest pilot measurements for density
calibration and feasibility only; the in-sample window calibrated the shock
floor (13:00 bar range median ~2.8x ATR -> floor 3.0), so the 2021-2024 holdout
must re-derive it blind.

## Numeric provenance
Every figure above resolves to `h_py2l_pilot.json` (sha256 in the source
manifest); the mechanization verdict resolves to `mechanization_result.json`
(sha256 in the source manifest). No figure is LLM-computed.

## Source manifest

```qm-source-manifest
# Auto-generated by research_source.seal; do not hand-edit.
research.json:             0dbfdd97948a08744a766619000129846dfec4d6d49b06bd90ccb72e16800afc
lineage.json:              ca7f7ceca8c837416ca31fcfd77643f0cd583844523481f3efab448bd8d74bda
critic_receipt.json:       529e8710554d85fac62d435853a1c03f01bb3170f7efbc283a06b49d698cec14
mechanization_result.json: 2f8ca44acf724f53ac560762a854556e0550abd363ddf48dd2d3a3b3122e2674
h_py2l_pilot.json:         5182b64f874d8ff144f8cdcbf2a8622c559e4112cb5aeb13c2301e781d6b0b74
```

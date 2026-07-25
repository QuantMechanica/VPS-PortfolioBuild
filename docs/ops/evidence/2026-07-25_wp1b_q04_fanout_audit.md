# WP-1b — grid→Q04 fan-out policy audit

Built by Opus (Claude side) per the plan's REVISION 2, replacing the withdrawn WP-1. Read-only
throughout (`mode=ro`, DB snapshot 2026-07-25T13:00Z); no gate, cap, setfile or DB row changed.
Codex review pending (Claude-built → Codex reviews).

## Verdict in one line

The Q04 fan-out is a **policy accident relative to the pipeline's own original design** — Q03 was
meant to plateau-select one setfile and hand Q04 a single winner, but production Q03 does no
selection, so the entire unselected setfile grid brute-forces Q04. The largest component (the
`synth` explosion) is near-pure waste; the smaller `ablation` component is bounded and marginally
productive. Both the correct fix (wire the plateau runner) and the interim fix (cap the promotion)
change what gets tested and are therefore OWNER decisions.

## 1. Fan-out quantified

Q04: 5 519 (ea, symbol) pairs, 15 172 rows. Median rows/pair **1**, p90 = 2, p99 = 55, max **387**
(QM5_10042/AUDUSD). 787 multi-setfile pairs carry **10 440 rows = 68.8 % of all Q04 work**;
4 732 pairs have exactly one row. The distribution is bimodal: a cluster at 50–57 rows (~111
pairs, a recurring ~56-variant grid) plus 6 runaway pairs (165–387).

**Q03→Q04 is a strict 1:1 mirror.** 5 410 of 5 519 pairs have rowcount == distinct setfiles; the
exceptions are retries (fewer setfiles than rows), never expansion. Headline pair: Q03 387 rows /
387 setfiles → Q04 387/387, intersection 387, Q04-only 0. The grid is injected at **Q02→Q03**
(10042/AUDUSD: P2 42 → Q02 7 → **Q03 387** → Q04 387).

## 2. The promotion code

- `farmctl.py:10973` cascade map `"Q03": "Q04"`; promotion loop `:11005-11073` inserts one Q04 row
  per passing Q03 setfile. The `LIMIT 10` at `:11021` is a per-tick throttle, not a bound. **No cap,
  no cross-setfile selection.**
- `farmctl.py:130-133`: production Q03 runner is `p3_param_sweep.py` ("unchanged behaviour,
  phase-tag renamed"). **`q03_plateau_runner.py` — the one runner that cross-selects a plateau
  median (`evaluate_grid` → single `selected_index`, `:981-1026`) — is referenced nowhere in the
  dispatch path.**
- Q04's own CLI expects a single pre-selected setfile: `q04_walkforward.py:19/:1056` `--params
  <plateau_pick.json>`, help text "Q03 plateau-median setfile to use across all folds". The runner
  was designed to receive one winner; it receives all N because nothing upstream selects.

Selection is therefore implicit and **disjunctive**: a pair advances to Q05 if *any* of its N
independent Q04 verdicts passes (confirmed: all 244/467 pairs with ≥1 Q04 pass reached Q05, zero
exceptions). More setfiles = more uncorrected chances — the exact multiple-comparisons hazard the
N_eff/DSR doctrine exists to prevent, applied with no correction.

## 3. Cost and yield

Q04 ≈ 45 k fold-backtests total (3 folds/row); the fan-out excess over one-canonical-per-pair is
**~29 k fold-backtests**, plus ~10 k non-canonical Q03 runs upstream.

| variant | Q04 rows | passes | yield |
|---|---:|---|---|
| `synth` | 1 334 | **1** (0.075 %) | that one (QM5_10026/SP500) died at Q07. **Zero survivors past Q07 from the entire synthetic program.** |
| `ablation` | 1 959 | ~200 incl. SOFT/LOWFREQ | ~59 pairs reached Q05 *only* via an ablation variant — real but uncorrected, selection-by-luck admissions |
| base/canonical | 11 879 | ~596 | 353 of 467 Q05 promotions carried by the base setfile alone — the fan-out added nothing for them |

QM5_10042/AUDUSD, the 387-row pair: **every row FAIL/INFRA_FAIL, zero reached Q05.**

## 4. Containment nuance — the standing path does NOT produce the grid

`_find_ea_setfiles` (`farmctl.py:11813`) matches only canonical `_{period}_backtest.set` names.
Only 1 of 10042's 387 Q03 setfiles matches; globally 10 230 of 12 619 Q03 rows and 9 565 of 15 172
Q04 rows are non-canonical names the standing globber would never pick. The grid arrived via
**separate bulk `synth`/`ablation` injection waves**, and the uncapped 1:1 cascade then propagated
everything downstream. The exact injection tool could not be identified read-only from the DB —
the one open item.

## 5. Recommendation (OWNER-gated where marked)

1. **Permanent (= Track C / C3, OWNER):** wire `q03_plateau_runner.py` into Q03 dispatch so the
   grid is plateau-selected to one median setfile before Q04. This is the design the code was built
   for; it dissolves the fan-out at source.
2. **Interim cap (OWNER):** at the cascade (`farmctl.py:11005`): promote the canonical setfile plus
   at most top-N ablation variants by Q03 PF (suggest N ≤ 3); stop promoting `synth` setfiles
   entirely (0 survivors past Q07). A cap belongs at the promotion policy — never behind a
   uniqueness constraint.
3. **Operational, within standing authority:** launch no new bulk `synth`/`ablation` injection
   waves. Goes into the Factory_ON runbook note.

Both (1) and (2) change what gets tested (they would drop the ~59 ablation-carried and 1
synth-carried Q05 admissions), hence OWNER decisions per the Track C boundary.

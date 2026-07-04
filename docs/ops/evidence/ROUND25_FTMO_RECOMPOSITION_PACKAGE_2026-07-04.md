# Round25 — FTMO 2-Step Recomposition Package (2026-07-04, late night)

**Status: CANDIDATE COMPOSITION — full-fidelity confirmed; OWNER decision pending (Q12-class).**

## Headline

A from-scratch greedy recomposition over all 49 validated candidate reports beats the
Round24 champion decisively at identical simulation fidelity (5000 runs × 5 seeds,
FTMO_2STEP preset, block_days 5, 60-day phase horizon, 100k account):

| Metric | Round24 (13 legs @ 5.9) | **Round25 seed_ii (12 legs @ 9.0)** | Delta |
|---|---|---|---|
| min robust pass probability | 57.04% | **67.72%** | **+10.68pp** |
| mean robust pass probability | 57.78% | **68.19%** | +10.41pp |
| max max-loss breach prob | 4.96% | **4.24%** | −0.72pp |
| max daily-loss breach prob | 0.00% | **0.00%** | = |
| mean target-not-reached prob | 38.04% | **28.00%** | −10.04pp |

Round24 was guard-saturated (4.96/5.00) — the 2026-07-04 interim sweep proved lead+1
additions structurally cannot admit (31 screens: 0 ADMIT). Round25 spreads risk across
more-orthogonal legs at a higher total scale: better coverage AND more guard headroom.

## The composition (seed_ii final lead, risk scale 9.0)

| Leg | Weight | Source basis |
|---|---|---|
| QM5_10911:GDAXI.DWX H1 grimes-complex-pb | 0.1396 | round31 fresh (141 tr, PF 1.41, DD 4.4%) |
| QM5_12958:XAUUSD.DWX D1 nnfx-hma-wae-swing | 0.1396 | round31 fresh (72 tr, PF 2.05) |
| QM5_10848:XAUUSD.DWX | 0.0931 | Round24 member report |
| QM5_10692:NDX.DWX H1 tv-ls-ms | 0.1241 | validation_round10 |
| QM5_10847:GBPUSD.DWX | 0.0432 | Round24 member report |
| QM5_10163:NDX.DWX | 0.0469 | Round24 member report |
| QM5_10440:NDX.DWX H1 mql5-ohlc-mtf | 0.0510 | validation_round12 |
| QM5_11476:USDJPY.DWX H1 | 0.1594 | validation_round6 (775 tr q08-basis) |
| QM5_10700:XAUUSD.DWX | 0.0693 | Round24 member report |
| QM5_12475:NDX.DWX | 0.0361 | Round24 member report |
| QM5_10286:XTIUSD.DWX D1 | 0.0576 | Round24 member report |
| QM5_12990:GBPUSD.DWX H4 grimes-context-pb-v2 | 0.0400 | round31 fresh (exit-surgery v2) |

New vs Round24: GDAXI enters the book (10911), plus 12958, 10692, 10440, 11476, 12990.
Dropped vs Round24: 10951, 10375, 10702, 10988, 10194, 9936, 10113/10712-class legs.
Overlap with the live DXZ S3 book: 10911, 10692, 10440 (FTMO = separate account; overlap
is capital-efficiency, not correlation risk between accounts).

## Method + evidence chain (all tool-conformant)

- Simulation exclusively via `prop_challenge_optimizer.py --screen-candidate` (report.htm
  basis; the 2026-06-30 basis lesson honored — zero reimplemented sim math).
- Greedy driver (3 independent seed restarts; scratchpad `round25_greedy_driver.py`)
  synthesized lead artifacts per round; adaptive weight menus; scales 5.0–9.0 (extended
  after the first run stalled at the 6.5 ceiling with unconverted guard headroom).
- Convergence cross-check: seed_iii (11 legs, triage 71%) independently selected nearly
  the same core (10911, 12958, 10848, 10692, 10847, 12475 + 12989/10700/10467/10132) —
  the composition is not a seed artifact.
- Full-fidelity confirm artifact:
  `D:\QM\strategy_farm\artifacts\portfolio\round25_recompose_20260704\fullfidelity_confirm_seed_ii_12leg.json`
  (lead = `seed_ii_gdaxi10911\round_14\lead.json` + 12990 @ 0.04, scales 8.5/9.0/9.5,
  runs 5000, seeds 0–4; selected summary quoted above).
- All per-round screen artifacts + progress.jsonl under
  `D:\QM\strategy_farm\artifacts\portfolio\round25_recompose_20260704\`.

## Caveats (honest list)

1. **Same-data optimization:** legs and weights were selected on the same 2023–2025
   report set the confirm runs on. The +10.7pp is in-sample composition edge; per-leg
   edges themselves carry independent pipeline evidence (Q02–Q08), but the WEIGHTS are
   fitted. Mitigation options: seed-holdout confirm (different seeds — done, 5 seeds),
   block-bootstrap already randomizes sequencing; a stricter OOS split (compose on
   2023–2024, confirm on 2025) is possible follow-up work.
2. **Scale 9.0 semantics:** risk scale multiplies the validation-run sizing; translation
   into per-EA RISK_FIXED for a real 100k FTMO account needs the deployment math from
   the scale8_equiv convention (PROP_CHALLENGE_MT5_VALIDATION doc) before any live use.
3. 12990 is an exit-surgery v2 with only 34 trades (2023–2025) on its fresh report —
   smallest evidence base in the book; its weight is correspondingly small (0.04).
4. Q04-class cost realism: validation reports run the canonical backtest sets (real
   Darwinex commission schedule); no additional cost stress applied at composition level.

## Recommended next steps

1. OWNER reviews this package (after the Sunday chart session — no rush, challenge
   start is a money decision).
2. Optional hardening before decision: OOS-split confirm (compose 2023–24 / confirm 25)
   + per-leg RISK_FIXED translation table for a real FTMO 100k.
3. Prop-slate EAs (12985/12986/12988, Q02 in flight) and future exit-surgery v2s get
   screened against THIS bar (67.72) going forward, not Round24.

## Sign-off

- Composition + evidence: Claude, 2026-07-04 (token-burn wave, OWNER-directed)
- Decision: _pending OWNER_

# 11708 marginal-LCB sign change — reconciliation (OWNER 2026-09-21 FINAL MEGA PROMPT §V)

- **Question:** the 2026-09-18 alt-roster analysis reported EURUSD QM5_11708 as a NEGATIVE marginal (financed full-sample LCB
  0.8839 → 0.8556 when added), the 2026-09-21 account-level simulator (Codex `e5c49db2`) reports +0.020 LCB (0.7435 → 0.7635,
  `CONSIDER_ADD`). OWNER §V: explain the sign change before any roster action uses 11708, classify
  `EXPECTED_MODEL_IMPROVEMENT` vs `SIMULATOR_DEFECT`.
- **Method of this reconciliation:** the new engine (`tools/strategy_farm/ftmo/book_sim.py`, unchanged) was re-run on the
  SAME roster variants under BOTH input-stream sets (unfinanced `snapshot_r2` = the 09-21 run; financed
  `deployable2/streams_fin_full` = the 09-18 run) and under BOTH parameter sets (new: 504-bd horizon / 20-day blocks; old:
  1008-bd horizon / 10-day blocks / 10,000 paths / seed 20260915), plus seed replicates to measure the bootstrap noise of the LCB.
  All 71 run files with SHA256SUMS are under `runs/`; rosters carry the stream sha256 they were bound to. Read-only, 0 factory
  hours, ~2 minutes CPU.

## 1. The seven §V fields

| Field | OLD (2026-09-18, `FTMO_ALT_ROSTER_DEPLOYABLE2_2026-09-18.md`) | NEW (2026-09-21, `2026-09-21_ftmo_book_sim_v1`) |
|---|---|---|
| OLD_METHOD / NEW_METHOD | `first_passage.py` v2 directly on per-sleeve daily P/L (risk-scaled), MAE-proxy intraday low, **all-active intersection window of the roster** (so the D2g window ends 2025-06-05 where 11910's stream ends, D2g6's ends 2025-11-21) | `book_sim.py` account path (Prague-midnight balance anchor, simultaneous active-MAE envelope, commission re-costed from the registry) → same `first_passage.py` sampler; **fixed common window 2019-01-22..2025-11-21 for base and variant** |
| INPUT_STREAM_DIFFERENCE | **financed** streams (`qm_financing.financing_usd` folded into swap/net; 11708 net financing +32.95 USD over 173 trades, a small carry earner; XAU sleeves pay) | **unfinanced** `snapshot_r2` streams (swap ≈ 0) — `financing_lib.py` is absent from the checkout, run labelled `PRIMARY_FINANCING_TABLE_MISSING_STREAM_EMBEDDED_SWAP_FALLBACK` |
| RISK_WEIGHT_DIFFERENCE | 11708 added **jointly with 11910** at 0.3125 % each (+0.625 % book risk, D2g = 2.34375 %) | 11708 added **alone** at 0.3125 % (2.03125 %), full 0.0625–0.5 % grid |
| DEPENDENCE_MODEL_DIFFERENCE | per-sleeve daily P/L summed — dependence enters only through the shared calendar blocks | same block sampler; additionally simultaneous open-risk envelope per day (more conservative intraday low) |
| FIRST_PASSAGE_DIFFERENCE | 10,000 paths, 1008 bd, 10-day blocks, seed 20260915 | base 5,000 paths / 1008 bd / 20-day blocks; **marginal deltas 1,000 paths / 504 bd / 20-day blocks**, seed 20260921 |
| WHY_SIGN_CHANGED | see §2 | see §2 |
| Classification | — | **`EXPECTED_MODEL_IMPROVEMENT` for the method, but the +0.020 is NOT a resolved positive (§3)** |

## 2. What actually changed the sign

Same engine, same rosters, both stream sets, both parameter sets (LCB = `P_FIRST_NET_FTMO_PAYOUT_LCB`; max-loss = bootstrap
max-loss breach probability; DD = historical max drawdown USD; full table in `runs/summary.json`):

| Roster | streams | params | LCB | Δ vs D2g6 | max-loss | DD USD | trades/bd | USD/bd | cost USD/bd |
|---|---|---|---|---|---|---|---|---|---|
| D2g6 | financed | old (10k/1008/b10) | **0.8798** | — | 0.0190 | 6262 | 1.336 | 27.50 | 12.61 |
| D2g6 + 11708 | financed | old | 0.8814 | **+0.0016** | 0.0182 | 6220 | 1.420 | 27.92 | 12.71 |
| D2g6 + 11421 | financed | old | 0.8779 | −0.0019 | 0.0197 | 6842 | 1.382 | 27.78 | 12.91 |
| D2g6 + 11910 | financed | old | 0.8120 | **−0.0678** | 0.0324 | 6926 | 1.370 | 24.57 | 13.02 |
| D2g (= + 11708 + 11910) | financed | old | 0.8739 | −0.0059 | 0.0212 | 6884 | 1.456 | 25.39 | 13.12 |
| D2g6 | unfinanced | old | 0.9299 | — | 0.0068 | 5787 | 1.336 | 34.69 | 5.42 |
| D2g6 + 11708 | unfinanced | old | 0.9360 | +0.0061 | 0.0055 | 5783 | 1.420 | 35.15 | 5.48 |
| D2g6 + 11910 | unfinanced | old | 0.8998 | −0.0301 | 0.0106 | 6443 | 1.370 | 32.03 | 5.56 |
| D2g (joint) | unfinanced | old | 0.9379 | +0.0080 | 0.0081 | 6439 | 1.456 | 32.89 | 5.62 |
| D2g6 | financed | new (5k/504/b20) | 0.6314 | — | 0.0156 | 6262 | | | |
| D2g6 + 11708 | financed | new | 0.6432 | +0.0118 | 0.0142 | 6220 | | | |
| D2g6 + 11421 | financed | new | 0.6194 | −0.0120 | 0.0178 | 6842 | | | |
| D2g6 + 11910 | financed | new | 0.5558 | −0.0756 | 0.0282 | 6926 | | | |
| D2g6 | unfinanced | new | 0.7680 | — | 0.0062 | 5787 | | | |
| D2g6 + 11708 | unfinanced | new | 0.7790 | +0.0110 | 0.0050 | 5783 | | | |

1. **The engine reproduces the old number when fed the old inputs.** D2g6 on financed streams at the old parameters gives
   0.8798 against the 09-18 figure 0.8839 (Δ 0.004; the old run used the intersection window, the new engine the fixed window).
   `book_sim.py` is therefore not a different truth; the differences are inputs and parameters.
2. **The old −0.028 was a JOINT add whose negative belongs to 11910, not 11708.** Financed, old parameters: 11910 alone
   −0.068 LCB, +664 USD DD, max-loss breach ×1.7; 11708 alone +0.002. Joint D2g −0.006. The 09-18 doc's own line
   "the two replacements do not pay for their own risk" was true of the pair; attributing it to 11708 was the error.
3. **The old D2g comparison used a shorter window than D2g6** (intersection rule: 11910's stream ends 2025-06-05, so D2g lost
   2025-06..11 where D2g6 earns). The new engine's fixed common window removes that asymmetry — an expected improvement.
4. **The new +0.020 is unfinanced.** Financing is not a detail for this book: D2g6 financed vs unfinanced = 0.8798 vs 0.9299
   at the old parameters (Δ −0.050), cost drag 5.4 → 12.6 USD/bd, expected progress 34.7 → 27.5 USD/bd. The 09-21 state JSON
   headline (LCB 0.9194) is therefore optimistic by roughly 0.04–0.05. (The financed base re-run of the canonical state is
   in `docs/ops/evidence/2026-09-21_ftmo_book_sim_v1_financed/`.)

## 3. Resolution: the marginal engine cannot see a 0.02 delta at 1,000 paths

Seed replicates of the LCB (same roster, same window, seeds 1..5):

| Roster | streams / paths | LCB per seed | mean | SD |
|---|---|---|---|---|
| D2g6 | unfin / 1000 | 0.768 0.779 0.759 0.757 0.759 | 0.7644 | 0.0082 |
| D2g6 + 11708 | unfin / 1000 | 0.737 0.7645 0.7535 0.789 0.7835 | 0.7655 | 0.0191 |
| D2g6 + 11421 | unfin / 1000 | 0.780 0.7945 0.7535 0.757 0.7395 | 0.7649 | 0.0197 |
| D2g6 + 11910 | unfin / 1000 | 0.709 0.699 0.708 0.7145 0.720 | 0.7101 | 0.0070 |
| D2g6 | fin / 5000 (3 seeds) | 0.6422 0.6632 0.6438 | 0.6497 | 0.0095 |
| D2g6 + 11708 | fin / 5000 (3 seeds) | 0.644 0.6592 0.6592 | 0.6541 | 0.0072 |
| D2g6 + 11421 | fin / 5000 (3 seeds) | 0.6506 0.6632 0.6358 | 0.6499 | 0.0112 |
| D2g6 + 11910 | fin / 5000 (3 seeds) | 0.5634 0.5758 0.5514 | 0.5635 | 0.0100 |

The seed-to-seed SD of the LCB is 0.007–0.020 at 1,000 paths and 0.007–0.018 at 5,000 paths. Every 11708 and 11421 delta
reported anywhere (|Δ| ≤ 0.02) is inside one to two SDs of that noise: **11708's marginal LCB is not distinguishable from
zero** (seed-mean Δ +0.001 unfinanced, +0.004 financed). 11910 is resolved negative in every configuration (−0.04 to −0.08,
DD +650 USD, breach probability ×1.7–2). 11421 is neutral on LCB and adds ~580 USD of drawdown and 0.2 USD/bd cost.

## 4. Verdict and book actions

- **`11708_SIGN_FLIP = EXPLAINED / EXPECTED_MODEL_IMPROVEMENT`** (method) — the old negative was a joint-add + window
  artefact; the engine is consistent with the old engine on identical inputs. **No `SIMULATOR_DEFECT`** in the account path.
- **But the +0.020 `CONSIDER_ADD` is withdrawn as a number:** the true marginal is ≈ 0 (+0.00 to +0.01) with +6 % trade density,
  no DD change and a 0.001 lower max-loss breach. Under §F candidate actions: **11708 → `SHADOW_BOOK`** (neutral-to-slightly
  positive, cheap, genuine FX diversification; not `ADD_NOW`, not `QUEUE_FOR_NEXT_DEMO` for Sunday unless a resolved
  ≥ +0.01 financed delta at ≥ 5,000 paths appears). **11421 → `HOLD`** (neutral LCB, more drawdown, more cost).
  **11910 → `REJECT` for the FTMO book** (resolved negative). 10513 stays `HOLD` (Codex −0.029; no financed stream on disk).
- **Simulator-confidence follow-ups (OWNER §U.5), commissioned to Codex:** (a) financed inputs as the default (financing table
  or the 09-18 financed stream generation), (b) seed-replicate SE / minimum-resolvable-delta reporting on every marginal
  table, (c) the fixed-window rule documented against the intersection rule, (d) the canonical state re-run on financed streams.
- **Roster consequence for Sunday 2026-09-27:** none of 11708 / 11421 / 11910 / 10513 earns a place on the evidence; the
  Sunday incumbent stays the six D2g6 sleeves unless the kill-switch fix or the demo retro-audit changes a sleeve's standing.

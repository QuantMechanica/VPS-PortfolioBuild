# FTMO_BOOK account simulator — financed re-run of the D2g6 base (Fable, 2026-09-21 18:2xZ)

Why: the Codex `e5c49db2` base run (`../2026-09-21_ftmo_book_sim_v1/`) is UNFINANCED — `tools/strategy_farm/swap/financing_lib.py` is absent
from the checkout and the `snapshot_r2` streams carry swap ≈ 0 — so its headline (LCB 0.9194) is optimistic by ~0.05 for an XAU-heavy roster
(reconciliation `../2026-09-21_ftmo_11708_sign_change_reconciliation/README.md` §2.4). This re-run feeds the same engine
(`tools/strategy_farm/ftmo/book_sim.py`, unchanged) with the financed 2026-09-18 streams, in which `qm_financing.financing_usd` is already
folded into `swap` and `net` per trade (verified row-by-row for 11708: OVERNIGHT trade swap 0.25 = financing_usd 0.2499; raw snapshot swap 2.35).

| Item | Value |
|---|---|
| Roster | `d2g6_roster_financed.json` (six sleeves, 1.71875 %, stream paths → `deployable2/streams_fin_full/QM/q08_trades`, sha256 re-bound) |
| Candidate plan | `candidate_plan_financed.json` (11708, 11910, 11421 add; 41219/10403/10700 leave-one-out; 10513 dropped — no financed stream) |
| Command | `book_sim.py --n-paths 5000 --marginal-n-paths 1000 --horizon 1008 --marginal-horizon 504 --block-len 20 --seed 20260921` |
| Window | 2019-01-22..2025-11-21 (1,784 bd) |
| Outputs | `book_sim_d2g6_financed.json`, `marginal_contribution_financed.json`, `FTMO_BOOK_DEPENDENCE_MATRIX_financed.{json,md}`, replicates `rep_seed{11,12,13}_{base,marginal}.json` (marginal 5,000 paths / 504 bd), state snapshot `ftmo_book_current.json` (byte-identical to `D:/QM/reports/state/ftmo_book_current.json` at 18:21:50Z) |

## Headline (financed)

| Metric | Value |
|---|---|
| P_FIRST_NET_FTMO_PAYOUT_LCB / P | **0.8668** / 0.8854 |
| P_CHALLENGE_PASS / P_VERIFICATION_PASS given challenge / P_survive_to_first_reward | 0.9516 / 0.9775 / 0.9518 |
| Phase-1 max-loss breach / daily-loss breach | 0.0202 / 0.0 |
| Time to phase-1 target (bd) p10/p50/p90 | 121 / 289 / 647 |
| End-to-end to first payout (bd) p10/p50/p90 | 254 / 489 / 909 |
| BOOK_EXPECTED_PROGRESS_USD_PER_DAY / COST_DRAG | 27.50 / 12.61 (commission 9,671 + swap −12,822 USD over the window) |
| BOOK_MAX_DD_USD | 6,262 |
| Fail-together cluster | {10403, 10700, 41219} XAUUSD |

Marginal (1,000 paths, financed): 11708 −0.0145, 11910 +0.0045, 11421 0.000 — opposite in sign to the unfinanced run for 11708/11910 at the
same path count, which is the resolution problem documented in the reconciliation (§3) and the reason ticket `3fae43b2` adds seed-replicate
SE + a RESOLVED/UNRESOLVED flag. Replicates at 5,000 paths: 11708 +0.013 ± 0.010, 11421 +0.004 ± 0.003, 11910 −0.015 ± 0.005.

State overlay: `write_ftmo_book_current_v2.py` (session scratchpad; logic described in `docs/ftmo/FTMO_BOOK_CURRENT.md` v2 header) moved the
unfinanced Codex headline to `unfinanced_reference`, installed this financed headline, and added `incumbent`, `shadow`,
`delta_shadow_vs_incumbent`, `strongest_missing_book_behavior`, `financing`, candidate `book_action` + `resolution`, and
`demo_cycle.classification = PRE_SUNDAY_LIVE_TRIAL`. No Codex machine field was deleted.

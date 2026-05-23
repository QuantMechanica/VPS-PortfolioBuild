# 2026-05-15 — Four P2-baseline EAs dropped (hard reset closeout)

**Issue:** QUA-1562 (MASTER DIRECTIVE rolling tracker)
**Decision owner:** CEO (`7795b4b0`)
**Decision:** Drop the following EAs to lessons-learned. Not reviving. Source themes may be re-picked by a fresh Research dispatch if approved-source criteria still hold; that is a new card, not a revival.

## EAs dropped

| EA | Source theme | P2 result | Report |
|---|---|---|---|
| QM5_1003_davey_baseline_3bar | Davey 2014 baseline 3-bar | 0 PASS / 20 FAIL / 16 INVALID | `D:/QM/reports/pipeline/QM5_1003/P2/report.csv` |
| QM5_1004_davey_es_breakout | Davey 2014 ES breakout | 0 PASS / 8 FAIL / 29 INVALID | `D:/QM/reports/pipeline/QM5_1004/P2/report.csv` |
| QM5_1017_chan_pairs_stat_arb | Chan pairs stat-arb | 0 PASS / 8 FAIL / 28 INVALID | `D:/QM/reports/pipeline/QM5_1017/P2/report.csv` |
| QM5_SRC04_S03_lien_fade_double_zeros | Lien fade double-zeros | 0 PASS / 1 FAIL / 0 INVALID | `D:/QM/reports/pipeline/QM5_SRC04_S03/P2/report.csv` |

All four returned zero passing baselines on the 2024 H1 (M15 for SRC04_S03) run on 2026-05-15. Zero-Trades-Specialist verdict at the time was `STRATEGY_DRIFT`; spec says "back to Research". Cards were cancelled in the hard reset earlier the same day.

## Rationale

QUA-1562 Non-Goal #4: "No retrospective revival of cancelled hard-reset issues unless still load-bearing." None of these four are load-bearing — there is no downstream dependency, and the source themes themselves are still on the approved-source list, so Research can re-attempt with fresh parametrization if it wishes (treated as a new card, new SRC<NN>_S<n>).

Reviving a STRATEGY_DRIFT card is functionally identical to a new Research dispatch: same source, same theme, new parametrization. Doing it as a "new card" preserves clean audit lineage; doing it as a "revival" muddles the dispatch_state and re-dirties the hard-reset closeout.

## Evidence

- P2 result JSONs and report.csvs at the paths above.
- Existing archive directories for three of the four EAs already exist under `C:/QM/repo/docs/ops/QUA-archived/framework/EAs/` (QM5_1003, QM5_1004, QM5_SRC04_S03). QM5_1017 has no archive yet; not creating one as the report.csv is sufficient as primary evidence.
- Hard-reset closeout context in the QUA-1562 directive comment (2026-05-15T08:16:52Z).

## What Research should NOT repeat blindly

The four themes are not banned, but if Research re-picks any of them:

- Davey baseline 3-bar (1003) — high INVALID rate suggests data-window/symbol mismatch; verify M15 H1-2024 data integrity on the symbol set before re-dispatching.
- Davey ES breakout (1004) — 29 INVALID suggests setfile/spec mismatch; re-derive setfile from the Davey reference rather than re-using the 1004 baseline.
- Chan pairs stat-arb (1017) — pairs strategies need the second leg defined cleanly; the prior card may have run as single-leg.
- Lien fade double-zeros (SRC04_S03) — single FAIL with zero INVALID is the cleanest of the four; if re-attempted, focus on the entry/exit logic rather than data plumbing.

CEO neither requires nor blocks Research from re-picking these themes.

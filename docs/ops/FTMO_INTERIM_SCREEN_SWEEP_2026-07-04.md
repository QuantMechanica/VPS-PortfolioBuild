# FTMO Interim Screen Sweep — 2026-07-04 (Saturday evening token-burn wave)

Scope: while the factory ran unattended (scheduler dead, reboot scheduled Sunday), the
entire backlog of validated-but-never-screened FTMO candidates was pushed through the
Round24 admission screen (`prop_challenge_optimizer.py --screen-candidate`, report.htm
basis per task 97e655fe), plus 6 fresh validation backtests for the newest pool members.

## Fresh validation backtests (round31, 2023-01-01 → 2025-12-31, canonical sets, T8/T9)

| EA | Symbol | TF | Trades | PF | Net | MaxDD | Result |
|---|---|---|---|---|---|---|---|
| QM5_12989 grimes-nested-pb-v2 | XAUUSD | H4 | 23 | 3.95 | 18 749 | 2.43% | PASS |
| QM5_12990 grimes-context-pb-v2 | GBPUSD | H4 | 34 | 1.71 | 8 733 | — | PASS |
| QM5_12958 nnfx-hma-wae-swing | XAUUSD | D1 | 72 | 2.05 | 14 155 | 5.66% | PASS |
| QM5_10494 mql5-dema-chan | XAUUSD | H8 | 248 | 1.13 | 10 099 | 10.27% | PASS |
| QM5_10115 tv-ma-scalper-relief | GDAXI | M15 | 183 | 1.16 | 11 372 | 9.27% | PASS (attempt 2; attempt 1 = cold GDAXI cache NO_HISTORY, self-healed) |
| QM5_10911 grimes-complex-pb | GDAXI | H1 | 141 | 1.41 | 21 310 | 4.44% | PASS |

T_Live untouched; T8/T9 were idle (farm-disabled, Codex quota-exhausted); factory
throughput unaffected (7/7 workers, ~350 verdicts/h throughout).

## Screen results — 31 candidates, Round24 bar (min_robust 57.04, guards ≤5%)

- **0 ADMIT**
- **3 BACKUP** (clean, but do not improve the Round24 bar):
  - QM5_10110:NDX H1
  - QM5_10467:XAUUSD H1
  - QM5_12958:XAUUSD D1 — the only candidate that *reduces* max-loss breach (−0.96pp to 4.0%)
- **28 REJECT**, almost all `confirmed screen breaches the max-loss guard`
  (incl. QM5_12989 despite PF 3.95 → breach 9%; QM5_10911 despite the best own
  profile and the only target-coverage improvement (−0.37pp) → breach 9%)

Artifacts: `D:\QM\strategy_farm\artifacts\portfolio\ftmo_interim_screens_20260704\`
(one JSON per candidate + `screen_results.jsonl`). Triage fidelity: `--screen-runs 100
--screen-seeds 0,1,2 --force-confirm`; any future ADMIT candidate must be confirmed at
full fidelity before OWNER sees it.

## Structural finding

**Round24 @ scale 5.9 is max-loss saturated: 4.96% breach probability vs the 5.00%
guard.** Any lead+1 addition — regardless of candidate quality — adds exposure the guard
cannot absorb. Lead+1 screening is structurally exhausted as a path to improving the
FTMO book; the 06-30 "0 ADMIT / 13 BACKUP" result was the same effect, now confirmed
across the entire validated pool.

## Recommendation (next step)

Full **re-composition** ("Round25") over the complete validated report set (44 legacy +
6 fresh round31 reports): more legs at a *lower* risk scale, spreading the same total
risk across more uncorrelated legs — the same principle that took the live book to
MaxDD 4.8% (D2-d S3). Diversifier profiles now in evidence: 12958 (risk-reducing),
10911 (coverage-improving), 12989 (PF 3.95 at 23 trades). Run via the established
report-basis combo chain (Codex process) or a review-disciplined rerun; do NOT
reimplement a parallel q08-stream screen (06-30 basis lesson: 4.5× off).

## Same-evening pipeline fix (related)

Q08 basket host_symbol bug root-caused and fixed (commit `977a31a2b`): the Q08 baseline
passed the logical composite symbol to MT5 ("symbol not exist" → tester never started →
INFRA n_trades=0). Systemic for basket EAs; QM5_12772 + QM5_12778 requeued for organic
re-verdict. Watchdog hardening + weekly hygiene reboot + LSM health probe: commit
`2707463e9`; scheduled-task installation is a mandatory post-reboot step
(`docs/ops/POST_REBOOT_INSTALL_CHECKLIST_2026-07-05.md`).

# Codex brief — every candidate sleeve fails Q09 on correlation. What is the path out?

Date: 2026-07-27
Priority: high. This is the wall the whole FTMO book is standing behind.

## What was just established

Q09 is **not** broken and **not** rejecting by construction. Latest verdict per EA:
**53 FAIL_PORTFOLIO, 25 PASS_PORTFOLIO, 6 NEED_MORE_DATA.** It admits a third of what it
sees.

`NEED_MORE_DATA` is also not what it sounds like. It is emitted at
`tools/strategy_farm/farmctl.py:9759-9790` when the Q08 trade count is below
`Q09_PORTFOLIO_MIN_TRADES = 20` (`farmctl.py:148`). The missing "data" is simply
**trades** — not a file, not a measurement, not an import.

Our six candidate sleeves are nowhere near that threshold problem. Their latest Q09 rows:

| EA | verdict | Q08 trades | reason |
|---|---|---:|---|
| QM5_9936 | FAIL_PORTFOLIO | 1252 | `no_diversification:corr_full` |
| QM5_13213 | FAIL_PORTFOLIO | 1596 | `no_diversification` |
| QM5_13036 | FAIL_PORTFOLIO | 1352 | `correlation_above_max_corr:corr_full` |
| QM5_10553 | FAIL_PORTFOLIO | 2615 | `correlation_above_max_corr` |
| QM5_10848 | FAIL_PORTFOLIO | 1344 | `no_diversification` |
| QM5_13301 | FAIL_PORTFOLIO | — | `CHALLENGER_SUPERIOR` |

**Five of six fail for correlation.** Not for returns, not for drawdown, not for sample
size. The book is too correlated to be admitted as a portfolio.

This is independently corroborated. The joint-backtest validation measured 9936 against
13213 directly and found **r = 0.905 on shared days and 269 bit-identical trades** — both
are USDJPY range breakouts firing at the same 06:00 GMT+3 hour off overlapping windows
(`docs/ops/evidence/2026-07-27_joint_vs_python_model_validation.md`). Q09 is telling us
something true: **our candidate book is one bet wearing six hats.**

## The question

For a **single FTMO account** — OWNER has fixed this: one account at a time, no parallel
accounts — does Q09's portfolio-correlation rejection even apply, and if so how?

Q09 exists to stop a *portfolio* concentrating risk. A single challenge account running a
single sleeve is not a portfolio. Establish, from the gate's own contract and code:

1. **What is Q09 actually comparing against?** The other admitted sleeves, the live DXZ
   book, or the candidate set? Cite the code. `corr_full` versus the bare
   `no_diversification` reason suggests two different comparisons — explain both.
2. **Does a single-sleeve, single-account prop challenge fall inside or outside Q09's
   remit?** Argue it from the gate's purpose, not from convenience. If the honest answer
   is that Q09 correctly applies and a correlated sleeve is genuinely unsuitable, say so
   — that is a valid and important answer.
3. **`CHALLENGER_SUPERIOR` on 13301**: what beat it, and is that comparison still valid?
   Challenger-swap evaluation happens at Q09 and is never automatic, so a swap decision
   may be pending.
4. **What would an admissible book actually require?** Give the concrete correlation
   thresholds in force and name which currently-gate-clean sleeves are decorrelated
   enough from each other to pass together. If none are, say that plainly — it means the
   sleeve pool has no genuine diversity and the sourcing brief must target
   decorrelation, not just smoothness.

## What NOT to do

- Do **not** weaken, tune, or bypass Q09 to admit our book. The gate is doing its job and
  the correlation is real and measured. Any recommendation to relax a threshold must be
  an OWNER decision on evidence, never a code change made here.
- Do not re-run Q09 for these six hoping for a different answer.
- Do not conflate "unsuitable as a diversified portfolio" with "unsuitable for a single
  challenge account". They are different questions and the whole value of this task is
  keeping them apart.

## Constraints

- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`; do not interrupt backtests; T5 stays
  disabled and T9 is reserved; never `C:/QM/mt5/T_Live`.
- Read-only analysis plus your artifact. No gate changes.
- Evidence over claims: cite `file:line` or a query throughout.

## Deliverable

`docs/ops/evidence/2026-07-27_q09_correlation_wall.md` with the four answers, the
in-force thresholds, and a named list of which gate-clean sleeves could pass Q09
together — or a plain statement that none can.

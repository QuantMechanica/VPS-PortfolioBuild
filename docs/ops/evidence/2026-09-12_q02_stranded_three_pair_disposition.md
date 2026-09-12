# Q02 stranded exhausted pairs — three-pair disposition

Date: 2026-09-12 05:55 UTC
Router task: `af3eac6e-9745-4e35-9171-0517221e15c9`

## Result

The live health cohort contained exactly three EA/symbol pairs and 40 terminal
INFRA_FAIL rows. A fresh read-only classifier bound each result to its row evidence,
verdict reason, current setfile, and canonical registry identity. All three are
evidence defects; none is an authenticated zero-trade/frequency-floor outcome.

One governed, append-only canary was admitted for the only first-sequence candidate
whose summary and worker log both still exist. The other two remain in evidence-repair
disposition and were not requeued. Consequently `q02_stranded_exhausted_pairs`
improved from **3 to 2** without changing any historical row.

| Pair | Terminal rows | Row-bound cause | Evidence | Disposition |
|---|---:|---|---|---|
| `QM5_10505 / XAUUSD.DWX` | 14 | `ONINIT_FAILED; INCOMPLETE_RUNS` | source `cc347183`; summary and worker log present | One append-only Q02 canary `7f4fb7d4-4fa0-4233-b1d1-f3c912ea12ff` pending. Stop before a second pair until its terminal result is reviewed |
| `QM5_12582 / XNGUSD.DWX` | 13 | `ONINIT_FAILED; INCOMPLETE_RUNS` | source `ae468d0f`; summary present, worker log absent | Evidence-repair hold. Do not blind-requeue; recover/attribute the exact init event first |
| `QM5_20143 / EURUSD.DWX` | 13 | `NO_HISTORY; ONINIT_FAILED; INCOMPLETE_RUNS` | source `57af5db0`; summary and worker log absent | Evidence-repair/history-coverage hold. Do not requeue without exact-window coverage and restorable row evidence |

The machine-readable census is
`docs/ops/evidence/2026-09-12_q02_stranded_pairs_classification.json`; its CSV
companion contains the compact pair table. JSON SHA-256:
`9a8da10ee4065ac461a1f773ff6b3a601d31806eed6131aa0ad1a0ed6d27122d`.

## Canary binding

The dry-run classifier selected `QM5_10505 / XAUUSD.DWX` as sequence 1 in the
ONINIT group. Before admission:

- source terminal row and row-bound summary/log existed;
- canonical EX5 SHA-256 was
  `cc702479b617074e190b94833eb60cb9f9b5571cbfe6e39747633223b7a03bbb`;
- setfile SHA-256 was
  `d13392b780774adcc8ef1b0816d8c824c3accd430731ba404f726f8c47d567a9`;
- setfile audit found no missing or duplicate header/input defect.

`farmctl enqueue-backtest` then created exactly one successor,
`7f4fb7d4-4fa0-4233-b1d1-f3c912ea12ff`, with
`append_only_rerun_of_work_item=cc347183-5365-427e-b815-3879639c0d42` and the
current EX5 hash. The source row remains terminal. No terminal was launched or
interrupted by this action.

## Verification

- live health readback: `FAIL value=2` (down from 3; the two explicit repair holds)
- focused health and rerun-contract tests: **14 PASS**
- classifier: 3 pairs / 40 rows; `ONINIT_FAILED=2`, `NO_HISTORY_TRANSIENT=1`
- classification: `INVALID_EVIDENCE_DEFECT=3`, `VALID_ZERO_TRADES=0`
- no T_Live/FTMO action; no historical verdict/evidence mutation

## Review disposition

`REVIEW`: accept the one canary and the two fail-closed repair dispositions. Do not
admit `QM5_12582` unless the first canary has a reviewed terminal disposition and an
exact init cause is attributable. Do not admit `QM5_20143` without both evidence
recovery and an exact requested-window history coverage proof.

# FTMO book simulator hygiene follow-up

- Router task: `bc00c556-b41e-4386-b9d5-5db3bb731fac`
- Decision: `OWNER-DEC-FTMO-FINAL-MEGA-20260921`
- Implementation commit: `d4547928417f81c93a4019c1953dedd5de3adb6c`
- Verdict: **PASS — the governed path now fails closed on truncated streams and net-only rows; resolution and rare-winner diagnostics are machine-readable.**
- Roster effect: **none**

No roster, gate, terminal, T_Live, AutoTrading, farm row, or production state was
changed. The state artifact in this directory is an isolated copy seeded from
the accepted state solely to verify machine-field updates and overlay
preservation.

## Implemented contract

1. Every requested comparison validates each measurable stream against the
   fixed base-window end. A last close earlier than `window_end - 14 calendar
   days` raises `STREAM_WINDOW_INSUFFICIENT` and identifies the sleeve, exact
   last close, fixed end, and minimum accepted close date.
2. `--allow-truncated-streams` is an explicit research-only bypass. Base,
   marginal, and state outputs are labelled
   `TRUNCATED_STREAM_RESEARCH_ONLY`; `book_evidence_eligible` is false.
3. Every `TRADE_CLOSED` row must carry `profit` as gross P/L. A net-only row
   raises `STREAM_ROW_MISSING_GROSS_PROFIT`, preventing swap from being added
   to an already-net amount.
4. Each measurable state candidate now publishes top-level
   `marginal_delta_se` and `is_statistically_resolved`, with the boolean bound
   to `abs(mean delta) >= 2 x SE` through the existing resolution result.
5. Each measurable candidate publishes `top3_trade_share_of_net`,
   `top10_share`, `years_positive_share`, `DELTA_LCB_EX_TOP3`,
   `rare_winner_dependent`, and `tail_concentration_status`. Shares use the
   fixed-window, post-cost trade net; the year denominator is every calendar
   year touched by the fixed comparison window. `DELTA_LCB_EX_TOP3` reruns the
   same point-estimate comparison after deterministically removing the three
   highest-net trades from the candidate/contributing sleeve.
6. `RARE_WINNER_DEPENDENT` is set when the top-three share is greater than 0.60
   or `DELTA_LCB_EX_TOP3 < 0`. An add candidate with that flag cannot receive
   `CONSIDER_ADD`; it remains `SHADOW_BOOK` at best.
7. CLI persistence is atomic with respect to marginal preflight: a rejected
   candidate plan writes no partial base, marginal, or dependence artifact.

## Governed D2g6 verification

The accepted roster, financed streams, financing manifest, and candidate plan
from the 3fae43b2 evidence were rerun at the documented parameters: 5,000 base
paths, 40,000 paths per marginal replicate, five replicates, 5,000 weight-grid
paths, 20-day blocks, fixed seed `20260921`, and fixed as-of
`2026-09-21T19:00:00Z`.

The default command failed before persistence, as required:

```text
STREAM_WINDOW_INSUFFICIENT: 11910_NZDUSD_D1 last close
2025-06-05T16:14:35+00:00 is earlier than fixed window end 2025-11-21 minus
14 calendar days (minimum 2025-11-07)
```

Postcondition: base output absent; marginal output absent; dependence output
absent.

The explicit research-only rerun completed successfully. Its base, marginal,
and state outputs all carry `TRUNCATED_STREAM_RESEARCH_ONLY`; both exposed
eligibility fields are false; and the marginal violation list contains only
`11910_NZDUSD_D1`.

The base economic results remain unchanged:

| Metric | Accepted artifact | Follow-up run |
|---|---:|---:|
| P_FIRST_NET_FTMO_PAYOUT_LCB | 0.8668 | 0.8668 |
| P_CHALLENGE_PASS | 0.9516 | 0.9516 |
| P_VERIFICATION_PASS_GIVEN_CHALLENGE | 0.9775 | 0.9775 |
| BOOK_R_PER_DAY | 0.108484 | 0.108484 |
| BOOK_MAX_DD_ABS_USD | 6262.431297 | 6262.431297 |

The dependence artifacts, which are unaffected by the hygiene fields, are
byte-identical to the accepted artifacts:

- JSON: `8cb7b0936518437010258d4145a3829651a6baef205d6ad1c88a03dfdea377`
- Markdown: `fe4e7111ef0801e75102510c574945ed41acc9009e232b22193c8439f5fb6c8a`

The base JSON itself is not byte-identical to the older 3fae43b2 file because
the current checkout already uses first-passage engine 2.1.0 (the accepted file
records 2.0.0) and already publishes the later symbol-cost schema and payout
frontier. The pre-existing economic fields above are identical; this follow-up
does not claim that unrelated engine evolution as its work.

## Candidate read-model result

Shares below are ratios (for example, `0.915073` is 91.5073%). A negative share
means the all-trade net denominator is negative; in that case the rare-winner
decision can still be triggered by a negative ex-top-three delta.

| Candidate | Top 3 / net | Top 10 / net | Positive years | Delta LCB ex top 3 | SE | Resolved | Tail status | State action |
|---|---:|---:|---:|---:|---:|---|---|---|
| 11708 EURUSD D1 | 0.915073 | 2.275665 | 0.714286 | -0.0004 | 0.001581 | true | RARE_WINNER_DEPENDENT | SHADOW_BOOK |
| 11910 NZDUSD D1 | -7.060918 | -15.482395 | 0.428571 | -0.0760 | 0.002078 | true | RARE_WINNER_DEPENDENT | HOLD |
| 11421 EURUSD D1 | 1.718900 | 5.214111 | 0.714286 | -0.0238 | 0.002163 | true | RARE_WINNER_DEPENDENT | HOLD |
| 41219 XAUUSD D1 (incumbent contribution) | 1.172108 | 3.016378 | 0.571429 | -0.0044 | 0.001426 | false | RARE_WINNER_DEPENDENT | KEEP |
| 10403 XAUUSD D1 (incumbent contribution) | 2.012972 | 5.752264 | 0.571429 | -0.0288 | 0.001396 | true | RARE_WINNER_DEPENDENT | KEEP |
| 10700 XAUUSD H1 (incumbent contribution) | 0.145172 | 0.471219 | 0.857143 | +0.1478 | 0.001256 | true | NOT_RARE_WINNER_DEPENDENT | KEEP |
| H-V4 / QM5_41485 | null | null | null | null | null | false | NOT_YET_MEASURABLE | TEST |

This mechanically revokes the earlier `CONSIDER_ADD` read-model action for
11708 without changing the roster: its resolved positive full-stream marginal
is dependent on rare winners under the OWNER rule.

## Overlay preservation

The isolated state writer started from the accepted `ftmo_book_current.json`.
The JSON values for `owner_directive`, `human_mirror`,
`strongest_missing_book_behavior`, `incumbent`, `shadow`,
`unfinanced_reference`, and `delta_shadow_vs_incumbent` remained identical.
`demo_cycle.classification` and `demo_cycle.state` also remained identical. The
human mirror Markdown was not written.

## Tests

```text
python -m py_compile tools/strategy_farm/ftmo/book_sim.py
python -m pytest -q \
  tools/strategy_farm/tests/test_ftmo_book_sim.py \
  tools/strategy_farm/tests/test_ftmo_dependence_matrix.py \
  tools/strategy_farm/tests/test_ftmo_first_passage.py \
  tools/strategy_farm/tests/test_ftmo_first_passage_chain.py

55 passed in 9.07s
```

The focused book simulator file contains 19 passing tests, including fixtures
for a truncated stream, a net-only row, research-only ineligibility, no partial
CLI writes, top-three removal, rare-winner action suppression, top-level
resolution fields, and end-to-end marginal tail publication.

## Task-scoped artifacts

| Artifact | SHA-256 |
|---|---|
| `book_sim_research.json` | `58ea2681490d7c779cd53b728f22ae56b82a5dceaef7910b97c644a70cd26d51` |
| `marginal_research.json` | `4f042c56729cdef86ee79403ebf975da6524d431acb622c386ea74b63962a736` |
| `ftmo_book_current_research.json` | `f297074837b71508c9f768214c12fba668c5949e81720702d1082e66adc33ceb` |
| `dependence_research.json` | `8cb7b0936518437010258d4145a3829651a6baef205d6ad1c88a03dfdea377` |
| `dependence_research.md` | `fe4e7111ef0801e75102510c574945ed41acc9009e232b22193c8439f5fb6c8a` |


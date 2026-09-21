# FTMO book simulator v2 — financed confidence run

- Router task: 3fae43b2-03c9-4bce-b064-e8a042e05fdf
- Decision: OWNER-DEC-FTMO-FINAL-MEGA-20260921
- Book: FTMO_DEMO_BOOK_V3_D2G6_20260918
- Verdict: **FINANCED D2g6 LCB 0.8668; 5 resolved / 1 unresolved measurable marginal contributions**
- Roster effect: **none**. This tool measures; Fable/OWNER decides.

No terminal, T_Live, AutoTrading, farm row, gate, contract criterion, or roster
was changed.

## Outcome

The canonical financed incumbent result is:

| Metric | Result |
|---|---:|
| P_FIRST_NET_FTMO_PAYOUT_LCB | **0.8668** |
| Challenge pass | 0.9516 |
| Verification pass given Challenge | 0.9775 |
| Daily-loss breach | 0.0000 |
| Maximum-loss breach | 0.0202 |
| Historical max drawdown proxy | USD 6,262.43 |
| Expected progress | USD 27.50 / business day |
| Cost drag | USD 12.61 / business day |
| Fixed window | 2019-01-22..2025-11-21 (1,784 business days) |

The base contract remains 5,000 paths, 1,008 business days, 20-day blocks and
seed 20260921. Marginal uncertainty uses five paired seeds, 40,000 paths per
replicate, a 504-day horizon and the same 20-day blocks. The exploratory risk
weight grid remains 5,000 paths; it is not used for the resolution decision.

## Marginal resolution

SE is the sample standard deviation of the five paired-seed LCB deltas divided
by sqrt(5). 2×SE is the minimum resolvable delta. A reported marginal is
RESOLVED only when abs(mean delta) >= 2×SE.

| Candidate / sleeve contribution | Mean delta LCB | SE | 2×SE | Observed delta | 0.01 target |
|---|---:|---:|---:|---|---|
| add 11708 EURUSD D1 | **+0.00578** | 0.001581 | 0.003161 | RESOLVED | RESOLVED |
| add 11910 NZDUSD D1 | **−0.07588** | 0.002078 | 0.004156 | RESOLVED | RESOLVED |
| add 11421 EURUSD D1 | **−0.00790** | 0.002163 | 0.004327 | RESOLVED | RESOLVED |
| contribution of 41219 XAUUSD D1 | +0.00224 | 0.001426 | 0.002851 | UNRESOLVED | RESOLVED |
| contribution of 10403 XAUUSD D1 | **+0.01796** | 0.001396 | 0.002791 | RESOLVED | RESOLVED |
| contribution of 10700 XAUUSD H1 | **+0.20088** | 0.001256 | 0.002511 | RESOLVED | RESOLVED |

Five of six measurable marginal contributions are resolved; 41219 remains
unresolved around zero. Every measurable cell can resolve a delta of 0.01 at
the chosen path count.

The machine action for 11708 is now CONSIDER_ADD: its mean is positive and
resolved, and its point-estimate daily/max-loss deltas do not worsen. This is
eligibility under the ticket's mechanical rule, not a roster instruction.
11910 and 11421 are HOLD; the three incumbent leave-one-out cells remain KEEP.
The pending H-V4 stream remains TEST / not measurable.

## Why 40,000 marginal paths

A five-seed, 5,000-path financed pilot was run first. Its noisiest cell was
11910, with 2×SE = 0.025827. Under Monte Carlo square-root scaling, the
estimated count needed for 2×SE <= 0.01 was:

    ceil(5,000 × (0.025827 / 0.01)^2) = 33,352

The governed default was rounded up to **40,000 paths per replicate**. The
acceptance rerun confirmed the target empirically: the worst final 2×SE is
0.004327, comfortably below 0.01. The code refuses fewer than five seed
replicates.

## Financing contract

The CLI is fail-closed:

- governed book evidence requires --financed-streams;
- an unfinanced research run requires the explicit --allow-unfinanced flag and
  is labelled UNFINANCED;
- every financed TRADE_CLOSED row must carry
  qm_financing.{status,financing_usd,units,nights};
- the cent-rounded qm_financing.financing_usd must equal the row's embedded
  swap, otherwise the run fails.

The accepted streams are under
D:/QM/reports/book_evolution/2026-W38/ftmo/fable_alt_rosters_20260918/deployable2/streams_fin_full/QM/q08_trades.
Each stream is SHA-bound by the roster/candidate plan. The financing manifest
SHA-256 is
0d4b845c1dc39cb3af09f00a6cd240a0e861b1d1ca74d1cf0e2452573d830633.
Every financing number retains its row-level rate, units, nights, rollover
dates, profit currency and FX conversion where applicable; no rate was
invented by this task.

## Fixed-window rule

Base and variant now always use the incumbent base window
2019-01-22..2025-11-21. The old all-active intersection rule conflated a roster
change with a date-window change. In particular, QM5_11910 ends on 2025-06-05;
under the old rule, adding it discarded the incumbent's June-November 2025
observations. Under v2 those later days remain in both sides and 11910 is simply
inactive after its evidence ends. This makes every delta a roster delta on the
same calendar.

## State publication and human fields

D:/QM/reports/state/ftmo_book_current.json is labelled FINANCED and records
the stream root, financing manifest/hash, row contract and result fields. Its
SHA-256 is
7f5cc17ad7b5df566d419a7f20ee208ed7cf0c7b1874f17cd57ab8c82f86e9c1.
The evidence copy
[ftmo_book_current.json](ftmo_book_current.json) is byte-identical.

The writer starts from the prior state and updates machine fields. Fable's
prose/overlay fields — including owner_directive, human_mirror,
strongest_missing_book_behavior, Demo classification, incumbent/shadow
descriptions, and unfinanced historical reference — remain input-only and were
preserved. The human mirror Markdown was not overwritten.

## Verification

Focused tests:

    python -m pytest -q tools/strategy_farm/tests/test_ftmo_book_sim.py
    ..........                                                               [100%]
    10 passed in 0.79s

The tests cover financing fail-closed behavior, row-provenance validation,
explicit labels, financed deterministic output, SE/resolution fields,
CONSIDER_ADD refusal for an unresolved positive delta, SHA binding, Prague
midnight anchoring, and preservation of human fields.

Canonical command (line-wrapped):

    python tools/strategy_farm/ftmo/book_sim.py
      --roster .../d2g6_roster_financed.json
      --financed-streams D:/QM/.../streams_fin_full/QM/q08_trades
      --financing-manifest D:/QM/.../manifest_fin_full.json
      --candidate-plan .../candidate_plan_financed.json
      --n-paths 5000 --horizon 1008
      --marginal-n-paths 40000 --marginal-grid-n-paths 5000
      --marginal-replicates 5 --marginal-horizon 504
      --block-len 20 --seed 20260921 --as-of 2026-09-21T19:00:00Z

Primary artifacts:

- [book_sim_d2g6_financed.json](book_sim_d2g6_financed.json), SHA-256
  d640ca7c86bb8d1b01bdf2c0d03d1d836ca4f307572700c4ffa981667cd48693;
- [marginal_contribution_financed.json](marginal_contribution_financed.json),
  SHA-256
  e80ec3c5a4cd2f312648e2fc0b2208b32d3dcc01cede5840777c530dcf9a52c0;
- dependence matrix JSON/Markdown, roster, candidate plan and the byte-identical
  current-state snapshot in this directory.

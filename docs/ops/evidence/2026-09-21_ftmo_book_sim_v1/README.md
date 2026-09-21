# FTMO_BOOK account simulator v1 — D2g6 evidence

Router task: `e5c49db2-0d04-48e7-a92d-4f4e47d75461`

Decision: `OWNER-DEC-FTMO-BOOK-PORTFOLIO-20260921`

Implementation commit: `dddbfc7c81c19d976f46ff80ddcad73bb4dac2da`

## Verdict

PASS for review. The account-level simulator, marginal-contribution engine,
pairwise dependence matrix, and machine state writer were implemented and run
against the SHA-bound D2g6 Q08 streams. This is measurement evidence only; it
does not approve a roster change, pipeline phase, or deployment.

The D2g6 base result is:

| Field | Result |
|---|---:|
| Book risk | 1.71875% |
| Window | 2019-01-22 through 2025-11-21 (1,784 business days) |
| `BOOK_R_PER_DAY` | 0.131483 |
| `BOOK_TRADES_PER_DAY` | 1.336323 |
| `BOOK_ACTIVE_DAYS` | 0.867713 |
| `TIME_WITH_NO_OPPORTUNITY` | 0.132287 |
| Expected progress | $34.690756/calendar day |
| Historical max drawdown | $5,786.796922 |
| Bootstrap daily-loss breach probability | 0.0000 |
| Bootstrap maximum-loss breach probability | 0.0080 |
| `P_FIRST_NET_FTMO_PAYOUT` | 0.9450 |
| `P_FIRST_NET_FTMO_PAYOUT_LCB` | 0.9194 |

The base estimate uses 5,000 deterministic block-bootstrap paths, a 1,008-day
horizon, 20-day blocks, and seed 20260921. Challenge and Verification use the
existing `tools/strategy_farm/ftmo/first_passage.py` engine rather than a fork.

## Marginal results

All eleven requested deltas and the complete 0.0625%–0.5% weight grid are in
`marginal_contribution.json`. The table below shows the declared 0.3125% weight
for additions and contribution-when-present for leave-one-out runs. These
deltas use a common 1,000-path, 504-day marginal baseline whose payout LCB is
0.7435; they must not be compared directly with the longer-horizon base LCB.

| Sleeve | Mode / book action | Δ payout LCB | Δ challenge pass | Δ max DD USD | Δ trades/day | Δ cost/day USD |
|---|---|---:|---:|---:|---:|---:|
| 11708 EURUSD D1 | add / CONSIDER_ADD | +0.0200 | +0.0230 | -3.73 | +0.083520 | +0.058994 |
| 11910 NZDUSD D1 | add / HOLD | -0.0025 | 0.0000 | +656.41 | +0.029465 | +0.079239 |
| 10513 XAUUSD D1 | add / HOLD | -0.0290 | -0.0120 | +86.52 | +0.035314 | +0.038362 |
| 11421 EURUSD D1 | add / CONSIDER_ADD | +0.0145 | +0.0220 | +570.75 | +0.045403 | +0.212546 |
| 41219 XAUUSD D1 | leave one out / KEEP | +0.0045 | +0.0090 | -342.82 | +0.040359 | +0.017772 |
| 10403 XAUUSD D1 | leave one out / KEEP | +0.0290 | +0.0160 | -476.75 | +0.107623 | +0.067053 |
| 10700 XAUUSD H1 | leave one out / KEEP | +0.2410 | +0.1680 | -586.73 | +0.181054 | +0.422886 |
| H-V4 / QM5_41485 | TEST | n/a | n/a | n/a | n/a | n/a |

H-V4 is explicitly `NOT_YET_MEASURABLE`: it has no Q08 trade stream, so the
tool does not manufacture a probability estimate.

## Dependence result

The top fail-together pair is
`10403_XAUUSD_D1/41219_XAUUSD_D1`. Its loss-day overlap is 2.374445 times the
independence expectation and its exact position-time overlap is 39.4734% of
the smaller sleeve's exposure. The detected cluster is
`{10403_XAUUSD_D1, 10700_XAUUSD_H1, 41219_XAUUSD_D1}`. The matrix deliberately
keeps correlation, downside correlation, loss/trade-day overlap, position and
direction overlap, lower-tail co-exceedance, worst-20 overlap, contextual
flags, and simultaneous MAE open-risk separate; there is no opaque composite
score. Full pair rows are in JSON and the operator table is in Markdown.

## Cost, equity, and binding notes

- Every input stream is SHA-256 verified before use. The derived input-manifest
  SHA is `ae402d17ef431f45e3c9be87858099f9326d5ad2d964b75d174859ead194a39d`.
- Commission is re-costed from `framework/registry/live_commission.json`
  (SHA `e9f3c23ae44e5b11c57bb874d4d4bec8cf1dc9987777f5c9ef3add6e2bb43eea`),
  producing $9,670.916696 total commission drag.
- The requested primary financing module
  `tools/strategy_farm/swap/financing_lib.py` is absent in this checkout. The
  run is explicitly labelled
  `PRIMARY_FINANCING_TABLE_MISSING_STREAM_EMBEDDED_SWAP_FALLBACK`; embedded
  stream swap totals $0. No financing values were invented.
- Configurable spread and slippage stress are implemented; this base run uses
  zero incremental stress so it does not double-charge the already frozen
  stream execution, while retaining canonical commission re-costing.
- Closed-trade streams do not contain tick paths. Floating equity is therefore
  labelled `CONSERVATIVE_SIMULTANEOUS_ACTIVE_MAE_ENVELOPE_NOT_TICK_EXACT`.
  FTMO Daily Loss uses the Europe/Prague midnight balance anchor and that
  conservative active-MAE proxy; Maximum Loss uses the fixed 90% equity floor.

## State and verification

The writer produced `D:/QM/reports/state/ftmo_book_current.json` with schema
`qm.ftmo-book-current/v1`; the evidence directory contains a byte-identical
snapshot. It preserved Fable's human mirror
`docs/ftmo/FTMO_BOOK_CURRENT.md`: SHA-256 was
`dd1610bc98f9cc846bf9eb31195838a793180b1409a1d1a789b56ae69353ed54`
both before and after the write.

| Artifact | SHA-256 |
|---|---|
| `d2g6_roster.json` | `296b0b9d3e277373a63beaf1ad369a13447b31c0c1d8c99332cc0128d3be2275` |
| `candidate_plan.json` | `2bb76d4fd44a531536c6568044df2eb2715edb51d2a3673f0753cbc6c2299998` |
| `book_sim_d2g6.json` | `16040579f9c91ce48e08d4cf52d7c9c1c04ef749653f0f8a9a826da9fbbb14a4` |
| `marginal_contribution.json` | `e9fdc5926508a0b0fd27984d1c903af381a900ff1861f96bc979bda934cdf1c8` |
| `FTMO_BOOK_DEPENDENCE_MATRIX.json` | `b8962be5dde0a6ae10b2df49b82148100adc005de0f9d8fb8bf7d6577fdcea65` |
| `FTMO_BOOK_DEPENDENCE_MATRIX.md` | `8879878f2834b2a77e98f86083e1c00090644d6e6231592effd558dea944dd7d` |
| `ftmo_book_current.json` | `3fcde12ae04653194f5563d040f4f6994af7c992b387d6a779cb9c2fc300e95c` |

Focused verification:

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_book_sim.py \
  tools/strategy_farm/tests/test_ftmo_dependence_matrix.py \
  tools/strategy_farm/tests/test_ftmo_first_passage.py \
  tools/strategy_farm/tests/test_ftmo_first_passage_chain.py -q
41 passed
```

A second fixed-as-of 5,000-path base run produced the identical
`book_sim_d2g6.json` SHA shown above, proving deterministic output for the
bound inputs, seed, and parameters. Tests cover a synthetic three-sleeve
overlap fixture, SHA-tamper refusal, commission/swap scaling, Prague-midnight
Daily Loss arithmetic, determinism, and human-mirror immutability.

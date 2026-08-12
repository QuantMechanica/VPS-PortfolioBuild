# FTMO finite-horizon inventory diagnostic — 2026-08-02

## Decision statement

No current composition has an evidence-admissible FTMO finite-horizon
probability estimate. The five sealed compositions all depend on durable Q08
trade streams whose realized prices came from Darwinex. Those bytes cannot
prove an FTMO spread basis, so the evaluator returns
`REFUSED_DXZ_SPREAD_INHERITANCE` before calculating correlation, a rolling pass
rate, HAC effective sample size, or bootstrap interval.

The best bootstrap lower bound is therefore **not estimated** (`null`). The
result assigns **0.00 evidence credit**, labelled
`NO_EVIDENCE_CREDIT_NOT_ESTIMATED_PROBABILITY`; this is not a claim that the
true P1 pass probability is zero. Against the OWNER design bar of 0.80, the
current evidence-credit gap is 0.80. The binding dimension is **density**:
there are zero FTMO-cost-attested daily sleeve streams in the sealed candidate
set. Expectancy, correlation, and drawdown headroom remain unadjudicated.

This diagnostic does not declare a book ready. Any admission decision remains
subject to Claude close-review and OWNER authority.

## Bound contract implemented

`tools/strategy_farm/portfolio/ftmo_timebox_eval.py` implements a two-command,
hash-bound workflow:

1. `prepare-config` rejects mutable database/farm-state references and pins the
   inventory, FUND_SCORE cache, FTMO instrument terms, and every sleeve stream
   by SHA-256.
2. `evaluate` checks the expected config SHA-256 before opening a bound input.
   It then verifies every input digest and fails closed on missing FTMO swap
   terms or absent FTMO spread/commission/swap attestations.

For an admissible `FTMO_DAILY_NET_V1` stream, the engine uses every eligible
broker-calendar start on the Europe/Prague (NY-close GMT+2/+3) calendar. P1
must compound to +10% within 60 calendar days before a 5% daily or 10% total
loss breach. P2 resets to initial equity on the next broker day after a flat P1
pass and must reach +5% within 30 calendar days under the same loss limits.
Right-censored windows count as timeouts. The result includes raw P1,
Bartlett/HAC effective sample size (up to 59 lags), a 60-calendar-day moving
block percentile interval whose lower endpoint is the decision number, P2
given P1, joint pass rate, median time to target, and breach taxonomy.

DL-083 is pinned as an effective-correlation rule equal to the maximum absolute
pairwise Pearson correlation over the full trace and its high-volatility
quartile. Below 0.15 is the strong budget, 0.15 to below 0.40 is the grey
budget, and 0.40 or above is refused. At least 20 shared calendar days are
required. The present run did not calculate correlations because venue-cost
admissibility fails first.

## Sealed inventory

The qualification snapshot contains 1 `CHALLENGE_READY`, 214
`NOT_QUALIFIED`, and 3 `RESEARCH_LEAD` candidates. QM5_10128 XAUUSD is the sole
challenge-ready sleeve. The FUND_SCORE top-N grid uses the overlap between the
current scored inventory and strict Q08-PASS inventory; FUND_SCORE remains a
screening-only metric.

| Sleeve | FUND_SCORE | med60 1x | Current qualification | Current Q08 | Relevant qualification blocker |
|---|---:|---:|---|---|---|
| 13301:GDAXI | 0.360174 | 1.833010 | NOT_QUALIFIED | PASS | build not clean; Q04 PASS_SOFT |
| 10145:XAUUSD | 0.164165 | 0.328330 | NOT_QUALIFIED | PASS | evidence predates current build |
| 10183:XAUUSD | 0.094890 | 0.189780 | NOT_QUALIFIED | PASS | missing Q02/Q03 evidence; Q04 PASS_SOFT |
| 13036:GDAXI | -0.016968 | -0.041330 | NOT_QUALIFIED | PASS | Q03 pass missing |
| 10128:XAUUSD | -0.035950 | -0.071900 | CHALLENGE_READY | PASS | none |

These qualification fields report snapshot state only; they are not new
pipeline verdicts.

## Composition re-score

| Composition | Weights | Evaluation status | Bootstrap-LB P1 |
|---|---|---|---:|
| FUND_SCORE top 1 | 13301 100% | REFUSED_DXZ_SPREAD_INHERITANCE | not estimated |
| FUND_SCORE top 2 | 13301/10145, 50% each | REFUSED_DXZ_SPREAD_INHERITANCE | not estimated |
| FUND_SCORE top 3 | 13301/10145/10183, equal | REFUSED_DXZ_SPREAD_INHERITANCE | not estimated |
| FUND_SCORE top 5 | 13301/10145/10183/13036/10128, equal | REFUSED_DXZ_SPREAD_INHERITANCE | not estimated |
| Challenge-ready singleton | 10128 100% | REFUSED_DXZ_SPREAD_INHERITANCE | not estimated |

The durable Q08 JSONL rows contain net, profit, commission, swap, volume,
notional, and a Darwinex symbol, but do not contain enough bid/ask provenance
to remove the realized Darwinex spread and insert FTMO spread terms. Repricing
only commission and swap would silently retain the forbidden venue spread.
The evaluator consequently inventory-binds and hashes these streams but does
not parse them into a probability trace.

## Reproduction identities

| Artifact | SHA-256 |
|---|---|
| Inventory spec | `6ad42eb4a6ecd02ccdad9c0290fe6f329b9ea359c2c98b7c5e9600e696d64d02` |
| Prepared config | `f468fef0da0bc0ccfdccbbcb186c90b037f120cbbe3b5ce7dc8a3a3cbc06fc7d` |
| Evaluation result | `74679b38f1cb9a02f9e51d3fb02d00ca36ebaa88a56397a8128843dd936f5ba5` |

The exact artifacts are:

- `docs/ops/evidence/2026-08-02_ftmo_timebox_inventory_spec.json`
- `docs/ops/evidence/2026-08-02_ftmo_timebox_inventory_config.json`
- `docs/ops/evidence/2026-08-02_ftmo_timebox_inventory_result.json`

| Bound input | SHA-256 |
|---|---|
| Qualification inventory | `e1bcec96919049ad2a3cd593d07617ecd6e43eaa6e36a1a50fdc033bf57e1a46` |
| FUND_SCORE cache | `e58139a87ffb0802bcb6fca2802690a204cc77795a7afee8dda391721240b302` |
| FTMO instrument snapshot | `7309310ad92f794407d25452127c38e7db175b841be0f70b82b201b841b932da` |
| 13301:GDAXI Q08 stream | `0a090ebb6ee67236948489a9486f419ba0ba41eb93d2ffa3e040a6a1b2a5a3a3` |
| 10145:XAUUSD Q08 stream | `b7828167b02d8440ce1956be570f13e56a95b0e26730b776f28086e10bb79c2d` |
| 10183:XAUUSD Q08 stream | `ca2e43790553fece068a3a91271ac5f75ad82bfc19e6a57d4437a4bb85a46265` |
| 13036:GDAXI Q08 stream | `da77e80241635ce4c45d1b802f38d779050948e6a4aabced4bc4ed9d0ad88a0b` |
| 10128:XAUUSD Q08 stream | `d96677acc4ec35597f80a5ad7d28d730c7b96d5dd5b01aceea1b40d9c8b8146f` |

Run from `C:/QM/repo`:

```powershell
python tools/strategy_farm/portfolio/ftmo_timebox_eval.py prepare-config `
  --spec docs/ops/evidence/2026-08-02_ftmo_timebox_inventory_spec.json `
  --output docs/ops/evidence/2026-08-02_ftmo_timebox_inventory_config.json

python tools/strategy_farm/portfolio/ftmo_timebox_eval.py evaluate `
  --config docs/ops/evidence/2026-08-02_ftmo_timebox_inventory_config.json `
  --expected-config-sha256 f468fef0da0bc0ccfdccbbcb186c90b037f120cbbe3b5ce7dc8a3a3cbc06fc7d `
  --output docs/ops/evidence/2026-08-02_ftmo_timebox_inventory_result.json
```

## Verification

Focused verification on 2026-08-02:

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_timebox_eval.py -q
..............                                                           [100%]
14 passed in 2.99s

python -m py_compile tools/strategy_farm/portfolio/ftmo_timebox_eval.py
PASS
```

The fixtures prove deterministic finite-horizon drift and sequential P1/P2
chaining, daily-loss and max-loss breach ordering, flat-boundary targets,
timeouts, HAC/bootstrap output, expected-config hash checking before input
access, mutable-DB refusal, missing-swap refusal, FTMO cost attestation,
Darwinex-spread refusal, and DL-083 rejection of a perfectly correlated pair.
It also proves fail-closed handling of undefined correlation and mismatched
shared calendars.

## Evidence needed to obtain a probability estimate

Each candidate needs a daily shared-equity stream whose rows explicitly attest
`venue=FTMO` and FTMO spread, commission, and swap bases against the pinned
cost-snapshot digest. Every broker-calendar date must include close-to-close
net return, conservative intraday low from broker midnight, trade count,
rolling-start eligibility, and flat-at-end state. Once those sealed streams
exist, this evaluator can adjudicate the top-N grid without changing the OWNER
horizons or weakening the cost guardrail.

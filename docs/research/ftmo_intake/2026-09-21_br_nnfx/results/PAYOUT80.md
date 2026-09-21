# FTMO 80/20 payout-speed frontier

Programme: `FTMO_BR_NNFX_20260921`

Router task: `e5cc5e95-c3d5-490a-b6c0-a3fded57a38c`

Evidence boundary: research diagnostic only; not a pipeline verdict, live allocation, or proof of cash receipt

Disposition: `EVALUATOR_READY / NO_INTAKE_SURVIVORS / ECONOMIC_DECISION_DEFERRED`

## Decision

The additive payout-speed evaluator is implemented in FTMO first-passage engine `2.1.0` and
is propagated by `book_sim.py`. It reports unconditional payout probability at calendar days
30, 45, 60 and 90; the first modeled day whose 90% batch lower bound reaches 0.80; conditional
time distributions; and an exhaustive, mutually exclusive path disposition.

The BR/NNFX intake contributes **no eligible candidate** to that evaluator. The frozen
prescreens contain 24 cells (16 BR1/BR2/BR3 plus 8 N2), with **0 survivors**. No candidate
has been compared as a new sleeve, no follow-on has been arranged, and no roster, live weight,
terminal, or published state has been changed.

The existing six-sleeve financed D2g6 roster was run only as the incumbent/control diagnostic.
It clears the 0.80 lower-bound target eventually in the modeled market path, but not quickly:
all four requested early day marks are zero and modeled `t80` is diagnostic calendar day 1300.
This is **not** a bank-receipt `t80`. Administrative hand-offs, administrative rejection,
payment-method minimum selection, and bank-receipt lag remain unbound, so a full real-world
calendar-to-cash frontier cannot be stated without inventing facts.

## Incumbent diagnostic

Run contract: 100,000 USD FTMO 2-Step; 40,000 block-bootstrap paths; seed `20260921`;
20-business-day blocks; 1,008-business-day horizon per stage; financed streams; registry
commission; floating equity represented by the existing conservative simultaneous-active-MAE
proxy. Challenge, Verification, and funded stages use independent block draws from the same
book distribution. The chain is evaluated pathwise, not as a product of marginals.

| Measure | Base financed D2g6 |
|---|---:|
| Challenge pass | 0.9565 |
| Verification pass, conditional on Challenge | 0.9777 |
| Funded survival to first modeled reward | 0.9531 |
| Full-chain positive-net-payout point estimate | 0.8913 |
| Full-chain positive-net-payout 90% batch LCB | **0.8762** |
| Positive-net paths | 35,651 / 40,000 |

### Unconditional speed frontier

Calendar days use the engine's documented 5/7 diagnostic conversion. They are not exact dated
calendar paths and exclude the unresolved administrative and receipt lags.

| Calendar day | Business-day cutoff | P(positive net payout by cutoff) | 90% batch LCB |
|---:|---:|---:|---:|
| 30 | 21 | 0.0000 | 0.0000 |
| 45 | 32 | 0.0000 | 0.0000 |
| 60 | 43 | 0.0000 | 0.0000 |
| 90 | 64 | 0.0000 | 0.0000 |

The first successful-path cutoff at which the batch LCB is at least 0.80 is business day 929,
mapped to diagnostic calendar day **1300**, with LCB **0.8013**. Conditional on a modeled
positive net payout, end-to-end time is 251 / 487 / 895 business days at p10 / p50 / p90,
or 352 / 682 / 1253 diagnostic calendar days. Reporting the conditional median alone would
hide the failure and censoring mass; the headline above is unconditional.

### Exhaustive outcome partition

| Exclusive path outcome | Count | Probability |
|---|---:|---:|
| Positive modeled net payout | 35,651 | 0.8913 |
| Challenge daily-loss breach | 0 | 0.0000 |
| Challenge maximum-loss breach | 753 | 0.0188 |
| Challenge unresolved at horizon | 989 | 0.0247 |
| Verification daily-loss breach | 0 | 0.0000 |
| Verification maximum-loss breach | 713 | 0.0178 |
| Verification unresolved at horizon | 141 | 0.0035 |
| Funded daily-loss breach | 0 | 0.0000 |
| Funded maximum-loss breach | 29 | 0.0007 |
| Funded unresolved at horizon | 1,724 | 0.0431 |
| Reward reached but net cash not positive | 0 | 0.0000 |
| **Total** | **40,000** | **1.0000** |

No daily-loss breach in this simulation is a result, not a waiver of the 5% rule. Unresolved
paths are censored and are never counted as wins.

## Cash ledger and current rule boundary

The bound economics are a 540 USD list fee, 100% fee refund, and 80% reward share. The fee and
refund remain separate ledger entries. At the requested funded-gain checkpoints:

| Funded gain | Funded profit | Reward at 80% | Fee paid | Fee refund | Net cash under bound refund |
|---:|---:|---:|---:|---:|---:|
| 0.5% | 500 USD | 400 USD | -540 USD | +540 USD | 400 USD |
| 1.0% | 1,000 USD | 800 USD | -540 USD | +540 USD | 800 USD |
| 2.0% | 2,000 USD | 1,600 USD | -540 USD | +540 USD | 1,600 USD |

The current official withdrawal FAQ states a minimum withdrawal of 20 USD for bank wire and
50 USD for cryptocurrency. At an 80% split, those method-specific first permitted reward
amounts correspond algebraically to 25 USD and 62.50 USD of funded profit, respectively,
before any separate method or account facts. The engine deliberately does **not** choose a
payment method: its first-positive threshold is labeled
`ENGINE_FIRST_POSITIVE_NET_REWARD`, and `payment_method_minimum_usd` is null. Consequently,
the model's first-positive event is not represented as a universally permitted withdrawal.
Nor does a modeled payout mean that FTMO accepted a request or a bank received cash.

Current official terms checked for this evidence:

- [FTMO Trading Objectives](https://ftmo.com/en/trading-objectives/): 10% Challenge target,
  5% Verification target, 5% Maximum Daily Loss including floating P/L and costs at Prague
  midnight, 10% static Maximum Loss, and four trading days in each evaluation phase.
- [FTMO profit withdrawal FAQ](https://ftmo.com/faq/how-do-i-withdraw-my-profits/): first
  request from day 14 after the first funded trade, closed positions/orders, 80% standard
  2-Step split, stated review/payment processing, and payment-method minimums.
- [FTMO evaluation timing FAQ](https://ftmo.com/faq/how-long-does-it-take-to-become-an-ftmo-trader/):
  no maximum evaluation duration and the four-plus-four trading-day lower boundary.

The engine binds 14 calendar days from first funded trade as 10 business days and a
conservative four-business-day processing envelope (the upper sum of the stated review and
sending windows). Challenge-to-Verification administration,
Verification-to-funded administration, administrative rejection probability, and final
bank-receipt lag are null. Those missing quantities prevent a real-world bank-receipt `t80`.

## Cost and venue sensitivity

The existing generic stress row (1.5x modeled costs plus 2 USD/lot round-trip slippage) yields
a 0.8252 point estimate and 0.8143 LCB. Its modeled `t80` is business day 1314 / diagnostic
calendar day 1839 (LCB 0.8000); conditional calendar p50/p90 are 748/1374 days.

This row is a sensitivity, not measured FTMO-vs-DarwinexZero execution evidence. Upstream task
`73434cab-cf1c-4c17-8a11-9ca52c11d99e` is in REVIEW with
`ABSTAIN_NO_ELIGIBLE_VENUE_DELTA`: the available records have no exact-time cross-venue overlap
and no request-to-fill slippage. Therefore no venue-calibrated numeric headline is substituted
and zero slippage is not claimed as evidence.

## Intake survivor and deduplication ledger

The read-only census contains 28 NNFX identities and 26 retest-labelled identities. Six NNFX
identities have no work-item row (`11963`, `11964`, `11965`, `36001`, `36003`, `36004`); adding
`36008` gives seven without an economic verdict. Three active retest identities have no
work-item row (`9241`, `12038`, `20078`). These are inventory gaps, not implied profitable
strategies.

| Frozen package | Cells | Selection outcome | Survivor count | Evidence SHA-256 |
|---|---:|---|---:|---|
| BR1/BR2/BR3 retest/control | 16 | all `CLEAR_REJECT` or `UNKNOWN` | 0 | `cf033bd761b431e033fbc24bfea67067e63d52d7e5a9e501cf8bb5c6dcb5294b` |
| N2 session-flat/all-hours | 8 | all `CLEAR_REJECT` | 0 | `9a452c7fff005e7ef27fc86bad91b5febdce2ee61e017396233c8e3bd9b32cf9` |
| **Total** | **24** | no reviewed survivor | **0** | — |

The result files were read only after their frozen selection/validation checks. Since there is
no reviewed survivor, the rules prohibit creating a Strategy Card, mechanisation task, funded
roster comparison, or live allocation follow-on. The incumbent result is context, not an
attempt to turn a rejected intake cell into a book survivor.

## Reproducibility and unresolved dependencies

| Item | Exact binding / status |
|---|---|
| Diagnostic JSON | `PAYOUT80_diagnostic.json`, SHA-256 `fb25ec50555f5b94ce912b4c247ef14b57c371ac63d60c2bacd60d91a00aa708` |
| Diagnostic input manifest | `9fa877faa41b21109b3bfc1ac46b3558801226453bb8c30c35d345e732f4f990` |
| Financed-stream manifest | `0d4b845c1dc39cb3af09f00a6cd240a0e861b1d1ca74d1cf0e2452573d830633` |
| D2g6 roster | SHA-256 `35844a5524f922cf013f970b21d5b5c895d1d2a25b266f937d4696637072aaa1` |
| Intake inventory | SHA-256 `76723f335a9b55c5a11fe4328c179048552e53321dfefa8d1e4ac94bca4fb226` |
| Source catalog | SHA-256 `9ed8295104853d2f4490089b1f4b7b2ebfc8da6e06fa8ad7978dd17b782354ba` |
| Frozen plan | SHA-256 `e42d8770df11fcbbca9e5560a1280c352145b09d7cd1e2b30135d4bff1a9b57b` |
| First-passage engine | `2.1.0`, SHA-256 `b2c56edf7327f5301eda5d1b5793cecf62466dd0e7db7052503f277af9ef6335` |
| Book simulator | SHA-256 `50cc51606590206ae48b77850745194972b19c8df976c3cb7e6d8423e9c8dc3a` |
| Venue-cost calibration | task `73434cab-cf1c-4c17-8a11-9ca52c11d99e`, REVIEW / abstain |
| Simulator hygiene | task `bc00c556-7b6f-4de5-93a9-a6c41ac94ca2`, still TODO; coterminous-stream, gross-profit, and rare-winner checks not accepted |
| Velocity harness v2 | task `7088da77-9e03-45cf-a568-581863f03ef1`, still IN_PROGRESS; existing F2 prescreens are not upgraded by this report |
| News archive/time fidelity | task `a36a5983-9951-43f5-8afd-c313329dcce7`, still IN_PROGRESS; `PRE30_POST30_DXZ` tags do not independently prove current Standard-account news compliance |

The JSON was produced with:

```text
python tools/strategy_farm/ftmo/book_sim.py \
  --roster docs/ops/evidence/2026-09-21_ftmo_book_sim_v2_financed/d2g6_roster_financed.json \
  --financed-streams D:/QM/reports/book_evolution/2026-W38/ftmo/fable_alt_rosters_20260918/deployable2/streams_fin_full/QM/q08_trades \
  --financing-manifest D:/QM/reports/book_evolution/2026-W38/ftmo/fable_alt_rosters_20260918/deployable2/manifest_fin_full.json \
  --out docs/research/ftmo_intake/2026-09-21_br_nnfx/results/PAYOUT80_diagnostic.json \
  --n-paths 40000 --horizon 1008 --block-len 20 --seed 20260921 \
  --as-of 2026-09-21T20:12:32Z
```

The diagnostic writes only this evidence file. It does not publish `D:/QM/reports/state`, alter
the candidate roster, authorize a Strategy Card, or imply live use.

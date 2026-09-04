# OWNER book receipt V2/V4/V6 + G5 epoch — implementation evidence

**Task:** `b9f7a280-0e5d-4c2c-bafe-44a133706b54`

**Authority:** `OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904` in
`decisions/2026-09-04_owner_receipts_briefing_2_4.md`

**Verdict:** **PASS / REVIEW READY**

## Result

The decision-bound repository changes are complete:

1. FTMO builder values `max_pairwise_correlation = 0.50` and
   `account_weight_budget = 10.0` now carry `OWNER_RATIFIED` status and the receipt ID.
   A CLI override is explicitly `UNRATIFIED_OVERRIDE` and cannot satisfy the manifest bar.
   The correlation control now enforces the documented Q15 rule as strict
   `abs(r) < 0.50`; the previous raw-`r` comparison could admit a strongly negative pair.
   SP-C3 and the separate Q15 caps (family <= 3, symbol <= 2, 10–15 EAs) are stamped as
   companion gates, not represented as replaced by the two FTMO selector numbers.
2. `portfolio_correlation.py` now emits `qm.portfolio-correlation/v2` pair evidence using
   the OWNER-ratified two-layer sparse-D1 method:
   - Layer A: zeros-kept daily net-of-cost PnL on the pair-local common-support business-day
     grid (plus actual weekend trade days), Pearson estimate, automatic
     Politis-White/PPW stationary-block length, paired stationary-block bootstrap 95% CI,
     and fail-closed `CERTIFY_A`/`ABSTAIN` against the strict OWNER-ratified +/-0.50 bound.
   - Layer B: entry-to-exit UTC calendar-day occupancy, exact all-rotation circular-shift
     null via FFT, exact upper-tail p-value, Benjamini-Hochberg FDR across testable pairs,
     lift, low-power/saturation declarations, and same-symbol signed notional refinement
     when `side` and `notional` are complete.
   - Each pair carries structured layer evidence and a combined method/admission verdict.
     Dense pairs retain scalar matrix compatibility. Sparse pairs remain `None` in the
     admission matrix and `ABSTAIN` while the COS/bootstrap calibration numbers remain
     `WORKING_DEFAULT_OPEN_OWNER_ITEM`; therefore the existing builder consumes them
     fail-closed, never as an absent constraint or an unratified pass.
3. The trade-stream loader preserves the existing JSONL `side` field so the ratified signed
   COS refinement can be computed rather than guessed.
4. The G5 OWNER command and review checklist now use exactly
   `deployment_epoch_utc = 2026-07-19T13:50:00Z` with `went-live` semantics. The historical
   current unsigned pointer value (07-24) remains documented as observation, and no pointer
   was generated, signed, or written.
5. V6 is unchanged: book risk remains 9.75%; this receipt required no code change for V6.

## Threshold and authority boundary

- OWNER-ratified now: absolute pairwise limit `0.50`; account unit-weight budget `10.0`;
  sparse method; went-live epoch `2026-07-19T13:50:00Z`.
- Still open pending the first SHA-frozen Q14 cohort: dense co-active-day split, bootstrap
  replicate/seed calibration, COS FDR alpha, lift, expected-cooccupancy/occupancy power
  floors, and signed-report floor. The emitted defaults are tagged
  `WORKING_DEFAULT_OPEN_OWNER_ITEM` and do not admit sparse pairs.
- Not performed: book construction, threshold calibration/ratification, deploy-pointer mint
  or signature, freeze lift, deployment, T_Live access, terminal action, or AutoTrading.

## Focused verification

Run from `C:/QM/repo`:

```text
python -m py_compile \
  tools/strategy_farm/portfolio/portfolio_common.py \
  tools/strategy_farm/portfolio/portfolio_correlation.py \
  tools/strategy_farm/portfolio/build_book_ftmo.py
PASS

python -m pytest \
  tools/strategy_farm/tests/test_portfolio_correlation.py \
  tools/strategy_farm/tests/test_portfolio_common.py \
  tools/strategy_farm/tests/test_portfolio_q08_contribution.py \
  tools/strategy_farm/tests/test_portfolio_resize.py \
  tools/strategy_farm/tests/test_dual_book_builders.py \
  tools/strategy_farm/tests/test_book_path_refusal_cli.py \
  tools/strategy_farm/tests/test_book_build_guard.py \
  tools/strategy_farm/tests/test_risk_freeze_prevention.py -q
99 passed, 1 skipped

python tools/strategy_farm/portfolio/portfolio_correlation.py --help
python tools/strategy_farm/portfolio/build_book_ftmo.py --help
PASS (both CLIs parse and expose the governed defaults/status descriptions)
```

Regression coverage includes zeros-kept structured sparse abstention, exact circular-shift
co-occupancy flagging with signed refinement, `side` loading, OWNER status/provenance,
unratified-override labeling, and rejection of `r = -0.92` under the absolute 0.50 rule.

## Files

- `tools/strategy_farm/portfolio/portfolio_correlation.py`
- `tools/strategy_farm/portfolio/portfolio_common.py`
- `tools/strategy_farm/portfolio/build_book_ftmo.py`
- `tools/strategy_farm/tests/test_portfolio_correlation.py`
- `tools/strategy_farm/tests/test_dual_book_builders.py`
- `docs/ops/evidence/2026-09-03_g5_deploy_pointer_signing_vorlage.md`
- this evidence record

**Mutation statement:** repository code, tests, and documentation only. No farm work item,
tester, terminal, live pointer, deploy state, freeze state, book, or T_Live state was changed.

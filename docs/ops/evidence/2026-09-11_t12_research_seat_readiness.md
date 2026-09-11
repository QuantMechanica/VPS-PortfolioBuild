# T12 research-seat readiness — receipt-backed hand-back

Router task: `95081591-4f88-4fac-917d-e83ac4067317` (priority 88).

## Delivered

`research_canary.py` now admits both inert research seats, **T11 and T12**.
Staging and execution retain the existing per-seat protections: canonical-repo
EX5 source, SHA-256-bound staged EX5/setfile, signed private-history audit,
seat-scoped MetaTester process accounting, a kill-on-close job, and append-only
receipts.  Neither research seat is a factory runner; the signed activation
continues to list only T1--T10.

T12 was prepared without changing a queue row, terminal worker, live terminal,
or AutoTrading setting:

| Item | Evidence | Result |
|---|---|---|
| Symbol catalogue | T1 and T12 `symbols.custom.dat` SHA-256 `6be56cd376afac7fb69bb6b30f24781f1d21e96b34bddc5b6c7e1e4f7ac09d65` | identical |
| Custom history | signed-manifest audit of T12 `USDJPY.DWX` | PASS, 108 files |
| EX5 stage | SHA-256 `68d37d3a6b6d5d4354e5a9aa494488d8d2809b1f662ff75fbb26440658137c01` | staged |
| Setfile stage | SHA-256 `e5129f6d71e6b65a8d94f53d94930866a05219755aca6692b58254e004b40be9` | staged |

Stage receipt: `D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2021_T12/staging/20260911_171944_e094254a_receipt.json`.

## Model-4 identity-smoke admission

The controller dry-run receipt is
`D:/QM/reports/research/WINSWEEP_QM5_41398_USDJPY_DWX_2021_T12/20260911_172046_34c412a7/receipt.json`.
It is `DRY_RUN_PASS`: Model 4, zero T12-owned MetaTester processes, 48.3 GB
available RAM, 66.22% five-sample CPU average, and the 108-file signed-history
audit all passed.  The receipt records independent factory advancement during
the observation; the controller did not write the factory DB or acquire the
factory lock.

The consequential non-dry identity attempt was refused before launch because
its five-sample CPU mean was **95.44%**, above the governed 95% ceiling.  The
CLI returned `REFUSED`; therefore there is no report, no metric comparison to
the fleet reference (net 2941.71 / PF 1.03 / 208 trades), and no identity PASS
claim.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_research_canary.py -q
39 passed
python -m py_compile tools/strategy_farm/research_canary.py
PASS
```

**RESULT (Q-only):** Q-S3 T12 readiness is REVIEW.  T12 is a hash-bound,
receipt-producing second research seat, but the required real-tick identity
smoke is not yet measured because the admission guard refused it.  Any later
T11+T12 pilot must first obtain fresh per-seat admission receipts and preserve
the same Model-4-only verdict boundary.

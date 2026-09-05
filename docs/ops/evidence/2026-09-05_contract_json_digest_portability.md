# FTMO probability-contract digest portability — 2026-09-05

## Result

PASS. `load_probability_contract` now exposes the checkout-portable,
LF-normalised SHA-256 as `sha256` and retains the exact on-disk SHA-256 as
`raw_sha256`. Every existing engine stamp carries the portable identity; JSON
artifacts also record the raw identity beside it. The contract path is marked
`-text` in `.gitattributes`, preventing future `core.autocrlf` smudging.

No probability, correlation, risk, or acceptance threshold changed.

## Digest evidence

Before the patch, the same contract content had checkout-dependent engine
identities:

| representation | SHA-256 |
|---|---|
| repository/on-disk LF bytes | `54cb80fd4623a8a08d792c0d15b347f7999a7ff3565d373121e01dba3bef7e27` |
| simulated CRLF checkout bytes | `7328b8b13de2a74a66ce322a8c3d366c6201d7a901c3329bf248103c5b7c219c` |

After correcting only stale citations, the content identity necessarily
changed. The loader behavior on those final bytes is:

| representation | raw SHA-256 | stamped LF-normalised SHA-256 |
|---|---|---|
| LF | `5b4e24eb60cd175f0973ddf7c8ea3f9db0daf2965379f1fedff6a8d816f79362` | `5b4e24eb60cd175f0973ddf7c8ea3f9db0daf2965379f1fedff6a8d816f79362` |
| simulated CRLF | `168b4eeb27a9a669b02bf7421a570d4aed79a92bfd65da5cdf8f1b35cb2e2ec6` | `5b4e24eb60cd175f0973ddf7c8ea3f9db0daf2965379f1fedff6a8d816f79362` |

Thus raw provenance remains observable while the decision identity is stable
across LF and CRLF checkouts.

## Citation corrections

- The builder migration note now cites the current Layer-A `CERTIFY_A`
  absolute-upper-CI loader at `build_book_ftmo.py:171-205`.
- The Q09 marginal cap now cites its declaration at
  `ftmo_timebox_eval.py:112-114` and application at `:1115-1117`.
- The signed/absolute note now cites the builder's explicit absolute transforms
  at `build_book_ftmo.py:190-197` and `:295-304`.

## Verification

- `python -m pytest tools/strategy_farm/tests/test_ftmo_probability_contract.py -q`
  — 6 passed.
- The portability test creates both LF and CRLF copies, loads each through the
  production loader, asserts identical `sha256`, and asserts distinct retained
  `raw_sha256` values.
- `git check-attr text -- tools/strategy_farm/config/ftmo_probability_contract.v1.json`
  — `text: unset` (`-text`).

Disposition: implementation is ready for independent review. It does not
ratify the pending FTMO acceptance test and does not lift `NO-BUY`.

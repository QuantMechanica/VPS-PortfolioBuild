# QM5_12951 mandatory Codex re-review

Router task: `6f392d1e-f1d8-402c-8d33-37d6661ab14e`  
Gemini source task: `aae32e9c-372c-4108-9dd7-2f041682eae4`  
EA: `QM5_12951_mql5-chaikin-zero-card`

Verdict: **RECYCLE / REVIEW HOLD**. The source-side defect from the prior
review is repaired and all focused static checks pass, but the canonical EX5
is not the binary produced by the governed repaired-source compile. The task
must not advance to pipeline or approval while that identity mismatch exists.

## Blocking finding

The canonical MQ5 is the repaired source from commit `b88a3c0750`:

- MQ5 SHA-256:
  `b130b48a35f848ce6457e1fbd1d4787b031c9a41b9dd2246429a660e84a5b96a`
- `QM_FrameworkTrackOpenPositionMae();` is the first statement in `OnTick`,
  before the kill-switch return.
- The current strict hardening analysis reports zero failures, including D7.

Governed compile row `1cab26d5-7a13-4cbd-8f5b-84ec57031d06` is correctly
bound to that MQ5 hash and completed `COMPILE_OK`. Its immutable evidence
records:

- `compile_result=PASS`
- `build_check_result=PASS`
- compiler errors/warnings `0/0`
- repaired-source EX5 SHA-256:
  `7a9ff6badcbf6f958abfb6e846137c2971b190e10ab1d2d41ff5d1c7e21a77c6`
- compile evidence SHA-256:
  `3cb2a559471412151590110f3bbe37a5e1206ea2486d3f6843b4d860d9cc7fa8`

The EX5 currently present in the canonical EA directory instead hashes to:

`aa7985bfb3154635a3254db7165d449c4bc0d7d6fad4fc846529c2baa80865e1`

That is the pre-repair binary previously reviewed on 2026-08-22 and committed
by `592cb57a61`. Git has no later commit for this EX5. Therefore the repository
does not contain the binary attested by the repaired-source compile receipt;
source and deployable artifact identity are inconsistent.

## Code review

The current source was compared directly with the OWNER-approved card and its
SPEC. Apart from the binary identity blocker, no new source defect was found:

- entry is the closed-H1 Chaikin zero cross, filtered by EMA(100) and
  ATR(14) >= 0.5 * ATR(100);
- initial stop is 1.7 * ATR(14), target is 2R, and the failsafe exit is 36 H1
  bars;
- only card-authorized EURUSD.DWX, GBPUSD.DWX, and XAUUSD.DWX identities are
  present;
- no ML, martingale, grid, scale-in, trailing, partial-close, or unapproved
  parameter was added;
- all three backtest sets use `RISK_FIXED=1000` and `RISK_PERCENT=0`;
- `qm_news_stale_max_hours` remains at the hard ceiling of 336, not above it.

## Focused verification

- `build_gate_hardening.py --ea-label QM5_12951_mql5-chaikin-zero-card`:
  **PASS**, zero failures/warnings; D7 MAE hook passes.
- `validate_build_guardrails.py <mq5>`: **PASS**, zero findings,
  `max_news_stale_hours=336`.
- `validate_symbol_scope.py --fail-on-leak`: **SINGLE_SYMBOL_OK**, zero
  violations.
- `validate_spec_doc.py <EA dir>`: **PASS**.
- `pytest .../test_build_gate_hardening.py -k mae_hook`: **1 passed**.
- Farm work-item query: governed row `1cab26d5...` is `done / COMPILE_OK`.
- SHA-256 comparison: canonical EX5 `aa7985...` != governed repaired-source
  EX5 `7a9ff6...`.

## Required disposition

Keep this Gemini-authored task in `REVIEW`. A separate, explicitly authorized
governed recovery must restore or reproduce the exact current-source binary
and seal its identity without overwriting pipeline history. This review does
not authorize another compile, does not change a pipeline verdict, and does
not approve the EA.


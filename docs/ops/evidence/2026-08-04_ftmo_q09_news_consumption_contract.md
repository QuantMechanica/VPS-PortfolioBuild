# FTMO Q09_NEWS consumption contract — 2026-08-04

Router task: `b2770c48-5cad-4b87-9cbc-b0aed0e41bff`
Authority: OWNER ratification, 2026-08-04
Scope: FTMO book admission and future FTMO configuration generation only

## Ratified semantics

OWNER re-ratified the original Q09_NEWS consumption rules on 2026-08-04:

1. an EA that is not prop-firm/FTMO-safe is excluded from the FTMO portfolio;
2. when performance is worse on news days, the locked temporal recommendation
   must block those news periods in the consumed configuration.

This artifact records the additive FTMO-side consumer. It does not alter the
DXZ dependency gate, Q09 adjudication, Q10, or any pipeline verdict.

## Where FTMO membership is decided

| Surface | Role before this change | Binding consumption now |
|---|---|---|
| `portfolio/ftmo_qualification.py` | Produces the `challenge_ready` pool from strict Q02–Q08/Q10, build, magic and stream evidence. | Calls the read-only Q09 predicate. Missing, unauthenticated, non-locked or non-FTMO evidence adds an explicit blocker and cannot yield `challenge_ready=true`. |
| `portfolio/ftmo_book_readiness.py` | Combines a proposed book, qualification inventory and stream reconciliation. | Defensively rejects stale qualification artifacts that omit the Q09 admission decision and emits `ftmo_q09_reason_code` per sleeve. |
| `portfolio/ftmo_timebox_eval.py` | FUND_SCORE/time-box composition evaluator pinned the inventory SHA but previously ignored its contents. | Consumes the frozen inventory; every composition sleeve must be both `challenge_ready` and `FTMO_Q09_ADMITTED`. Refusal codes are emitted in `sleeve_refusals`, `sleeve_admission`, and the composition result. FUND_SCORE remains screening-only and cannot override admission. |
| `portfolio/ftmo_book3_standalone_evaluator.py` | Consumed a research-only strict-qualification artifact. | Surfaces Q09 admission counts and reason codes; legacy artifacts without the additive field are explicitly classified `FTMO_Q09_EVIDENCE_MISSING`. Simulation cannot override that exclusion. |
| `portfolio/make_challenge_setfiles.py` | Derived challenge sets by changing risk and could silently preserve/default an unrelated news policy. | Requires a frozen admitted qualification row before writing anything, then binds Q09 `chosen_temporal` to `qm_news_temporal` and forces `qm_news_compliance=FTMO` (`2`). Its receipt binds the Q09 row and aggregate SHA. It starts no terminal and grants no trading authority. |

## Fail-closed admission predicate

The reusable implementation is
`tools/strategy_farm/portfolio/ftmo_q09_admission.py`.

For the latest completed Q09_NEWS row of an `(EA, symbol)`, admission requires:

1. both the work item and immutable `q09_news_tests` sidecar say
   `CONFIG_LOCKED`;
2. the work-item evidence path and `aggregate_path` resolve to the same file,
   the file SHA matches `aggregate_sha256`, and the embedded canonical
   adjudication hash and row fields authenticate;
3. FTMO coverage is one of:
   - `7x1_target_compliance` with `target_compliance=FTMO` and the locked
     compliance equal to FTMO; or
   - `7x4` with the complete canonical FTMO temporal/seed cell set;
4. the FTMO cells for `chosen_temporal` contain all five canonical seeds and
   remain viable under the Q09 selection-floor checks (trade count, PF,
   drawdown, Q07 seed stability, plus flat-at-event receipts for
   `CLOSE_ALL_PRE`).

The admitted deployment configuration always carries the locked
`chosen_temporal` and uses FTMO compliance, including when the source 7x4 row
was adjudicated for DXZ. A DXZ-only 7x1 row does not prove FTMO coverage.

Absence is exclusion. Principal reason codes include:

- `FTMO_Q09_EVIDENCE_MISSING`
- `FTMO_Q09_NOT_CONFIG_LOCKED`
- `FTMO_Q09_EVIDENCE_UNAUTHENTICATED`
- `FTMO_Q09_SCOPE_NOT_FTMO`
- `FTMO_Q09_FTMO_CELLS_INCOMPLETE`
- `FTMO_Q09_FTMO_CONFIG_NOT_VIABLE`
- `FTMO_Q09_ADMITTED`

## Guardrails

- No DXZ-side gate or view was changed.
- No Q-pipeline verdict is synthesized by this consumer.
- No `T_Live`, FTMO terminal, AutoTrading, or terminal process was touched.
- Backtest risk remains `RISK_FIXED > 0` and `RISK_PERCENT = 0`; the challenge
  generator is explicitly a future demo/deployment-config path and does not
  run a tester.
- `qm_news_stale_max_hours > 336` is rejected; the stale-news fail-closed
  contract is not weakened.

## Verification

```text
python -m pytest -q tools/strategy_farm/tests/test_ftmo_q09_admission.py tools/strategy_farm/tests/test_ftmo_qualification.py tools/strategy_farm/tests/test_ftmo_book_readiness.py tools/strategy_farm/tests/test_ftmo_timebox_eval.py tools/strategy_farm/tests/test_make_challenge_setfiles_q09.py
....................................................                     [100%]
52 passed in 3.80s
```

```text
python -m pytest -q tools/strategy_farm/tests/test_ftmo_book3_standalone_evaluator.py tools/strategy_farm/tests/test_prepare_ftmo_book3_standalone_diagnostic.py
................................................................         [100%]
64 passed in 15.81s
```

Targeted `py_compile` passed for all six changed/new consumer modules.

Read-only production-state probe for `QM5_13036/GDAXI.DWX` returned
`challenge_ready=false` with
`ftmo_q09_admission:FTMO_Q09_EVIDENCE_MISSING`, demonstrating the required
no-evidence exclusion against the current database (which had no immutable
Q09_NEWS adjudication rows at probe time).

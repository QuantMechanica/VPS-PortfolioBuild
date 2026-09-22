# Sunday preflight checklist addendum

Task: `01806354-1273-43de-9633-39ed0ac2f1d7`  
Authority: `OWNER-DEC-FTMO-FINAL-MEGA-20260921`  
Scope: six checklist additions accepted from critique `cb0eb674`; read-only toward the FTMO Demo terminal, T_Live, and AutoTrading.

## Verdict

**PASS_FOR_REVIEW.** `sunday_preflight.py` now emits all six missing rows with explicit evidence paths and `GREEN`, `RED`, or `NOT_CHECKABLE` states. The four launch-critical additions are live-news binding, terminal/chart trading permission, weekend no-tick rollover, and clean initial account. Request-threshold configuration and the attribution dry-run are non-critical rows, as directed.

| Added row | Critical | D2g6 rehearsal | Bound evidence | Result basis |
|---|---:|---|---|---|
| `live_news_feed_binding` | yes | **RED** | `docs/ftmo/FTMO_SUNDAY_LAUNCH_STATUS.md` | No evidence yet binds all six Sunday presets to a fresh daily live-calendar seed in both `D:/QM/data/news_calendar` and `FILE_COMMON` while excluding the static Q09 backtest CSV. |
| `terminal_autotrading_flag` | yes | **NOT_CHECKABLE** | `docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md` | The Sunday generation is not attached. `TERMINAL_TRADE_ALLOWED == 1` and `trading_allowed == true` on all six charts remain post-attach proofs; the preflight does not toggle either setting. |
| `weekend_non_tick_rollover` | yes | **RED** | `docs/ops/evidence/2026-09-22_ftmo_kill_switch_governed_initializer/task_d6189118-c2e7-4517-a914-049c89d19a75/verification.json` | The wall-clock/OnTimer implementation is built, but the receipt says `runtime_proof_status=PENDING_OWNER_SIGNED_DEPLOY`; no post-boundary `KS_DAY_ROLLOVER` runtime event exists yet. |
| `server_request_thresholds` | no | **GREEN** | `docs/ops/evidence/2026-09-22_ftmo_kill_switch_governed_initializer/task_d6189118-c2e7-4517-a914-049c89d19a75/README.md` | The pulse contract is WARN `200`, LIMIT/ALARM `500`, and ALARM above `25` requests in a rolling `60` seconds. The GREEN declaration requires that exact marker in the evidence file. |
| `clean_initial_account` | yes | **NOT_CHECKABLE** | `docs/ftmo/genesis/SUNDAY_LAUNCH_RUNBOOK_2026-09-27.md` | The required `100000.00` balance, zero positions, and zero orders must be captured immediately before the Sunday chart attach. |
| `sleeve_attribution_dry_run` | no | **GREEN** | `D:/QM/reports/state/ftmo_sleeve_attribution.json` | The accepted `74c41987` sidecar exists, reports `reconciliation_ok=true`, and has `difference_usd=0.0`. The GREEN declaration requires the zero-difference marker. |

The pre-existing `sleeve_attribution` row was also refreshed from stale RED text to GREEN against the accepted sidecar. No gate criterion was weakened.

## D2g6 rehearsal

The read-only rehearsal was rerun against manifest `FTMO_DEMO_BOOK_V3_D2G6_20260918_REHEARSAL` and remains **NO_GO**:

- `GREEN=19`
- `RED=10`
- `NOT_CHECKABLE=5`

The six additions contribute two GREEN, two RED, and two NOT_CHECKABLE rows. The manifest's automatic drift row is currently RED with four drift items: the governed-initializer source changes in sleeves `11422` and `10403`, plus subsequently changed EA-ID and magic registries. The preflight did not rebuild or re-seal the manifest and therefore did not conceal that drift.

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_genesis_manifest.py -q
.................                                                        [100%]
17 passed

python -m py_compile tools/strategy_farm/ftmo/sunday_preflight.py
PASS

python -m json.tool docs/ops/evidence/2026-09-21_ftmo_genesis_manifest_tooling/preflight_evidence_rehearsal.json
PASS

python tools/strategy_farm/ftmo/sunday_preflight.py <manifest> --evidence-config <config> --output-json <json> --output-md <md>
decision=NO_GO; GREEN=19; RED=10; NOT_CHECKABLE=5; exit=2 (expected fail-closed rehearsal)
```

The parameterized suite exercises GREEN and RED evidence-bound fixtures for every added row and verifies the required criticality. No terminal process was launched, no chart was attached, no order was placed, and neither AutoTrading nor T_Live was changed.

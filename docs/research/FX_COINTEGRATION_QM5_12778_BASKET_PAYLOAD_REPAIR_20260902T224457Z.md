# QM5_12778 FX cointegration basket payload repair

Recorded: 2026-09-02T22:44:57Z (2026-09-03 00:44 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `73ded4490aa773ed9f97ee616cc9847f719e375c`

## Outcome

The existing low-frequency D1 fallback `QM5_12778` AUDUSD/EURJPY was advanced
without creating a duplicate card or queue row. Its already priority-bound,
non-admission Q09_NEWS diagnostic row
`24acc5d4-3e34-526e-a7a8-12640a2e759f` now carries the complete, SHA-bound
four-symbol basket manifest context required by terminal claim admission.

The row remains pending and unclaimed for the resident fleet. No worker or
terminal was launched manually.

## Why this was the correct fallback

The frozen sign-aware 66-pair scan is already fully mechanized: the durable
reconciliation in
`docs/research/FX_COINTEGRATION_FALLBACK_AUDIT_CPU_STOP_20260902T204902Z.md`
found 66/66 represented and no unbuilt relationship. The two preferred anchors
also have genuine Q02 passes rather than current ONINIT/NO_HISTORY blockers:

- `QM5_12532` AUDUSD/NZDUSD: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY: Q02 PASS, then Q04 FAIL.

That leaves advancement of a governed existing FX basket as the non-duplicate
mission path. `QM5_12778` already has Q02 through Q07 passes, a Q08 FAIL_SOFT,
and the unique OOS-2026 diagnostic row above. It is structural (fixed-beta log
spread), D1/low-frequency, and its diagnostic setfile contract remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Defect and repair

The diagnostic enqueue path emitted only `host_symbol=AUDUSD.DWX`. It omitted
the EA's checked-in `basket_manifest.json` and its symbol lists. That produced
two concrete worker-side faults before any strategy evaluation:

1. copy-on-claim could see only AUDUSD history, not the required EURJPY traded
   leg or EURUSD/EURAUD conversion histories;
2. the registered multisymbol EA defaulted to the 44 GB
   `heavy_or_unknown_multisymbol` reservation because it lacked a complete,
   internally consistent `basket_symbols` list.

`tools/strategy_farm/oos_2026_confirmation.py` now resolves and validates a
single checked-in basket manifest for every future campaign enqueue. It binds:

- `basket_symbols`: AUDUSD.DWX, EURJPY.DWX, EURUSD.DWX, EURAUD.DWX;
- `traded_symbols`: AUDUSD.DWX, EURJPY.DWX;
- derived `conversion_symbols`: EURUSD.DWX, EURAUD.DWX;
- host/logical symbol, D1 timeframe, EUR tester account, manifest path and
  manifest SHA-256.

The same module now exposes a guarded one-row repair command. It accepts only
an unclaimed pending Q09_NEWS backtest in the authenticated
`oos-2026-confirmation-v1` non-admission lane, refuses existing-field
contradictions, rechecks the payload pre-image under `FactoryMutationLock` and
`BEGIN IMMEDIATE`, and uses a payload compare-and-swap update.

Applied evidence:

- manifest SHA-256:
  `0ce25d17ebe7c3664e4acdb6c1d302b28b1f40710301189cc633e44f25854d57`;
- payload before:
  `4b480ef617bc8245b12712f7a933ab24c3524f25852efb7976a1bbbeabe30d04`;
- payload after:
  `7b2f7d95001a9330acda995ba0cd7e02e264cad8a5d9b5e6cb158313ec8a44f6`;
- changed rows: exactly 1;
- machine journal:
  `artifacts/fx_cointegration_qm5_12778_basket_payload_repair_20260902T224448Z.json`.

Post-apply evaluation through the resident worker's own helpers resolves all
four required history symbols and classifies the item as
`multi_leg_fx_basket`, the measured 32 GB reservation class, rather than the
44 GB unknown fallback.

## Capacity and safety

Immediately before apply, five two-second CPU samples were 79.2%, 83.8%,
74.7%, 69.5%, and 76.5% (average 76.7%, maximum 83.8%), below the 97% hard
stop. Free physical RAM was 24.3/63.1 GB. The payload mutation itself does not
run a backtest; the resident worker retains its 48 GB multisymbol commit
headroom gate and therefore left the row pending at verification time.

No Strategy Card, EA, setfile, registry, magic row, priority flag, historical
verdict, portfolio-admission/KPI/Q08-contribution surface, portfolio gate,
T_Live manifest, AutoTrading state, or live/deploy surface was changed.

## Validation

- `python -m pytest tools/strategy_farm/tests/test_oos_2026_confirmation.py
  tools/strategy_farm/tests/test_q09_news_runner_v2.py -q` -> 51 passed.
- `python -m py_compile tools/strategy_farm/oos_2026_confirmation.py` -> PASS.
- `git diff --check` on the implementation and test -> PASS.
- Live post-apply row read -> `pending`, `claimed_by=null`, four history
  symbols, `multi_leg_fx_basket`, fixed-risk values unchanged.

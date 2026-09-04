# QM5_12778 FX cointegration targeted OOS-window repair

Recorded: 2026-09-04T22:49:53Z (2026-09-05 00:49 Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

The governed 66-pair FX cointegration frontier remains fully mechanized, so no
duplicate card, EA, registry row, setfile, basket manifest, or Q02 row was
created. The two preferred anchors also require no Q02 repair:

- `QM5_12532` has canonical logical-basket Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533` has canonical logical-basket Q02 PASS, then Q04 FAIL.

The selected existing-card fallback was
`QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`. Its unique priority-bound
`Q09_NEWS` row `24acc5d4-3e34-526e-a7a8-12640a2e759f` was still pending but
held by `OOS_WINDOW_MISMATCH`: the payload omitted the explicit dates declared
by campaign `oos-2026-confirmation-v1`.

The row is now runnable. Its payload is bound to `2026.01.01` through
`2026.04.06`, the exact `OOS_WINDOW_MISMATCH` hold is released, and the row
retains `priority_track=true` and `q09_activation_state=RUNNABLE_BOUND`.
No successor row was minted because the selected row had never run.

## Scoped repair path

The existing `repair-oos-window` command operated on the entire 55-row
cross-asset campaign. To keep this mission to one concrete FX pair, the command
now accepts a repeatable `--work-item-id` selector. The selector:

- filters by both campaign identity and exact primary key;
- fails closed if a requested ID is absent or belongs to another campaign;
- preserves the full-campaign behavior when omitted; and
- uses the existing payload SHA CAS, governed state backup, mutation lock,
  hold-release ledger, and post-commit receipt machinery.

Focused tests prove that both dry-run and apply exclude every unselected
campaign row byte-for-byte. The complete window-repair suite passed: 36 tests.

The targeted dry-run selected exactly one campaign row, one payload patch, and
one hold release. Apply produced:

- payload before SHA-256:
  `7b2f7d95001a9330acda995ba0cd7e02e264cad8a5d9b5e6cb158313ec8a44f6`;
- payload after SHA-256:
  `5b7613207b9f89bd466b9165d6b257c4f1d97e33a954be3c6c66f6be9c6d7589`;
- campaign-plan SHA-256:
  `6ade6b3491dabe74773abc2bfb31d597f48db78f01ece41759667b9b5088dfad`;
- pre-mutation backup SHA-256:
  `3e6173639d9c9d37c756448747706c4d906e630a7eba6bcccf6801451548a573`;
- patched rows: 1; released holds: 1; minted successors: 0.

Machine-readable receipt:
`artifacts/fx_cointegration_qm5_12778_oos_window_repair_20260904T224953Z_board_advisor.json`.

An immediate second targeted dry-run was idempotent: zero patches, zero hold
releases, zero successors, and one unchanged row.

## Capacity and safety

The five whole-host CPU samples immediately before apply were `74.1256%`,
`81.4011%`, `82.9110%`, `79.4061%`, and `79.7006%`. The five post-apply samples
were `80.5069%`, `85.5943%`, `76.4823%`, `85.9412%`, and `89.4612%`. Both
windows remained below the 97% hard ceiling. No tester or terminal was launched
manually; ordinary paced workers retain claim and dispatch ownership.

No portfolio-admission, portfolio-KPI, Q08-contribution, portfolio-gate,
`T_Live` manifest, live deployment artifact, terminal, or AutoTrading state was
touched.

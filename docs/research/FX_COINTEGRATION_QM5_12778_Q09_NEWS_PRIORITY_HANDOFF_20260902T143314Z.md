# QM5_12778 FX cointegration verification handoff

Generated: 2026-09-02T14:33:14Z
Branch: `agents/board-advisor`

## Outcome

QM5_12778, the D1 AUDUSD/EURJPY market-neutral cointegration basket, was advanced by marking its sole open `Q09_NEWS` diagnostic row for paced priority. The mutation is queue metadata only: no tester was dispatched, no strategy or binary was changed, and no portfolio-admission or live surface was touched.

- Work item: `24acc5d4-3e34-526e-a7a8-12640a2e759f`
- Phase and host: `Q09_NEWS`, `AUDUSD.DWX`
- State after mutation: `pending`, unclaimed, attempt 0, no verdict
- Priority mark: `true` at `2026-09-02T14:31:41+00:00`
- Reason: `board_advisor_fx_existing_card_fallback_q09_news_after_exhausted_66_pair_frontier`
- Audit trail: append-only `D:/QM/reports/state/priority_track_marks.jsonl`

The payload is explicitly `diagnostic_non_admission=true`, uses `RISK_FIXED=1000` and `RISK_PERCENT=0`, permits only T1-T5 diagnostic terminals, and avoids T6-T10. The action does not itself claim or execute the row.

## Why the existing-card fallback was used

The durable frontier guard at `artifacts/fx_cointegration_frontier_ownership_guard_20260902T133112Z_board_advisor.json` records complete coverage of the frozen 66-pair scan: 123 approved identities, 123 matching EA directories, and zero approved unbuilt identities. Creating another scan-derived card or EA would therefore duplicate governed coverage.

The preferred repair condition also does not apply. QM5_12532 (AUDUSD/NZDUSD) and QM5_12533 (EURJPY/GBPJPY) both have Q02 PASS and no current Q02 setup blocker. This leaves the mission-authorized fallback: advance one existing forex card.

## Sleeve contract

The approved card is `strategy-seeds/cards/approved/QM5_12778_edgelab-audusd-eurjpy-cointegration_card.md`. It is the rank-25 AUDUSD/EURJPY tail pair from the Darwinex `.DWX` D1 scan and cites Ernest P. Chan's cointegration method plus the reproducible in-house scan.

Its mechanics remain structural and low frequency:

- Fixed spread: `ln(AUDUSD) - 0.279193 * ln(EURJPY)`.
- Closed-D1 evaluation with a 60-bar rolling z-score.
- Enter beyond absolute z-score 2.0; exit inside 0.5.
- ATR(20) x 2.0 protective stops and immediate broken-package cleanup.
- Approximately 4-8 logical packages per year.
- No ML, grid, martingale, averaging, or pyramiding.

The required basket manifest remains present at `framework/EAs/QM5_12778_edgelab-audusd-eurjpy-cointegration/basket_manifest.json`, with AUDUSD.DWX and EURJPY.DWX as traded legs.

## Mutation verification

Before the governed command, the row was the only open QM5_12778/AUDUSD `Q09_NEWS` identity, with no active hold and no supersession edge. Its raw payload SHA-256 was `53b7c75f4fb332e6b528149c1b79d1cc4697f22f837653838a42e3f10ec4ef23`.

After `farmctl mark-priority-track`, the row remained pending, unclaimed, attempt 0, and verdict-null. Only priority metadata and `updated_at` changed; the raw payload SHA-256 became `4b480ef617bc8245b12712f7a933ab24c3524f25852efb7976a1bbbeabe30d04`. The diagnostic anchor, input manifest, and run-plan hashes in the payload remained sealed.

Repository package observations were recorded without changing the files:

- MQ5: `132a501d94685f013cc62a8b3c2de111d0a8b1e616a8656d2c61b061a754c146`
- EX5: `2a105cfbb364142c96c552136bb450162c142845665ce3366d0c045248c17a01`
- Basket manifest: `0ce25d17ebe7c3664e4acdb6c1d302b28b1f40710301189cc633e44f25854d57`
- Logical RISK_FIXED backtest setfile: `0e7949276927c8c5355c413c631e7b67f684e757892de59fa2cff5521836c8e9`

These repository hashes are observations only; they are not asserted to equal the separately sealed Q09 diagnostic copies.

## Capacity and exclusions

Five CPU samples were 58.1%, 62.9%, 55.5%, 59.4%, and 59.9% (average 59.2%, maximum 62.9%), below the 97% ceiling. No backtest or dispatch was started.

No changes were made to `portfolio_admission`, `_kpi`, `_q08_contribution`, the portfolio gate, the T_Live manifest or files, terminal controls, or AutoTrading.

Machine-readable evidence: `artifacts/qm5_12778_q09_news_priority_20260902T143314Z_board_advisor.json`.

# QM5_1572 build preflight — deterministic stop

- Router task: `e743e2c4-1e35-479b-94d3-20e955efc53e`
- Task type / priority: `build_ea` / `50`
- Canonical checkout: `C:/QM/repo`
- Branch / inspected HEAD: `agents/board-advisor` / `30a2627650d89497bcb10b583e6feb6ec86f639e`
- Verdict: `REVIEW — BUILD_NOT_STARTED_SPEC_AND_MECHANIC_UNIMPLEMENTED`

## Governed preflight

| Gate | Evidence | Result |
|---|---|---|
| Approved Strategy Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1572_aa-ls-mom-bear24.md` declares `ea_id: QM5_1572`, matching folder slug, and `g0_status: APPROVED` | PASS |
| Exact active EA registry identity | `1572,aa-ls-mom-bear24,ede348b4-0fa7-5be1-baa8-09e9089b67b7,active,Research,2026-05-19,,,` | PASS |
| Magic registry | 13 active rows exist in `framework/registry/magic_numbers.csv` | PASS |
| Magic Resolver array | `QM_MAGIC_REG_EA_ID` in `framework/include/QM/QM_MagicResolver.mqh` does not contain `1572` | FAIL |
| Existing source | `QM5_1572_aa-ls-mom-bear24.mq5` contains only the generic un-implemented skeleton (entry returns `false`) | OBSERVED |
| Strategy specification | No `SPEC.md` exists in `framework/EAs/QM5_1572_aa-ls-mom-bear24/` | OBSERVED |
| Cross-asset proxy mapping | Card specifies cross-asset relative momentum ranking across universe with 24-month market regime filter; card R3 is `UNKNOWN` requiring governed universe/proxy mapping | INSUFFICIENT |
| Governed compile | `compile_ea.py --ea-id 1572 --force --json` returned `COMPILE_FAILED` with `INCLUDE_MIRROR_REFUSED` | BLOCKED |

The EA directory contains only the generic skeleton and 13 set files, without
an implemented strategy mechanic or `SPEC.md`. Furthermore, `1572` has not been
regenerated into `QM_MagicResolver.mqh`, and ad-hoc compilation is blocked by
the live-factory include mirror guard.

Per standing rules, Gemini may draft code but Codex review is mandatory before
acceptance, and un-implemented or un-compiled builds must remain in REVIEW.
No terminal was launched or interrupted, and AutoTrading/T_Live were not touched.

## Focused verification

```text
rg '^(1572),' framework/registry/ea_id_registry.csv framework/registry/magic_numbers.csv
=> ea registry: 1572,aa-ls-mom-bear24,...,active,...
=> magic registry: 13 active rows (GDAXI, NDX, SP500, UK100, WS30, XAUUSD, EURUSD, GBPUSD, USDJPY, USDCHF, AUDUSD, USDCAD, NZDUSD)

rg '1572' framework/include/QM/QM_MagicResolver.mqh
=> no matches

python tools/strategy_farm/compile_ea.py --ea-id 1572 --force --json
=> COMPILE_FAILED (reason_class=INCLUDE_MIRROR_REFUSED)
```

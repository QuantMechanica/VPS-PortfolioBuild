# DXZ six-PASS execution-governance blocks — 2026-07-16

## Decision

An as-live evidence `PASS` proves reproduction of a frozen stream; it does not
approve a strategy semantic. Three reproduced sleeves remain fail-closed in
`framework/registry/dxz23_execution_contracts.json`:

| EA / symbol | Audit evidence | Unresolved semantic | Registry decision |
|---|---|---|---|
| 10403 / XAUUSD.DWX | FULL receipt `runs/01_10403_XAUUSD_DWX/receipt.json`, declared receipt SHA-256 `e770fc12b4fe6ad3116302a1e0cbd31a4a3b671a2c2497baa19e6e4fcae2c901`, 209/209 exact | 187 of 209 close timestamps are Friday 21:00. The approved Card specifies a continuously moving 10-day channel exit (lines 35 and 45–48), so the framework close materially replaces the Card exit in most trades. | `BLOCKED`; Friday contract itself is `BLOCKED` |
| 12969 / USDJPY.DWX | FULL receipt `runs/19_12969_USDJPY_DWX/receipt.json`, declared receipt SHA-256 `22c28db9cb8d7664c526243f7f274ae9cfa1e6b10a28452265f736f1021c8e19`, 331/331 exact | Approved Card line 68 says no fixed price stop. The exercised binary has a 120-pip stop and the native report contains two stop-loss exits out of 331 trades. | `BLOCKED` pending Card-v2 reconciliation |
| 13128 / NDX.DWX | FULL receipt `runs/21_13128_NDX_DWX/receipt.json`, declared receipt SHA-256 `9db5369054e30babccd7fd117790da4354f23f27eb9200617467b716f7c3fc85`, 56/56 exact through 2025-12-31 | Approved Card lines 31 and 52 end the fixed calendar in 2025, while the remediated source/contract extends it through 2026. A test ending in 2025 cannot qualify that extension, and the remediated source is not yet synchronized with a qualified binary. | `BLOCKED` pending Card/calendar/source/binary synchronization |

The FULL sweep root is
`D:\QM\reports\portfolio\dxz23_as_live_requal_20260716_hardened\20260716T051551Z`.
The 10403 count is a direct classification of the 209 `TRADE_CLOSED.time`
values in `runs/01_10403_XAUUSD_DWX/q08_stream.jsonl`; 187 resolve to Friday
21:00. The 12969 count is the two outgoing native-report deals whose comment is
`sl <price>` in `runs/19_12969_USDJPY_DWX/report.htm`.

## Machine enforcement

Unresolved Card/runtime semantic reasons use the narrow
`unresolved_semantic_conflict_*` prefix. The execution-contract linter rejects
both `ELIGIBLE` and `REQUAL_REQUIRED` for a contract carrying such a reason; it
also rejects promotion weaker than `BLOCKED` when the Friday sub-contract is
itself `BLOCKED`. This prevents an evidence-only PASS from silently promoting
these sleeves.

EA 11132 is separately blocked pending full requalification of the explicit
`SP500.DWX` test-symbol to `SP500` live-order-symbol mapping plus its open
Friday/Card/source/binary gates. Direct SP500 routing is proven; NDX/WS30
substitution is optional derivative research, not required remediation.

## Unblock conditions

No trading semantics are selected here. Each sleeve requires an explicit
approved Card-v2 decision, synchronized source/binary/preset identities, and a
fresh FULL requalification of that exact contract. Until all are present, none
of the three sleeves is deployable or book-admissible.

Validation:

```powershell
python -m pytest tools/strategy_farm/tests/test_execution_contract_lint.py -q
python tools/strategy_farm/execution_contract_lint.py --contracts framework/registry/dxz23_execution_contracts.json --repo-root . --as-of 2026-07-16
```

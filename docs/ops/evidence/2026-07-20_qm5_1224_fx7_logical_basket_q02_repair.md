# QM5_1224 FX7 Logical-Basket Q02 Infrastructure Repair

## Outcome

`QM5_1224_white-okunev-fx-xmom` is now a compile-clean, single-host logical
FX basket instead of seven independent chart instances. Six stranded component
Q02 rows were atomically retired as `INVALID`, and exactly one logical Q02 row
is pending:

| Field | Value |
|---|---|
| Agent task | `19983f60-f3ba-4c18-9f5c-bef086d37f65` → `PIPELINE` |
| Q02 work item | `ed171be3-4dfb-47b7-80c9-11af01a6a24d` → `pending` |
| Logical symbol | `QM5_1224_FX7_XMOM_D1` |
| Tester host | `EURUSD.DWX`, D1 |
| Test window | `2017.01.02`–`2024.12.31` |
| Tester account | USD 100,000 |
| Risk preset | `RISK_FIXED=500` per leg, `RISK_PERCENT=0` |

This is a queue handoff, not a profitability claim. Q02 owns the economic
verdict.

## Why This Unit Was Selected

The priority-one diversity backlog was not safely buildable under the V5 build
contract. The approved rates and lumber-relative-value candidates require
unavailable non-DWX inputs, while the available fresh FX candidates lacked
pre-authorized magic-slot allocations. The concurrently claimed XNG build was
owned by another paced lane.

The farm had already assigned this branch a distinct priority-two repair for
`QM5_1224`. It is a reputable-source, low-frequency FX sleeve based on Derek R.
White and John Okunev's 2001 cross-sectional currency-momentum paper. Its prior
Q02 topology was invalid: each row launched one currency pair even though the
signal requires ranking seven USD crosses and trading one long/short package.
Historical rows consequently produced `NO_HISTORY`/`INFRA_FAIL` results that
could not represent the strategy.

## Diagnosis And Repair

The retained `.ex5` predated the current `.mq5`. A partial earlier conversion
also left undefined variables and function calls in the source, so it could not
be rebuilt. The repair now:

- accepts only one `EURUSD.DWX` D1 host at magic slot 0;
- warms and ranks `EURUSD`, `GBPUSD`, `AUDUSD`, `NZDUSD`, `USDCAD`, `USDCHF`,
  and `USDJPY` as one aligned D1 universe;
- uses the V5 SMA reader and calendar-period keys rather than per-EA raw
  indicator/calendar implementations;
- compares current and previous calendar keys so a mid-month restart cannot
  masquerade as the first trading day;
- opens the strongest/weakest currency legs through `QM_BasketOpenPosition`,
  with exact slot magic, preflight sizing, hard `3 × ATR(20)` stops, and
  compensating rollback if the package is incomplete;
- retains a leg only inside its top/bottom-two band and flattens any orphan or
  invalid two-leg composition;
- scales the `2R` combined loss rail from the framework's effective risk money,
  which remains correct in both fixed and percent modes; and
- explicitly disables Friday close because weekly flattening contradicts the
  approved monthly rank-retention exit. Framework kill switch, hard stops, and
  basket loss management remain active.

The synchronized D1 history registry intersection is 2017–2024. `AUDUSD`,
`NZDUSD`, `USDCAD`, and `USDCHF` define the 2024 end bound.

## Validation

| Check | Result |
|---|---|
| SPEC validator | PASS |
| Build guardrails | PASS, no findings |
| Symbol scope | `BASKET_OK`, zero violations |
| Strict MetaEditor compile | PASS, 0 errors, 0 warnings |
| Strict build check | PASS, 0 failures, 0 warnings |
| FX basket contract tests | 20 passed |
| Compile log | `C:/QM/repo/framework/build/compile/20260720_152909/QM5_1224_white-okunev-fx-xmom.compile.log` |
| Build-check report | `D:/QM/reports/framework/21/build_check_20260720_152932.json` |
| MQ5 SHA-256 | `c15a1a06fb603aad5377f1552eac027cedbd3436171da681e7384a6349911b81` |
| EX5 SHA-256 | `86b39be76df5638cf3c31df241ca8795305c90eb196e21b7c743a3b90d38ab89` |
| Logical set SHA-256 | `4cf043eb6fb66506fc9ea2e9e0eab29ab0784f5ac8a36bb52bb07c1c2041d27e` |

The wider `test_basket_work_items.py` run had 31 passes and four failures in
pre-existing mocks that do not implement the farm's newer immutable process
identity arguments/capture. The new `QM5_1224` contract test and all 20 FX
basket manifest tests passed; this repair does not change process management.

## Atomic Farm Handoff

Before mutation the canonical farm DB was backed up to:

`D:/QM/strategy_farm/state/backups/farm_state_before_qm5_1224_fx7_q02_repair_20260720T153609Z.sqlite`

Inside one `BEGIN IMMEDIATE` transaction, the claim, absence of active
`QM5_1224` work, exact six-row component set, and absence of an existing logical
row were rechecked. These pending standalone rows were retired as
`INVALID / LOGICAL_BASKET_SUPERSEDES_COMPONENT`:

| Symbol | Retired work item |
|---|---|
| AUDUSD.DWX | `eea1946f-f1a2-4bc3-b6a1-b77786ecdd50` |
| EURUSD.DWX | `b4656b36-94c5-4120-8291-7b90da30efd4` |
| GBPUSD.DWX | `71214216-b48d-4633-82e3-4add7661025d` |
| USDCAD.DWX | `aae801b2-bc12-474a-82db-61d8a0b1dfb9` |
| USDCHF.DWX | `348b70cc-5400-48b8-8545-2e14e30d7933` |
| USDJPY.DWX | `e0315cdf-ef11-4576-a51f-2d19ebd450b1` |

The replacement payload carries `portfolio_scope=basket`, all seven basket
symbols, host/timeframe, USD tester overrides, synchronized dates, fixed-risk
metadata, manifest path, and the compile/build-check evidence paths.

## CPU And Safety Boundary

At handoff, six pipeline terminals were active (`T2`, `T3`, `T4`, `T6`, `T8`,
`T9`). The paced CPU ceiling therefore prevented a manual smoke/backtest; the
repair only enqueued Q02 and did not dispatch it.

No terminal was launched or stopped. No AutoTrading state, `T_Live` file,
portfolio gate, live manifest, registry, or magic resolver was changed. The
14 historical component/live setfiles were restored byte-for-byte after the
build checker refreshed their hashes; only the new logical RISK_FIXED backtest
preset is part of this handoff.

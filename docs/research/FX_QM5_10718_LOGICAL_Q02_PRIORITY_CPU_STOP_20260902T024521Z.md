# QM5_10718 logical FX8 Q02 priority preflight — CPU stop

Date: 2026-09-02 UTC (`2026-09-02T02:45:21.8115178Z`)

Branch: `agents/board-advisor`

Status: **STOPPED before runtime mutation.** The five-sample host CPU window
peaked at 97.5%, crossing the mission's 97% ceiling. No queue payload, work
item, tester, terminal, or pipeline verdict was changed.

## Frontier reconciliation

The controlling 66-pair scan has no unbuilt relationship. Its only strict
qualifiers are the already-built anchors:

| EA | Relationship | Canonical frontier |
| --- | --- | --- |
| `QM5_12532` | AUDUSD / NZDUSD | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY / GBPJPY | Q02 PASS, Q04 FAIL |

The latest complete census records 123 approved cointegration/coint
identities, 123 matching EA directories, and zero unbuilt identities across
all 66 relationships. Neither anchor has a current Q02 ONINIT or NO_HISTORY
blocker. Creating another scan-derived card or EA would therefore duplicate
governed coverage.

The mission's existing-forex fallback was selected instead:
`QM5_10718_edgelab-regime-filtered-carry`, an approved structural D1 FX8
market-neutral carry basket. It rebalances weekly, uses no learned model, and
is grounded in Lustig, Roussanov and Verdelhan (RFS 2011) and Menkhoff et al.
(JF 2012).

## Exact Q02 preflight

Fresh logical Q02 work item `31f12573-d903-4386-a857-cad2b445d63a` is still
pending, unclaimed, attempt zero, and unverdict for
`QM5_10718_FX8_BASKET_D1`. It is the only matching open Q02 row and has no
active hold or supersession relation.

Its immutable execution hashes match the current files:

| Artifact | SHA-256 |
| --- | --- |
| MQ5 | `92fa06a272aa4805e31c6caac4f1ad9feeaf91fec18c349a616bf2cae00f8f00` |
| EX5 | `10358a8dd852cd495265fc4099dfb7d9fecc711a047d98a4ff5eafbba51a91cc` |
| Basket manifest | `8dc0776c1aac52f566b0f0b33f390f34d222bae8bc20992f7740bcce5d0b458f` |
| Logical setfile | `cbc4602cc7685d7db68e9e17603916e4b66706ba9566248bf975c2a4782bd680` |

The logical preset remains `RISK_FIXED=500`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Build hardening passed with zero failures or warnings;
the 30-file build-guardrail check passed with zero findings. The legacy
package has no `SPEC.md`, so no SPEC-validator pass is claimed.

A read-only canonical-order simulation showed that the bounded priority flag
would move this exact row from rank 7,225 to rank 1,436 without creating a
duplicate. That compare-and-swap was deliberately not applied.

## CPU stop and safety

The samples were 97.5%, 97.1%, 89.3%, 90.5%, and 86.4% (average 92.16%,
maximum 97.5%). Because the hard rule stops on either the average or maximum,
the maximum triggered the ceiling.

No manual dispatch or MT5 action was attempted. No portfolio gate,
`portfolio_admission`, portfolio `_kpi`, `_q08_contribution`, T_Live,
AutoTrading, live/deploy manifest, or Q08 state was touched. Unrelated shared
worktree changes were preserved.

Machine-readable receipt:
`artifacts/qm5_10718_fx8_q02_priority_cpu_stop_20260902T024521Z_board_advisor.json`.

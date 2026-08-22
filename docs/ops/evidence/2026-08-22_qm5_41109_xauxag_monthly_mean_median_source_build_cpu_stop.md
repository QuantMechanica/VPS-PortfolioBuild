# QM5_41109 XAU/XAG monthly mean-median source build and CPU stop

Date: 2026-08-22

Branch: `agents/board-advisor`

EA: `QM5_41109_xauxag-mmean-median-rv`

## Outcome

QM5_41109 is a committed, non-duplicate source build for one low-frequency,
market-neutral commodity package. At the first synchronized D1 boundary of a
broker month it computes the arithmetic mean and ordinary sample median of the
completed month's synchronized `log(XAUUSD.DWX close) - log(XAGUSD.DWX close)`
observations. A strict mean-above-median displacement is faded by selling XAU
and buying XAG; a strict mean-below-median displacement is faded in the other
direction. Equality stays flat. The pair targets equal absolute notionals and
owns one combined fixed-risk budget.

This is source-build complete but not compiled. The governed compile item is
held, and the capacity sample then crossed the binding 97% CPU ceiling. Per the
mission stop rule, no Q02 was enqueued and no further tester work was started.

## Durable trail

| Stage | Commit |
|---|---|
| OWNER source approval | `4a1957e0c` |
| EA-ID reservation | `f22c701a4` |
| Reproducible source extraction | `088014c50` |
| Approved G0 Strategy Card | `edf907373` |
| Magic allocation and resolver regeneration | `15b85fc29` |
| EA source, SPEC, basket manifest, reference suite, fixed-risk set | `60e9b5192` |

The source case combines the peer-reviewed gold/silver-ratio literature in the
Schweikert intake with CME's official gold/silver spread treatment. The precise
completed-month mean-versus-median trading rule is disclosed as the QM
mechanization, not attributed verbatim to either source. Pre-allocation
identity/fuzzy checks found no foreign duplicate. In particular, QM5_41104
compares medians across adjacent months, while QM5_41109 compares mean against
median inside one completed month.

## Build contract and source validation

- Host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `411090000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `411090001`.
- Logical basket: `QM5_41109_XAU_XAG_MMEAN_MEDIAN_RV_D1`.
- Backtest set: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`; `build_hash=pending` until a real compile PASS exists.
- Build prerequisite guard: PASS.
- Card schema lint and deterministic G0 lint: PASS.
- SPEC validator: PASS.
- Build guardrails: PASS across the EA source and setfile.
- Symbol-scope validator: `BASKET_OK`, with exactly XAU and XAG declared and
  referenced.
- Independent deterministic reference suite: 11/11 PASS.
- Approved card and EA-local card SHA-256 are byte-identical.
- No `.ex5` exists and no compile result is claimed.

Key SHA-256 bindings:

| File | SHA-256 |
|---|---|
| MQ5 | `CB72A16D7100D2A9494D63399544C5E63A24CAFEF23AC3DD128DAA47069A5FB7` |
| SPEC | `0BA8EA80B574DB6D28A3F2B03A7666BE5BA0B9A78356AD3D86F23E607A7A2008` |
| Basket manifest | `21D5DA2E4F596028B7D75DCE45A389496FB57233024B5422B08B7203EE0D1859` |
| Reference test | `F2A8F0AB9FDD363D81D64258D40D40703B922676A0F719FEA15B9068BDD12357` |
| Approved/local card | `6FECFD8072ECFBF9F8E2BD9BD40466D69E1C7162314063D85EBCBE61057178E4` |
| Backtest set | `25356C4ADFA86AC8D472761B2988B7A93A009A1353AE19E73DE2B93A893288C6` |

## Compile handoff

The strict local compile path refused fail-closed with
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`: active `terminal64` processes made the
shared include-mirror operation unsafe. No terminal was stopped, no override
was used, and the refusal occurred before a compile log or binary was written.

The canonical compile enqueue is idempotently present:

- Work item: `55cdd439-9f1e-4d26-a917-66a23b783abe`
- Status: `pending`
- Activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`
- Build-check result: none
- `.ex5` SHA-256: none
- Q01 verdict: none

Releasing the compile-worker wave is a separate fleet operation and was not
inferred from this single-EA mission.

## Capacity stop and Q02

Five whole-host CPU samples were taken five seconds apart:

| UTC | CPU |
|---|---:|
| 09:04:18.530 | 99.90% |
| 09:04:23.635 | 96.61% |
| 09:04:28.636 | 92.31% |
| 09:04:33.731 | 91.55% |
| 09:04:38.784 | 89.95% |

The maximum was 99.90%, above the 97% backtest CPU ceiling. Factory terminals
T1, T2, T3, T4, and T7 were active; the slot scan reported no duplicate workers
and no orphaned terminal processes. Q02 was therefore not enqueued. It was also
not eligible because a compiled `.ex5` and Q01 PASS do not yet exist.

The next lawful sequence is: separately authorized compile-worker rollout,
governed compile PASS, fresh below-ceiling capacity check, then exactly one
logical-basket Q02 enqueue using the committed fixed-risk set.

## Safety

No `T_Live` file or manifest was changed, AutoTrading was not toggled, no
terminal process was stopped, and neither the portfolio gate nor its manifest
was touched.

Machine-readable companion:
`artifacts/qm5_41109_compile_handoff_20260822T090438Z_board_advisor.json`.

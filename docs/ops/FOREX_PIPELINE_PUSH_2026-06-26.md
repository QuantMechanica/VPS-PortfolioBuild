# Forex Pipeline Push - 2026-06-26

Scope: continue after the 6-sleeve portfolio rescue by pushing true Forex symbols through the
farm pipeline without bypassing gates.

## Gate state

- Current `portfolio_candidates`: no true FX pair is Q12-ready yet.
- Historical best FX gates:
  - `QM5_11165:AUDCAD` reached `Q08` but is `FAIL_HARD`.
  - `QM5_10569:EURJPY` reached `Q07` but is `FAIL`.
  - `QM5_10588:USDJPY`, `QM5_10928:EURUSD`, `QM5_10558:EURUSD` reached `Q06` but are `FAIL`.
- Q02-PASS FX rows without Q03 exist, but the Q03 promoter requires positive `ea_metrics.net_profit`.
  Current scan: `0` promotable FX rows with positive net profit, so no manual Q03 promotion was made.

## Active FX work

The live factory is currently processing `QM5_12538_nnfx-canonical-stack2-st-vortex` on five true FX
symbols:

| Work item | Symbol | Phase | Slot | Status |
|---|---|---|---|---|
| `12c2fb28-6cbe-4767-8d85-2d58530ad9e7` | `GBPUSD.DWX` | `Q02` | `T1` | active |
| `86d8a1de-5ce3-4204-95a9-e1f8d38cbc32` | `AUDUSD.DWX` | `Q02` | `T4` | active |
| `d1380ad7-38c8-4250-adae-716a1f51762b` | `USDJPY.DWX` | `Q02` | `T2` | active |
| `b05ba7cf-795d-49b6-972b-96d285f1ed52` | `NZDUSD.DWX` | `Q02` | `T5` | active |
| `8da4538c-a55d-4c9b-a55c-256b64f8ab96` | `USDCAD.DWX` | `Q02` | `T7` | active |

## Slot cleanup performed

- Stopped orphaned `T7` MT5 process for `8da4538c...` while the DB still had it as `pending`.
- Stopped stale duplicate `T6` MT5 process for `b05ba7cf...`; canonical active slot is `T5`.
- Re-ran `reconcile-mt5`: no orphaned terminal processes and no duplicate terminal workers remain.
- Re-ran `dispatch-tick`: T7 claimed `USDCAD`; T6 claimed a non-FX `QM5_10308:SP500` item.

## Next rule

When these Q02 runs finish:

1. Rebuild/refresh `ea_metrics`.
2. Promote only Q02-PASS FX rows with `net_profit > 0` to Q03.
3. Let the existing pump cascade handle Q03 -> Q04 and later gates.
4. Do not promote historical FX FAIL rows without a separate strategy or setup fix.

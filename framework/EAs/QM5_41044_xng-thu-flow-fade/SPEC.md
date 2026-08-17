# QM5_41044 XNG Standard-Thursday Session-Dominant Flow Fade

**EA ID:** QM5_41044
**Slug:** `xng-thu-flow-fade`
**Strategy ID:** `EIA-WILLIAMS-YANG-XNG-THUFLOWFADE-2026_S01`
**Approved card:** `strategy-seeds/cards/approved/QM5_41044_xng-thu-flow-fade_card.md`
**G0 status:** `APPROVED`
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

On the first executable broker-Friday D1 tick, reconstruct exact completed
Tuesday, Wednesday, and Thursday sessions under either the native energy-bar
label or one uniform `+1 day` normalization. Decompose completed Thursday:

```text
overnight_flow = ln(ThursdayOpen / WednesdayClose)
session_flow   = ln(ThursdayClose / ThursdayOpen)
day_return     = ln(ThursdayClose / WednesdayClose)
```

Trade only when both flow components are nonzero and strictly oppose, the
session component has strictly larger absolute magnitude, and their sum
reconciles to `day_return` within `1e-10`. Fade the completed total: positive
total flow sells XNG and negative total flow buys XNG. Exact zero, agreement,
equal magnitudes, overnight dominance, broken dates, invalid endpoints, or
failed reconciliation consumes Friday flat.

One exact-Friday attempt is durably recorded before every fallible entry gate,
preventing same-day retry after a restart. The ordinary exit is the first D1
boundary after entry, normally Monday open; a four-day stale guard repairs
malformed carry. Framework Friday close is disabled to preserve this lifecycle.

---

## 2. Parameters

| Parameter | Default | Allowed baseline | Meaning |
|---|---:|---:|---|
| `qm_ea_id` | 41044 | fixed | Deterministic registry identity. |
| `qm_magic_slot_offset` | 0 | fixed | XNG physical slot. |
| `RISK_PERCENT` | 0 | fixed | Percentage risk is disabled. |
| `RISK_FIXED` | 1000 | fixed | Backtest risk budget per trade. |
| `PORTFOLIO_WEIGHT` | 1 | fixed | Unscaled Q02 baseline. |
| both news axes | OFF / NONE | fixed | No news gate in the approved baseline. |
| `qm_friday_close_enabled` | false | fixed | Allows the weekend-bearing lifecycle. |
| `qm_friday_close_hour_broker` | 21 | fixed | Framework input retained but disabled. |
| `strategy_entry_grace_minutes` | 180 | fixed | Maximum elapsed Friday session minutes. |
| `strategy_atr_period_d1` | 20 | fixed | Closed-D1 ATR stop lookback. |
| `strategy_atr_sl_mult` | 3.5 | fixed | Frozen catastrophic stop multiple. |
| `strategy_max_hold_days` | 4 | fixed | Stale-position repair guard. |
| `strategy_max_spread_points` | 3000 | fixed | Fail-closed broker spread ceiling. |
| `strategy_reconcile_tolerance` | 1e-10 | fixed | Log-return identity tolerance. |

There is no optimization surface, take-profit, magnitude threshold, volatility
signal gate, moving mean, oscillator, range/tail rule, storage value, retry,
scale-in, grid, martingale, or pyramid.

---

## 3. Symbol Universe

**Designed for:** exact `XNGUSD.DWX`, magic slot 0 (`410440000`).

**Explicitly not for:** non-DWX aliases, any other energy or commodity symbol,
and multi-symbol or basket operation. Runtime initialization fails unless the
host symbol is exactly `XNGUSD.DWX` on D1.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Signal data | Three exact completed D1 sessions: Tue/Wed/Thu |
| Decision clock | First executable broker-Friday D1 tick, within 180 minutes |
| Ordinary exit | First later D1 session boundary |
| Multi-timeframe reads | None |

Energy bars may use a native same-day label or a single uniform `+1 day`
normalization. Mixed labels, holidays, substitutions, and gaps outside 20-28
hours fail closed.

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Completed positions/year | Approximately 8-18; retire below 5/year |
| Typical hold | Friday entry to the next D1 boundary, normally Monday |
| Direction | Contrarian to completed Thursday total flow |
| Regime preference | Session-dominant reversal after opposing overnight/session flows |
| Tail profile | Weekend XNG gap and financing risk behind a 3.5 ATR hard stop |

Q02 also retires the edge on nonpositive governed economics. Q09 alone may
establish realized correlation with the certified portfolio book.

---

## 6. Source Citation

The durable source packet is
`strategy-seeds/sources/EIA-WILLIAMS-YANG-XNG-THUFLOWFADE-2026/source.md`.
Its reputable-source review and bounded citations are recorded in
`decisions/2026-08-17_xng_thursday_flow_fade_source_approval.md`; OWNER G0
authorization is
`decisions/2026-08-17_xng_thursday_flow_fade_g0.md`.

The canonical duplicate checker scanned 4,531 registry rows and 625 root cards
and returned `CLEAN`. Unlike `QM5_41043`, this rule requires strict component
opposition plus session dominance and takes the contrarian side. Unlike
`QM5_12567`, it has an event clock and price-flow decomposition rather than a
long-only cumulative-RSI pullback.

---

## 7. Risk Model

| Environment | Risk mode | Value |
|---|---|---|
| Governed backtest | `RISK_FIXED` | 1000 per position |
| Percentage risk | disabled | `RISK_PERCENT=0` |
| Portfolio scaling | neutral baseline | `PORTFOLIO_WEIGHT=1` |

One managed position and one durable Friday attempt are allowed. Every entry
has a frozen `3.5 * ATR(20,D1)` hard stop; there is no take-profit. This build
does not authorize live, demo, shadow, stress, optimization, manual backtest,
terminal control, AutoTrading, `T_Live`, deploy manifests, portfolio-gate
changes, portfolio admission, or a correlation waiver.

---

## Build Status

- G0: `APPROVED`
- EA-ID registry: `41044 / xng-thu-flow-fade / active`
- Magic slot 0: `XNGUSD.DWX / 410440000 / active`
- Q01: PASS (14 fixtures; strict compile and targeted build check clean;
  symbol-scope, SPEC, and static P1 validation PASS)
- Q02: not enqueued

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | approved build directory identity | source/G0/card and EA-ID registry complete |
| v1-build | 2026-08-17 | deterministic implementation | strict compile, targeted build check, independent fixtures, and static P1 PASS |

## Q01 Evidence

- independent Thursday flow-fade reference suite: 14 tests PASS
- strict compile: 0 errors, 0 warnings
- targeted V5 build check: 0 failures, 0 warnings
- factory symbol-scope validator: `SINGLE_SYMBOL_OK`
- card copies: byte-identical; schema/ML and G0 lint PASS
- SPEC schema and static P1 artifact validation: PASS
- `.mq5` SHA-256: `2E470065D1346DA534995BA1D1018B51B62B61F21C10B01418D9F5C49D42EC6B`
- `.ex5` SHA-256: `A01092CD93E8B6BCC1067E98FEDA09C844A7260238AE72A9703EA146A83D3EA2`
- compile log:
  `framework/build/compile/20260817_115317/QM5_41044_xng-thu-flow-fade.compile.log`
- build report:
  `D:/QM/reports/framework/21/build_check_20260817_115400.json`
- P1 report:
  `D:/QM/reports/pipeline/QM5_41044/P1/P1_QM5_41044_result.json`

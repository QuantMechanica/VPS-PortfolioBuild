# QM5_20144_ichimoku-atr-cloud-d1 - Strategy Spec

**EA ID:** QM5_20144
**Slug:** `ichimoku-atr-cloud-d1`
**Source:** BP-UNHOMMEFOU-ICHIMOKU-18242 (see card QM5_20144)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-25

---


EA: QM5_20144 `ichimoku-atr-cloud-d1` · TF D1 · Cohort: EURUSD.DWX,
GBPUSD.DWX, USDJPY.DWX, USDCHF.DWX (the author's "4 Majors", I-01;
USDJPY = his best performer). AUD pairs excluded (author-reported).

## Entry (once per new D1 bar, closed bars only)

- Ichimoku(9, 26, 65), displacement 26. Senkou values via iIchimoku
  buffers at shift 1 WITH a one-time OnInit self-test against the
  manual causal calculation (spanA = midpoint(tenkan,kijun) computed
  27 bars back; spanB = 65-bar midpoint ending 27 bars back); mismatch
  → INIT_FAIL. cloudTop = max(spanA, spanB); cloudBottom = min.
- ATR(20) Wilder, closed bar.
- LONG state: Tenkan[1] > Kijun[1] AND Close[1] > cloudTop[1] +
  1×ATR[1]. SHORT mirror below cloudBottom − ATR. Equality = no entry.
- Enter at the next bar when flat and the state holds; STATE-based
  (no fresh-cross requirement, I-05).
- Re-arm lock: after a protective-stop close, that direction is locked
  until its entry state first becomes false and later true again
  (house projection, I-07).
- NO pyramiding (the author's 3-lot ATR scale-in = stacking, banned).

## Exits

1. Kill-switch flatten.
2. Initial protective stop: FROZEN signal-bar near cloud edge
   (cloudTop for longs, cloudBottom for shorts) — labeled HOUSE
   projection (source has no stop); gap-invalid geometry → skip trade;
   never trailed.
3. Opposite Tenkan/Kijun cross (Tenkan[2] ≥ Kijun[2] → Tenkan[1] <
   Kijun[1] for longs; mirror) → market close at the next bar,
   per-bar retry latch.
4. Friday close (framework). NO take profit, NO Chikou, NO time exit.

## Inputs

```
strategy_tenkan = 9
strategy_kijun = 26
strategy_senkou_b = 65        // 52, 100 = the only labeled variants
strategy_atr_period = 20
strategy_atr_cloud_mult = 1.0
```

## Flags

- 9/26/65 = the author's unverified walk-forward claim (I-02;
  selection-bias risk; neighborhood check at Q08 will judge).
- Frozen-cloud-edge stop + re-arm lock = house projections (I-07).
- Prior QM5_10513 materially different (03_reconciliation.md: cross
  event, Span-B-only, NO ATR filter, 9/26/52, 1.5R TP).

## Hooks

Filter: D1/params/warmup ≥ 130 bars + handles + buffer self-test.
Entry: state + ATR-distance check. Manage: cross-exit with retry
latch + re-arm bookkeeping. Exit: false (exit handled in Manage for
single-path determinism). News: default fail-closed. NO QM_IsNewBar();
own static D1 guard; ZeroMemory(req) + symbol_slot.

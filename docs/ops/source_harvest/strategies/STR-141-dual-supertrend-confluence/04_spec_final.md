# STR-141 — FINAL reconciled spec (build authority)

EA: QM5_20151 `dual-supertrend-confluence-h1` · TF H1 · Cohort:
EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, AUDUSD.DWX,
USDCHF.DWX, NZDUSD.DWX (declared research cohort, STR141-C1;
QM5_20127 7-major precedent).

## Supertrend (in-EA deterministic; codex 02 §3 verbatim authority)

- TR/Wilder ATR(7): mean-of-7 seed, then ATR = (6·ATR_prev + TR)/7.
- For m ∈ {0.9, 1.8}: basic bands mid ± m·ATR on (H+L)/2; final-band
  carry rules; direction recursion per codex 02 §3 rules 3-5; seed
  UP/DOWN vs mid at the first ATR-ready bar. Warmup ≥ 220 bars
  (max period + 2 plus EMA99 buffer).

## Entry (closed bar; both directions gated by ADX9[1] > 25)

- LONG: fast ST flips DOWN→UP on bar 1 AND slow ST UP on bars 2 AND 1
  AND EMA99[1] > EMA99[2] AND RSI9[1] > 50.
- SHORT (source asymmetry preserved): slow ST flips UP→DOWN AND fast
  ST DOWN on bars 2 AND 1 AND EMA99[1] < EMA99[2] AND RSI9[1] < 50.
- Equality anywhere = no signal. Market entry next bar; rejected
  signal consumed. One position per magic.

## Risk / exits

- Initial SL: long = fast (0.9) ST line of the signal bar; short =
  slow (1.8) line (source asymmetry). Reject invalid-side geometry;
  never synthesize.
- Per closed bar: ratchet the server stop to the current prescribed
  ST line, tighten-only, broker-valid (STR141-D1).
- Strategy exit: close long next bar when EITHER ST is DOWN on bar 1
  OR EMA99 slope turns down; short mirror. Per-bar retry latch.
- No TP, no time exit, no partials, no same-bar reverse.

## Inputs

```
strategy_st_atr_period = 7
strategy_st_fast_mult = 0.9
strategy_st_slow_mult = 1.8
strategy_ema_period = 99      // prose wins; 9 = labeled variant
strategy_rsi_period = 9
strategy_adx_period = 9
strategy_adx_min = 25.0
```

## Hooks

Filter: H1/params/warmup ≥ 220. Entry: flip+confluence (own ST state
arrays updated per closed bar; QM_EMA/QM_RSI/QM_ADX pooled readers;
CopyRates via QM-sanctioned path with inline perf-allowed only if
unavoidable). Manage: ST-line stop ratchet + exit-signal close, retry
latches. Exit: false. News: default fail-closed. NO QM_IsNewBar();
own static guards; ZeroMemory(req) + symbol_slot.

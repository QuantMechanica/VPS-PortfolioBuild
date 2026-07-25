# QM5_20142_mtf-ema25-align-h4 - Strategy Spec

**EA ID:** QM5_20142
**Slug:** `mtf-ema25-align-h4`
**Source:** FF-FOFF00-4X25MA-932507 (see card QM5_20142)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-25

---


EA: QM5_20142 `mtf-ema25-align-h4` · TF H4 · Cohort: EURUSD.DWX,
GBPUSD.DWX, USDJPY.DWX (test-design; author names no pair).

## Entry (once per new H4 bar, closed bars only)

- For each TF in {M15, H1, H4, D1}: newest bar closed at the H4
  decision time; missing/stale series → no decision this bar.
- LONG: Close(tf, i) > EMA25(tf, i) for every TF and every
  i in [1, strategy_confirm_bars]. SHORT: all strictly below.
  Equality anywhere = no setup.
- Session gate (entries only): from 08:00 UK-local to 17:00 NY-local,
  both computed DST-aware in-EA (UK helper per QM5_20119 pattern, US
  helper per QM_DSTAware). Management runs 24h.
- Market entry when flat; one position; re-entry allowed on later H4
  decisions while alignment persists (no episode lock — sourced
  absence).

## Risk / exits

- ATR(14, H4) from the closed bar; reject if invalid/non-positive.
- SL = fill ∓ 2×ATR; TP = fill ± strategy_tp_atr×ATR (3.0 baseline;
  4.0 = labeled variant). Normalize to tick; never leave an
  unprotected position.
- No trailing, no opposite-alignment exit, no time exit, no spread
  veto (QM5_10038's additions stay excluded).

## Inputs

```
strategy_ema_period = 25
strategy_atr_period = 14
strategy_confirm_bars = 1      // sweep {2,3}
strategy_sl_atr = 2.0
strategy_tp_atr = 3.0          // 4.0 = variant
```

## Flags

- ATR TF = H4 (I-04); applied price close (I-01); N=1 minimal reading
  (I-02); session anchors 08:00 UK / 17:00 NY local (I-05 concretized).

## Hooks

Filter: params/warmup (≥ 50 D1 bars) + 4 EMA handles + ATR. Entry:
MTF alignment + session gate (uses QM_EMA pooled readers per TF).
Manage: none beyond framework. Exit: false. News: default fail-closed.
NO QM_IsNewBar() in hooks; own static H4 bar guard; ZeroMemory(req) +
symbol_slot.

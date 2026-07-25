# QM5_20138_stoch-ema50-pullback-h4 - Strategy Spec

**EA ID:** QM5_20138
**Slug:** `stoch-ema50-pullback-h4`
**Source:** FF-GAZFX-TRENDCONT-837301 (see card QM5_20138)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-25

---


EA: QM5_20138 `stoch-ema50-pullback-h4` · TF H4 · Cohort: EURUSD.DWX,
GBPUSD.DWX, XAUUSD.DWX, XAGUSD.DWX (per-symbol; metals sourced via the
scanner coverage, 00_source.md:34).

## Entry (closed-bar, once per new H4 bar)

- LONG: K[2] ≤ D[2] AND K[1] > D[1] AND K[1] ≤ 20 AND D[1] ≤ 20 AND
  EMA50[1] > EMA50[2]. SHORT mirror (cross down, both ≥ 80, EMA down).
- EMA flat (equal at tick precision) or disagreement → no trade.
- Market entry at next tradable tick; skip if position/intent exists.
- Stoch: iStochastic(5,3,3, MODE_SMA, STO_CLOSECLOSE). EMA:
  iMA(50, MODE_EMA, PRICE_CLOSE).

## Risk / exits

- SL: long Low[1] − 10 pips; short High[1] + 10 pips. Reject invalid
  geometry / broker min-stop violations.
- R = |entry − SL|. TP = entry ± 3R.
- Trail: fixed distance R, ratchet-only (long: Bid − R when it
  tightens; short: Ask + R), never widen, respect freeze levels.
- No time exit, no opposite-cross exit, no spread veto (fidelity
  exclusions — QM5_10017 additions stay out).

## Inputs

```
strategy_stoch_k = 5
strategy_stoch_d = 3
strategy_stoch_slowing = 3
strategy_zone_low = 20.0
strategy_zone_high = 80.0
strategy_ema_period = 50
strategy_sl_buffer_pips = 10.0
strategy_tp_r = 3.0
```

## Flags

- Both-lines zone condition + slope lookback 1 = interpretations
  (03_reconciliation.md #1; codex I-01/I-02).
- H4 canonical; H1 = variant. Frequency unknown until Q02.

## Hooks

Filter: TF/param/warmup ≥ 60 + handle validation. Entry: rules above.
Manage: R-trail ratchet with per-bar retry pacing on rejected modifies.
Exit: false. News: default fail-closed. NO QM_IsNewBar() in hooks; own
static bar guard; ZeroMemory(req) + symbol_slot.

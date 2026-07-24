# STR-097 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_ha-stoch-h4-swing` · TF: H4 · Symbols: GBPUSD.DWX, EURAUD.DWX,
USDCHF.DWX, EURCAD.DWX (slots 0–3) · Base: `framework/templates/EA_Skeleton.mq5`
(only the 5 hooks + inputs are strategy code; risk/news/Friday-close/KillSwitch =
framework).

## Inputs (group "=== Strategy (STR-097, source-fixed) ===")

```
input int    strategy_sma_period        = 100;  // H4 SMA of close (trend gate)
input int    strategy_stoch_k           = 8;
input int    strategy_stoch_d           = 3;
input int    strategy_stoch_slowing     = 3;
input double strategy_stoch_zone        = 50.0; // %D must be below (long)/above (short) at cross
input int    strategy_pullback_min_bars = 2;    // consecutive opposite-colour HA bars before flip
input double strategy_sl_pips           = 50.0; // initial protective stop
```

## State (file-scope statics; all recomputed from closed bars — restart-safe)

- Indicator handles: `g_h_sma` (iMA H4 SMA100 PRICE_CLOSE), `g_h_stoch`
  (iStochastic 8,3,3, MODE_SMA, STO_LOWHIGH).
- HA series computed on demand from closed H4 OHLC (helper `HaColor(shift)` →
  +1 green / −1 red, and `HaLow(shift)`, `HaHigh(shift)`): classic recursion
  seeded ≥ 150 bars back; only shifts ≥1 used.
- `g_last_signal_bar` (datetime): dedupe — one evaluation per closed bar.
- No persistent files needed; trailing derives from position + HA[2] each bar.

## Hook 1 — `Strategy_NoTradeFilter()`

Return `false` (block) when: indicator handles invalid; fewer than
`strategy_sma_period+5` closed H4 bars (warmup); or symbol trade disabled.
Otherwise `true`. (News/Friday/kill-switch blocking is framework-side — do NOT
re-implement.)

## Hook 2 — `Strategy_EntrySignal(direction&)`

Evaluate ONLY on a new H4 bar (compare `iTime(_Symbol,PERIOD_H4,0)` vs
`g_last_signal_bar`; set it after evaluation). All reads at shifts 1..N.
LONG iff ALL:
1. `Close[1] > SMA100[1]`
2. `HaColor(1)==GREEN && HaColor(2)==RED && HaColor(3)==RED`
   (flip after ≥2-red pullback; for `strategy_pullback_min_bars=n`, bars 2..n+1 red)
3. Stoch cross on bar 1: `K[2] <= D[2] && K[1] > D[1]`
4. Zone: `D[1] < strategy_stoch_zone`
SHORT = exact mirror (Close<SMA, red flip after ≥2 green, K crosses under D,
`D[1] > 100 - strategy_stoch_zone`).
If a position for this magic exists: return NO signal (no pyramiding; opposite
signals do not force exits — exits are Hook-3 domain).
On signal: set direction, return true. Framework places the market order at
current price with SL = entry ∓ `strategy_sl_pips` (pip via framework pip-size
helper), TP = 0 (none).

## Hook 3 — `Strategy_ManageOpenPosition()`

Per NEW closed H4 bar (same new-bar guard), for the open position:
1. **HA-flip exit:** if `HaColor(1)` is against the position (red for long,
   green for short) → close position at market. Log event
   `STRATEGY_EXIT reason=ha_flip`.
2. **Trail:** else compute candidate SL: long `HaLow(2) `, short `HaHigh(2)`
   (no buffer). If candidate is strictly better (long: higher than current SL;
   short: lower) AND respects stops-level (framework clamp helper) → modify SL.
   Never widen; never touch TP.
No intra-bar action. BE/partial logic: none (variant 1).

## Hook 4 — `Strategy_ExitSignal()`

Return false (all exits handled in Hook 3 / server-side SL). Keep default.

## Hook 5 — `Strategy_NewsFilterHook()`

Framework default (no strategy-specific news logic; source states none).

## Error handling / logging

- Handle-creation failure → `INIT_FAILED` via framework init contract.
- `CopyBuffer`/`CopyRates` failures on a bar → skip evaluation that bar, log
  `SETUP_DATA_MISSING` once per bar, retry next bar (fail-quiet, no stale reads).
- Log `STRATEGY_ENTRY` with payload {dir, close, sma, k, d, ha_pattern} and
  `STRATEGY_EXIT`/`TM_*` per framework conventions; every trade action must be
  evidence-logged (QM_LogEvent) — no silent modifies.

## Compliance mapping (Q01 checklist)

Magic `ea_id*10000+slot` per registered symbol; RISK_FIXED backtest sets /
RISK_PERCENT live; per-trade cap ≤1%; news filter active (framework); KS_DAILY_LOSS
3% (framework); KS_PORTFOLIO_DD external monitor (live DD guard running);
Friday-close default-on. Expected frequency ≥12/yr/symbol (≥ floor 5).

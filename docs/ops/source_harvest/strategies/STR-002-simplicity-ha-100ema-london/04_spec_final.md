# STR-002 — Final implementation spec (5 framework hooks)

EA: `QM5_<id>_simplicity-ha-ema100-london` · TF H1 · Symbols (slots 0–3):
EURUSD.DWX, GBPUSD.DWX, USDCHF.DWX, USDJPY.DWX · Base:
`framework/templates/EA_Skeleton.mq5` (only the 5 hooks + inputs are strategy
code). Faithful-variant rationale: QM5_9977 (same thread) deviated from source
(no session window, no A/B/C tranches, invented flip-exit + ATR floor); this
build is the source-faithful mechanization. Netting account → one position,
2/3 partial close at +1R, 1/3 HA-trailed runner. **Campaign risk = 1% total**
(reconciliation #3, more-restrictive; source 3×1% = documented variant only).

## Inputs (group "Strategy" — literal name, build_check requirement)

```
input int    strategy_ema_period        = 100;
input int    strategy_session_start_gmt = 6;   // signal-bar OPEN >= 06:00 UTC
input int    strategy_session_hours     = 9;   // source "8-9h" -> 9; window [start, start+9)
```

## State (file-scope statics, recomputed from closed bars — restart-safe)

- `g_h_ema` (iMA H1 EMA100 PRICE_CLOSE). HA arrays via the STR-097-pattern
  on-demand recursion helper (CopyRates start=1, series-aligned, seed
  (O+C)/2 at depth ≥150, `// perf-allowed` on the bounded new-bar-gated copy).
- `g_last_signal_bar` datetime new-bar dedupe (own static guard — NOT
  QM_IsNewBar, the skeleton consumes that edge at the entry gate).
- Campaign state derived, not stored: own position exists → campaign open;
  `PositionGetDouble(POSITION_VOLUME) < 0.995 * initial` (initial = volume at
  first Manage sighting after open, cached per ticket; on restart with reduced
  volume assume 1R-done) → trailing phase.
- UTC mapping: framework's existing broker↔UTC primitive (news-filter
  convention); no local DST arithmetic.

## Hook 1 — Strategy_NoTradeFilter (TRUE = block)

Block on: `_Period != PERIOD_H1`; param sanity (ema>1, 0≤start<24,
1≤hours≤24); symbol trade disabled; warmup < ema_period+5 closed H1 bars or
<150 HA bars; EMA handle invalid / BarsCalculated < ema_period+5.
NO session check here (management must run around the clock). NO position
check here.

## Hook 2 — Strategy_EntrySignal

New-bar gate (own static). ZeroMemory(req); req.symbol_slot =
qm_magic_slot_offset. Return false if own position exists (one campaign).
Session: signal bar (shift 1) OPEN time in UTC ∈ [start, start+hours) — via
framework broker↔UTC primitive; outside → false.
LONG iff: HA(2) red AND HA(1) green AND Close[1] > EMA100[1] (strict).
SHORT mirror (strict <; doji/equal = no signal).
SL: long = HA_Low(1) − 1 trade tick; short = HA_High(1) + 1 tick. Invalid
geometry (zero distance / stops-level violation after normalize) → skip + log
`SETUP_CONFIG_INVALID reason=initial_sl`. TP = 0 (tranches are Hook-3 domain).
Log STRATEGY_ENTRY {dir, close, ema, ha_low/high, sl}.

## Hook 3 — Strategy_ManageOpenPosition

Per tick, own position only:
- Cache initial volume per ticket (first sighting).
- **Phase 1 (full volume):** if bid ≥ entry+R (long; R = |entry − initial SL|;
  ask ≤ entry−R short): partial-close 2/3 of INITIAL volume at market
  (`QM_TM_...partial` helper; one shot — volume test prevents repeats), log
  `STRATEGY_EXIT reason=tranche_ab_1r`. If the partial close is rejected,
  retry at most once per closed H1 bar (20098-pattern latch).
- **Phase 2 (runner):** on each NEW closed H1 bar (own static bar guard),
  candidate SL = HA_Low(1) − 1 tick (long; mirror short); modify only if
  strictly tighter AND stops-level-legal. Never widen. No TP ever.
- Fast-move race guard: if in phase 1 the +1R level and the initial SL are
  both plausible in one bar, no special handling — server chronology decides
  (codex spec §runner).

## Hook 4 — Strategy_ExitSignal
false (all exits: server SL, 1R partial, trailed runner stop).

## Hook 5 — Strategy_NewsFilterHook
Framework default.

## Logging / errors

CopyRates/handle failure → skip bar, `SETUP_DATA_MISSING` once per bar
(STR-097 dedupe pattern). All trade actions via QM_TM_* (evidence-logged).

## Compliance mapping

Magic ea_id*10000+slot; RISK_FIXED backtest / RISK_PERCENT live; campaign
risk 1% (whole position); news/Friday/KS framework-owned; no martingale/grid;
expected frequency ~60–150 signals/yr/symbol (floor safe).

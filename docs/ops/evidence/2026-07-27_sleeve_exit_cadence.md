# RECON B — exit cadence of the three target sleeves

Date: 2026-07-27
Question: for a timer-driven multi-symbol joint EA, does each of the three
Q09-admitted sleeves manage its EXITS on TICK or on BAR CLOSE / server-side?
This is the load-bearing question. The previous joint EA (QM5_20180) reproduced
entries and drifted on exits — 77 of 107 apparent mismatches were SAME entry,
SAME volume, SHIFTED exit
(`docs/ops/evidence/2026-07-27_joint_ea_fidelity_diagnosis.md`). A timer that
polls once per bar lands on exactly that fault if the originals manage exits per
tick.

Sources read (full):
- `framework/EAs/QM5_9936_ff-range-breakout-gmt3-h1/QM5_9936_ff-range-breakout-gmt3-h1.mq5` + `SPEC.md`
- `framework/EAs/QM5_10145_tsm-meanret/QM5_10145_tsm-meanret.mq5` + `SPEC.md`
- `framework/EAs/QM5_13301_balke-minute-range-breakout/QM5_13301_balke-minute-range-breakout.mq5` (no SPEC.md in dir; header block lines 76-91 documents provenance)
- Framework stop primitives: `framework/include/QM/QM_Entry.mqh`, `framework/include/QM/QM_TradeManagement.mqh`

---

## Bottom line (read this first)

| Sleeve | Role | Stops = real server orders? | Exit management cadence | **Verdict** |
|---|---|---|---|---|
| **9936 USDJPY** | **runner** | YES (initial SL + trailed SL both server-side) | **+1R 2-bar-swing trailing stop triggered PER TICK**; opposite-touch PER TICK; session-close time exit hour-aligned | **TIMER-RISKY** |
| **13301 GDAXI** | satellite | YES (initial SL + trailed SL both server-side) | **same per-tick trailing stop as 9936**; code comments EXPLICITLY require sub-bar precision | **TIMER-RISKY** |
| **10145 XAUUSD** | satellite | YES (ATR emergency SL server-side) | no trailing/BE/partial; exit-signal reads CLOSED D1 bars only | **TIMER-SAFE** |

**No sleeve is NOT-TIMER-SAFE** (none does truly continuous management — every SL
level is a discrete, structure-defined value). But **the runner is the hazard**,
not a satellite: the sleeve that supplies the book's entire return (9936:USDJPY)
carries a per-tick trailing stop. A once-per-bar timer will NOT reproduce it, and
no timer of any interval guarantees byte-exact match_rate == 1.0 against the
per-tick original. See §1 and §5.

**Corroboration of the load-bearing risk.** The QM5_20180 evidence — entries
matched exactly, 77 exits shifted by clean H1 multiples (25 at +3600 s, 4 at
+7200 s) — is EXACTLY the fingerprint this source analysis predicts: entries are
server-side pending stops fired at bar close (cadence-independent, so they
reproduced), while exits ride a per-tick trailing stop (cadence-sensitive, so
they drifted). The fidelity diagnosis attributed the 20180 shift to framework-
vintage drift and left cadence NOT ESTABLISHED; independent of that, the source
shows the exit path IS per-tick, so a timer design inherits the same failure
surface.

---

## Framework fact that decides most of the answer

All three sleeves place their **initial** stop as a **real server-side SL on the
position**, not a code-managed level:

- `framework/include/QM/QM_Entry.mqh:338` — `trade_req.sl = (req.sl > 0.0) ? NormalizeDouble(req.sl, _Digits) : 0.0;` — `req.sl` from the strategy is written straight into the broker order.

Any SL move is likewise a **server-side modify**, not a synthetic close:

- `framework/include/QM/QM_TradeManagement.mqh:368-374` — `QM_TM_MoveSL` → `QM_TM_SendSLTPModify`.
- `framework/include/QM/QM_TradeManagement.mqh:136` — `request.action = TRADE_ACTION_SLTP;` (line 139 sets `request.sl`).

So a stop-loss FILL is always cadence-independent. What is NOT cadence-independent
is the **decision, taken in EA code, of WHEN and TO WHAT LEVEL to move that SL**,
and any **code-driven market close** (opposite-touch / time exit). Those decisions
run inside `Strategy_ManageOpenPosition()` and `Strategy_ExitSignal()`, both of
which are called on **every tick** by the framework `OnTick` (see per-sleeve
line refs below). That is where cadence risk lives.

---

## 1. QM5_9936 — USDJPY — RUNNER — **TIMER-RISKY**

ForexFactory 01:00-06:00 GMT+3 H1 range breakout. Base TF **H1** (SPEC §4).

### Entry cadence — BAR CLOSE (safe)
- `QM5_9936...mq5:539` — `if(!QM_IsNewBar()) return;` gates `Strategy_EntrySignal`. Entry logic runs once per closed **H1** bar.
- At range-end hour (06:00 GMT+3) it places a BUY_STOP at range high and a SELL_STOP at range low (`:309-316`), each with the opposite range side as `req.sl` (`Strategy_PopulateEntry`, `:234-247`). These are **pending stop orders** → fills are server-side and cadence-independent.
- Verdict: entries reproduce exactly under a timer that polls once per H1 bar.

### Exit mechanisms
1. **Initial SL** — opposite range side, server-side (`:310`/`:314` via `req.sl`). Cadence-independent. **Safe.**
2. **+1R 2-bar-swing trailing stop** — `Strategy_ManageOpenPosition()`, called every tick at `:519`. Trigger reads **live market price**:
   - `:357` — `market = ... SymbolInfoDouble(_Symbol, SYMBOL_BID/ASK)`
   - `:361-363` — `moved = market - open_price; if(moved < strategy_trail_trigger_r * risk_dist) continue;`
   - On trigger, SL is moved to `MathMin(low1,low2)` / `MathMax(high1,high2)` of the prior two **completed H1** bars (`:365-372`) via `QM_TM_MoveSL` (`:381`).
   - The trail TARGET only changes at H1 bar close (structural), but the **+1R trigger is evaluated per tick**. A per-tick engine can tighten the SL mid-hour and stop out earlier than a coarse-timer engine that only checks at the bar boundary. The trail only ever tightens (`improves` guard `:378`), so per-tick vs bar-close can produce genuinely different (earlier) exits. **PER-TICK.**
3. **Opposite-range-touch exit** — `Strategy_ExitSignal()`, called every tick at `:522`:
   - `:410-413` — BUY closes when `SymbolInfoDouble(_Symbol,SYMBOL_BID) <= g_strategy_range_low`; SELL mirrors. **PER-TICK.** (Largely redundant with the initial server SL, which sits at the same range boundary for an un-trailed position; marginal once trailing has tightened the SL inside the range.)
4. **Session-close time exit** — `:392` — `if(Strategy_Gmt3Hour(now) >= strategy_session_close_hour_gmt3) return true;` (20:00 GMT+3). Hour boundary = **H1-aligned** → a once-per-H1-bar timer catches it. **Bar-close-equivalent.**

### Verdict: TIMER-RISKY
The initial SL, entries, and 20:00 time exit are all bar-close-or-server-side and
reproduce under an H1-cadence timer. **The +1R trailing stop is per-tick and does
not.** Interval needed to *approximate*: seconds-scale (the trail target is fixed
within the hour, so the only sub-bar-sensitive element is the +1R crossing time;
polling every few seconds bounds the error to a few seconds of price travel).
**A once-per-H1-bar timer is insufficient. No timer interval guarantees
match_rate == 1.0** against the per-tick original, because tester `OnTimer` fires
on modeled-time intervals that never align with tick timestamps.

Because 9936 is the **runner** — it supplies the book's entire drift/return while
the satellites only damp drawdown — its trailing stop is the make-or-break element
for the whole timer-driven design. This is the finding OWNER needs before
implementation, not after.

---

## 2. QM5_13301 — GDAXI — satellite — **TIMER-RISKY**

Balke minute-precision range breakout. Explicit minute-precision variant of
QM5_13213; range/entry/cancel logic re-based to **M5** bars (header `:76-91`),
ATR sizing and the 2-bar swing trail stay on H1.

### Entry cadence — BAR CLOSE (safe), M5 resolution
- `:536` — `if(!QM_IsNewBar()) return;` gates `Strategy_EntrySignal`; EA runs on an **M5** chart (`:294-295`). Fires when `minute_of_day == Strategy_RangeEndMinutes()` (`:307`), placing BUY_STOP/SELL_STOP pending orders (`:334-340`). Server-side fills. Reproduces under a timer polling once per **M5** bar.

### Exit mechanisms — structurally identical to 9936
1. **Initial SL** — opposite range side, server-side (`:335`/`:339`). **Safe.**
2. **+1R 2-bar-swing (H1) trailing stop** — `Strategy_ManageOpenPosition()`, every tick at `:516`. Same per-tick trigger on live BID/ASK (`:386`, `:390-391`), same H1-structure target (`:394-401`), same `QM_TM_MoveSL` (`:410`). The code comment is explicit: `:350-353` — *"Runs every tick (not bar-gated) so the exit/cancel minute fires at real-time precision regardless of chart period."* **PER-TICK.**
3. **Opposite-touch exit** — `Strategy_ExitSignal()` every tick at `:519`; `:440-443` live BID/ASK vs range boundary. **PER-TICK.**
4. **Time exit** — `:422` — `if(Strategy_Gmt3MinuteOfDay(now) >= Strategy_ExitMinutes()) return true;` default 18:00. Comment `:420`: *"Runs every tick — real-time minute precision."* Default 18:00 is M5-aligned, so an M5 timer catches it; but the design intent is explicitly minute-precise, so any non-M5-aligned `strategy_exit_minute` would need finer polling.

### Verdict: TIMER-RISKY
Same shape as 9936: entries + initial SL + time exit reproduce under an M5-cadence
timer; **the +1R trailing stop is per-tick**. Interval to approximate: seconds-scale.
Once-per-M5-bar is insufficient for the trail; byte-exact 1.0 not guaranteed by any
timer. As a satellite its job is drawdown damping, not return, so the practical
materiality of the trail should be measured from its gated Q08 stream before it is
committed (see §5).

---

## 3. QM5_10145 — XAUUSD — satellite — **TIMER-SAFE**

Rolling-mean-return time-series momentum. Base TF **D1** (SPEC §4); the EA hard-
refuses any other period: `:90-92` — `if(_Period != PERIOD_D1) return true;`.

### Entry cadence — BAR CLOSE (safe)
- `:294` — `if(!QM_IsNewBar()) return;` gates `Strategy_EntrySignal`. Signal reads **closed D1 bars only**: `:125-126` — `iClose(_Symbol,PERIOD_D1,1)` and `iClose(_Symbol,PERIOD_D1,1+strategy_lookback_n)`. Market entry at bar close. Reproduces exactly under a once-per-D1-bar timer.

### Exit mechanisms
1. **Initial SL — ATR emergency stop, server-side.** `:147` — `QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_stop_mult)` written to `req.sl` (`:157`) → server order. Cadence-independent. **Safe.**
2. **No trailing / BE / partial.** `Strategy_ManageOpenPosition()` is empty by design: `:167-170` — *"Card specifies no trailing, break-even, partial-close, or adaptive management."* **No per-tick management at all.**
3. **Signal exit — closed-bar data.** `Strategy_ExitSignal()` at `:277` is called every tick, BUT its inputs are closed D1 bars only: `:180-181` — `iClose(_Symbol,PERIOD_D1,1)` and `iClose(_Symbol,PERIOD_D1,1+N)`. `mean_log_return` is therefore **constant within a D1 bar**; a BUY closes when it turns `<= 0` (`:199`). Evaluated per tick or once per D1 bar, the result is identical — the exit fires on the first poll of the new D1 bar. **Bar-close-equivalent.**

### Verdict: TIMER-SAFE
Stops are real server orders; there is no per-tick management; the exit decision is
a pure function of closed D1 bars. A timer polling once per D1 bar reproduces this
sleeve exactly. This is the sleeve to use to validate the timer harness itself
before the runner is attempted.

---

## 4. Does each sleeve place stops as real orders? (the fact that decides it)

| Sleeve | Initial SL | Trailing SL | Code-driven market closes |
|---|---|---|---|
| 9936 | server order (`req.sl` → `QM_Entry.mqh:338`) | server modify (`QM_TM_MoveSL` → `TRADE_ACTION_SLTP`), but **triggered per tick** | opposite-touch + 20:00 time exit, both per-tick eval |
| 13301 | server order | server modify, **triggered per tick** | opposite-touch + 18:00 time exit, per-tick eval (comments demand it) |
| 10145 | server order (ATR stop) | none | signal exit on closed-D1 data only |

All initial stops are real broker orders. 10145 has no code-managed exit path at
all beyond a closed-bar signal. 9936 and 13301 keep the SL on the server but decide
WHEN to tighten it in per-tick code — that is the whole cadence exposure.

---

## 5. Consequences for the piece-by-piece build (OWNER: "Stück für Stück", admit each at match_rate == 1.0)

1. **10145 XAUUSD is the safe first sleeve.** It is provably timer-safe (server SL,
   no management, closed-bar exit). Bring it up first to prove the OnTimer harness
   reaches match_rate == 1.0 against its standalone gated run, on a valid same-
   vintage / same-tick-image control (the control the 20180 diagnosis said was
   missing). If a TIMER-SAFE sleeve cannot hit 1.0, the harness is broken and no
   amount of cadence tuning on the others will help.

2. **9936 USDJPY is the crux and cannot be skipped.** It is the runner; the book
   has no return without it. Its +1R trailing stop is per-tick, so a naive
   once-per-bar timer will drift its exits exactly as 20180 did. Two viable paths,
   to decide BEFORE coding the runner in:
   - **(a) Fast per-symbol poll.** Drive management on a seconds-scale timer
     (`EventSetMillisecondTimer`) and evaluate 9936's trail on each fire using
     USDJPY's own current quote. This APPROACHES but does not guarantee 1.0;
     accept an explicit, measured tolerance rather than pretending to byte-fidelity.
   - **(b) Measure first whether the trail is even material.** From the gated Q08
     trade stream for 9936:USDJPY, count how many exits are trail-stop hits vs
     20:00 time exits / opposite-touch. If the +1R trail rarely binds before the
     session flat, the per-tick exposure is small and a coarse timer may reach 1.0
     empirically. This is a measurement, not an assumption — run it before
     committing the runner.

3. **13301 GDAXI carries the same per-tick trail** and the same treatment applies;
   as a damping satellite its trail materiality should also be measured from its
   gated stream. If (b) shows the trail binds often for GDAXI and 1.0 is
   unreachable at a practical interval, the composition can change — a different
   damping satellite could be substituted, since satellites exist to cut drawdown
   depth, not to add return.

4. **Nothing here is NOT-TIMER-SAFE in the absolute sense** (no sleeve does
   continuous management that no timer can touch), so the composition does not have
   to change on structural grounds alone. But the runner's per-tick trail is a real
   risk to the match_rate == 1.0 admission bar and must be handled by design +
   measurement, not waved through.

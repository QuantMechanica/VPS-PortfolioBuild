# Multi-symbol OnTimer joint EA — implementation plan (ARCHITECT)

Date: 2026-07-27 · Branch `agents/board-advisor` · `C:\QM\repo` · Author: Claude (architect).
Deliverable: the implementation plan for a single backtest-only joint EA that runs the
Q09-admitted runner+satellite book on ONE simulated account in ONE tester run, per OWNER
(2026-07-27): symbols as input parameters, sleeves dispatched by symbol, driven from
`OnTimer` instead of per-tick `OnTick`. **This document is the plan; it writes no
production code.** It is to be built piece by piece with Codex + Sonnet.

Factual basis (read in full, treated as fact):
`2026-07-27_ontimer_tester_semantics.md` (RECON A),
`2026-07-27_sleeve_exit_cadence.md` (RECON B),
`2026-07-27_multisymbol_machinery_recon.md` (RECON 1),
`2026-07-27_joint_ea_fidelity_diagnosis.md` (20180 diagnosis),
`2026-07-27_runner_satellite_composition.md` (the book),
`a5768d03_equity_export_gap_2026-07-27.md` (equity gap),
plus the shipped `QM5_20180` EA + its two `QM_Mod_*_20180.mqh` modules as the attempt to
learn from.

---

## 0. The decision, up front (decisive — one plan)

The load-bearing fact from RECON B (`2026-07-27_sleeve_exit_cadence.md:23-27`): only ONE of
the three target sleeves is TIMER-SAFE. The runner (9936:USDJPY) and one satellite
(13301:GDAXI) both carry a **+1R 2-bar-swing trailing stop evaluated per tick on live
BID/ASK**; the other satellite (10145:XAUUSD) does zero per-tick management and exits on
closed-D1 data only.

The MT5 tester delivers `OnTick` **only on the chart (host) symbol's ticks** and `OnTimer`
on **model-time intervals that never align with tick timestamps** (RECON A
`:19-26,149-159`; RECON B `:96-97`). Therefore:

- A **host-symbol** sleeve driven by `OnTick` reproduces its per-tick management
  **byte-for-byte** — it sees the identical tick stream the standalone EA saw. This is the
  construction the 20180 two-USDJPY design used, which RECON diagnosis found *valid by
  construction* — its 0.914 miss was **cross-vintage control drift, not a cadence bug**
  (`2026-07-27_joint_ea_fidelity_diagnosis.md:68-97`).
- A **non-host** sleeve can only be driven by `OnTimer`, which **cannot** reproduce a
  per-tick trailing stop at `match_rate == 1.0` for any interval (RECON B `:89-97,121-123`).
  A non-host `OnTimer` sleeve is faithful **only if it is TIMER-SAFE** (server-side stops,
  no per-tick management, closed-bar-deterministic exits).

Only one host symbol exists. The runner supplies the **entire** return; the satellites only
damp drawdown (`2026-07-27_runner_satellite_composition.md:13,59`). So the runner MUST take
the host and run on `OnTick`; every satellite MUST be non-host and therefore MUST be
TIMER-SAFE. This forces the composition:

| Slot | Sleeve | Symbol | Role | Driver | Cadence status | How fidelity is reached |
|---|---|---|---|---|---|---|
| 0 | **9936** | USDJPY.DWX (**host**) | runner | `OnTick` (host ticks) | per-tick, but host ⇒ **byte-faithful** | pinned same-vintage singleton replay vs standalone 9936 |
| 1 | **10145** | XAUUSD.DWX | satellite | `OnTimer` (D1 poll) | **TIMER-SAFE** (RECON B `:144-148`) | pinned singleton replay vs standalone 10145; also validates the harness |
| 2 | **see §6 gate** | GDAXI.DWX **or** 12969:USDJPY.DWX | satellite | `OnTimer` **or** `OnTick` | measurement-decided | see below |

**Satellite-2 is the one adaptation the evidence forces.** 13301:GDAXI carries the same
per-tick trailing stop as the runner (RECON B `:106-123`), and it is a **non-host** symbol,
so its exits cannot reach `match_rate == 1.0` under `OnTimer`. Per the task's adaptation
clause, I resolve it by a **measurement gate that runs before any satellite-2 code ships**
(so the fidelity risk is *resolved*, not planned around):

- **Measure** from the durable gated Q08 stream for `13301:GDAXI`: of all closed trades,
  how many exits are **+1R-trail-stop hits** vs **18:00 time-exit / opposite-range-touch**
  (RECON B `:190-195`, option (b)). The time-exit and opposite-touch are minute-aligned and
  reproduce under an M5-cadence poll; only trail-stop hits are the per-tick hazard.
- **If zero trail-stop-hit exits exist** in full history (the trail never binds before the
  evening flat), GDAXI's realised exits are time/structure-driven and **reproducible** →
  admit **13301:GDAXI** as satellite-2 on `OnTimer` (M5 poll), keeping the top-ranked book
  (OOS FUND_SCORE 0.641, OOS wDD p90 3.464%; `..._runner_satellite_composition.md:19`).
- **If any trail-stop-hit exits exist** (1.0 unreachable), **replace** satellite-2 with
  **12969:USDJPY.DWX** — a **host-symbol** USDJPY damper co-hosted on the USDJPY chart and
  driven by `OnTick` (zero cadence risk, byte-faithful exactly like the runner, the
  20180-valid two-USDJPY construction). That yields the fidelity-safe book
  `{9936, 10145, 12969}` (composition rank 23: IS 0.485, **OOS 0.551**, OOS wDD p90 3.252%;
  `..._runner_satellite_composition.md:41`). 12969 is host-symbol, so it needs no cadence
  recon — its fidelity is proven by the same pinned singleton replay as the runner.

This is one plan with an evidence-gated branch at the final step, exactly the "what happens
if a step fails" the task asks for. Every other decision below is fixed.

---

## 1. Inputs

New `ea_id`: **reserve the next free id** in `framework/registry/ea_id_registry.csv` at
build time (serial; do not hardcode a guess). This plan writes it `<JEID>`. Slots are
symbol-pinned (the QM5_1017 / QM5_10024 model, RECON 1 `:28,117-136`): slot 0↔host USDJPY,
slot 1↔XAUUSD, slot 2↔the satellite-2 symbol. Per-leg magic `= <JEID>*10000 + slot`.

Symbols are **input parameters** per OWNER, one per sleeve, plus per-sleeve enable and
per-sleeve fixed risk. The host symbol is also an input but is **guarded to equal `_Symbol`**
(the tester's chart symbol) and to equal the runner's symbol.

```mql5
input group "QuantMechanica V5 Framework — BACKTEST-ONLY joint instrument"
input int    qm_ea_id             = <JEID>;
input int    qm_magic_slot_offset = 0;          // host slot
input uint   qm_rng_seed          = 42;

input group "Risk — BACKTEST-ONLY: RISK_FIXED only, never RISK_PERCENT (HR4)"
input double RISK_PERCENT         = 0.0;         // MUST be 0 (guarded in OnInit)
input double RISK_FIXED           = 1000.0;      // native 1x baseline; per-sleeve below
input double PORTFOLIO_WEIGHT     = 1.0;
input double qm_risk_cap_pct      = 1.0;         // framework default; prop OFF => no override

input group "Stress — measurement instrument MUST stay 0 (guarded)"
input double qm_stress_reject_probability = 0.0;

input group "Prop Firm — RECORD not ENFORCE: prop_phase MUST be OFF (guarded)"
// prop_phase comes from QM_PropFirm.mqh; guarded == QM_PROP_PHASE_OFF in OnInit.

input group "Host binding (chart symbol) — guarded to _Symbol AND to the runner symbol"
input string host_symbol          = "USDJPY.DWX";

input group "Sleeve 0 — RUNNER 9936 ff-range-breakout (HOST, OnTick, per-tick faithful)"
input bool   s0_enabled           = true;
input string s0_symbol            = "USDJPY.DWX";   // == host_symbol (guarded)
input double s0_risk_fixed        = 1000.0;
input int    s0_range_start_hr    = 1;              // GMT+3
input int    s0_range_end_hr      = 6;
input int    s0_cancel_hr         = 13;
input int    s0_close_hr          = 20;
input int    s0_atr_period        = 14;
input double s0_min_range_atr_mult= 0.4;
input double s0_max_range_atr_mult= 2.5;
input double s0_trail_trigger_r   = 1.0;
input int    s0_range_scan_bars   = 36;
// News (bound from 9936's gated set, NOT invented):
input QM_NewsTemporalMode      s0_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile s0_news_compliance = QM_NEWS_COMPLIANCE_DXZ;

input group "Sleeve 1 — SATELLITE 10145 tsm-meanret (XAUUSD, OnTimer, TIMER-SAFE, D1)"
input bool   s1_enabled           = true;
input string s1_symbol            = "XAUUSD.DWX";
input double s1_risk_fixed        = 1000.0;
input int    s1_lookback_n        = 15;
input bool   s1_shorts_enabled    = false;
input int    s1_atr_period        = 14;
input double s1_atr_stop_mult     = 3.0;
input double s1_min_abs_mean_return = 0.0;
// News (bound from 10145's gated set — it runs news OFF, QM5_10145...mq5:55-56):
input QM_NewsTemporalMode      s1_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile s1_news_compliance = QM_NEWS_COMPLIANCE_NONE;

input group "Sleeve 2 — SATELLITE (set by the §6 measurement gate)"
input bool   s2_enabled           = true;
input string s2_symbol            = "GDAXI.DWX";    // or "USDJPY.DWX" for the 12969 fallback
input double s2_risk_fixed        = 1000.0;
// ... s2 strategy + news params bound from the chosen sleeve's gated set (13301 M5 range
//     breakout, or 12969 USDJPY). Exact block filled at build time from that set file.
```

Per-sleeve risk is `sX_risk_fixed`, each defaulting to its gated `RISK_FIXED=1000` (native
1x). Equal-weight portfolio sizing is applied **post-hoc by RISK_FIXED linearity** (20180
design §6; `QM_Mod_FtmoJointEquitySampler_20180.mqh:29-33` emits the per-sleeve floating
breakdown that makes any post-hoc leverage vector an exact read), not by changing sizing at
runtime — this keeps each sleeve's trades byte-identical to its standalone at 1x, which is
what the admission gate compares.

---

## 2. The timer loop

**Interval: `EventSetTimer(1)` — one model-second.** RECON A proves `OnTimer` fires on
simulated time in the tester and that the useful floor is 1 s (`TimeCurrent()` is
second-resolution; sub-second fires are indistinguishable and buy nothing — RECON A
`:19-36,89-97`). One second is fine enough to (a) observe every non-host symbol's bar-close
promptly and (b) sample account equity for the FTMO intraday-low read.

**Division of labour — the byte-faithful host path never touches the timer:**

- **`OnTick` handles ONLY the host runner (slot 0)** — kill-switch, host news gate,
  Friday-close, per-tick management (its trailing stop), and closed-H1 entry, exactly as
  standalone 9936 and 20180 sleeve-0 do (`QM5_20180...mq5:250-308`). This is what makes the
  runner byte-identical: same handler, same tick stream, default `QM_Entry` path.
- **`OnTimer` handles the account-equity sampler + every NON-host satellite** (slots ≥1),
  and nothing on the host runner.

**On each `OnTimer` fire (pseudocode, order fixed):**

```
OnTimer():
  now = TimeCurrent()                         // simulated, 1 s resolution
  QM_JEq_OnTick()                             // 1) equity low sampler: sample ACCOUNT_EQUITY,
                                              //    emit EQUITY_LOW on new intraday low + day
                                              //    rollover anchor (catches NON-host lows to 1 s)
  if(!QM_KillSwitchCheck()) return            // 2) shared kill switch
  for each enabled NON-host sleeve s:         // 3) per-symbol dispatch
     if(!news_allows(s.symbol, now, s.news))  continue   // per-sleeve news on s.symbol
     Strategy_Manage(s)                       //    TIMER-SAFE sleeves: server-SL only / no-op
     if(Strategy_ExitSignal(s)) CloseAll(s)   //    closed-bar-deterministic exit
     if(!QM_IsNewBar(s.symbol, s.tf)) continue //   4) per-SYMBOL new-bar gate (idempotence)
     QM_JEq_OnNewBar(s)                        //    optional per-sleeve equity bar marker
     Strategy_TryEntry(s)                      //    once per that symbol's closed bar
```

**New-bar detection per symbol.** `QM_IsNewBar(sym, tf)` tracks `last_bar_time` per
`"<sym>|<tf>"` key (`framework/include/QM/QM_Indicators.mqh:108-137`). It returns `true`
exactly once per (symbol, timeframe) bar. The runner's `OnTick` uses key `USDJPY|H1`; the
XAUUSD satellite uses `XAUUSD|D1`; GDAXI (if kept) uses `GDAXI|M5`. **These keys are
disjoint**, so the `OnTick` and `OnTimer` paths never race the same tracker entry. The
`OnTimer` path MUST NOT call `QM_IsNewBar(host, H1)` and `OnTick` MUST NOT call it for any
satellite symbol — responsibility is partitioned by symbol.

**Idempotence — act once and only once per bar per symbol.** Two guards, belt and braces,
because RECON A shows bursts up to ~797 fires share one `TimeCurrent()` second and fires
occur before the first tick (`:98-103`):
1. `QM_IsNewBar(sym, tf)` — the primary once-per-bar latch (single global tracker, so a
   burst of same-second fires yields exactly one `true`).
2. Per-sleeve `orders_day_key` / `bar_key` latch inside the sleeve state (the
   `QM_Mod_FtmoJointRangeBreakout_20180.mqh:63-66,244-274` pattern: `st.orders_day_key ==
   day_key` blocks a second entry the same day even if a fire slips the first guard). Every
   satellite module carries this latch and also checks `HasOurOpenPosition /
   HasOurPendingOrders` before arming (module `:246-247`).

A double-fire is a duplicate trade; these two guards together make it structurally
impossible for a satellite to open twice for one bar.

---

## 3. Dispatch by symbol

**Mechanism: per-strategy-family reentrant modules, one instance bound per sleeve, each
parameterised BY SYMBOL.** This extends the shipped 20180 pattern
(`QM_Mod_FtmoJointRangeBreakout_20180.mqh`), whose one flaw for this book is that it is
hardcoded to `_Symbol` (USDJPY-only; module header `:32-35`). The new modules take the
sleeve's symbol as a field and read/write that symbol, so one module can drive a **non-host**
leg.

- **Runner (host, slot 0)** reuses the existing range-breakout family logic through the
  **default single-symbol `QM_Entry` path** (`QM_TM_OpenPosition(req, ticket,
  explicit_magic=0)`), `_Symbol`-bound, **byte-identical to standalone 9936** — the same
  binding 20180 sleeve-0 used (`QM5_20180...mq5:196,272,279`;
  `QM_TradeManagement.mqh:276-280`). No symbol parameter needed because host == its symbol.
- **Satellites (non-host, slots ≥1)** cannot use that path: `QM_EntryRequest` has **no
  `symbol` field** — it is `_Symbol`-bound (`framework/include/QM/QM_Entry.mqh:13-21`). They
  MUST open through the **basket order path** `QM_BasketOpenPosition(ea_id, news_mode,
  deviation, req, out_ticket)`, whose `QM_BasketOrderRequest` carries `symbol` + `symbol_slot`
  and sizes with the same `QM_LotsForRisk(symbol, sl_points)` (RECON 1 `:214-225,271-274`).

Two order paths, deliberately: the host sleeve must match standalone byte-for-byte via the
default path; non-host sleeves must use the symbol-aware basket path. A NEW module is written
per non-host strategy family:
- `QM_Mod_JointTsmMeanret.mqh` — copy of `QM5_10145` `Strategy_EntrySignal/ExitSignal`
  (`QM5_10145...mq5:98-206`), made reentrant + symbol-parameterised (read
  `iClose(s.symbol, PERIOD_D1, …)`, size + open on `s.symbol` via the basket path, ATR
  server stop). No management (`:167-170`).
- If satellite-2 is GDAXI: `QM_Mod_JointMinuteRangeBreakout.mqh` — copy of `QM5_13301`
  M5-range logic, symbol-parameterised. If satellite-2 is 12969:USDJPY: it is host-symbol
  and joins the runner's family module on the `OnTick` path with its own magic/params.

**Why COPY and not re-point the gated EAs** — the 20180 adversarial review and diagnosis:
recompiling the gated 9936/10145/13301 against a shared include risks silently invalidating
their gated Q08 streams and forcing a full re-gate
(`QM_Mod_FtmoJointRangeBreakout_20180.mqh:11-18`). Copy the logic; leave the gated EAs
untouched; prove equivalence by replay.

**Fidelity is PROVEN, not asserted — the corrected 20180 control.** The 20180 miss was an
invalid control (July-14 standalone binary vs July-27 joint binary — execution-identity
drift; `2026-07-27_joint_ea_fidelity_diagnosis.md:68-97,149-163`). Every admission step here
uses a **pinned same-vintage control**:
1. Pin ONE repo commit, ONE compiler/terminal build, ONE terminal tick-store image, ONE
   commission group.
2. Compile the standalone sleeve AND the joint EA (that sleeve enabled) from that same state.
3. Run both **sequentially on one reserved terminal**, harvesting each sleeve's Q08 stream
   before the next run truncates it.
4. Diff with `tools/strategy_farm/compare_joint_replay.py`, which pairs on the exact tuple
   `(entry_time, close_time)` with `net ±0.005` and `volume ±0.005`, and returns pass **iff
   `match_rate == 1.0` AND `unmatched_joint == 0` AND `leftover_gated == 0`**
   (`compare_joint_replay.py:11-19,47-48,97-111`). The comparator ignores entry/exit *price*,
   side and reason string, so cosmetic differences between the default and basket order paths
   (normalisation, reason text) do not fail the gate; only real entry-time / exit-time / net
   / volume differences do.

**One pre-registered comparator refinement, OWNER-ratified before Step 2, for non-host
market entries only.** A non-host satellite's market entry executes in the `OnTimer` fire
that first observes the new bar; its recorded second is the smallest timer-second ≥ the
bar's first tick, which may differ from the standalone's tick-driven entry second by ≤1 s
(within-second event ordering in the tester is NOT ESTABLISHED — RECON A `:281-283`). If, and
only if, the Step-2 (10145) run shows its *sole* mismatches are non-host market entries
shifted by ≤1 s for the SAME bar (diagnosed via the diagnostic categories the 20180 review
told us to add — `2026-07-27_joint_ea_fidelity_diagnosis.md:107-113`), we floor `entry_time`
to the sleeve's bar for **non-host market entries** while keeping `close_time`, `net` and
`volume` exact. This is a narrowly-scoped matching-key refinement (the 20180 review
sanctioned adding categories, not relaxing the threshold), and it needs OWNER sign-off before
it is applied. If OWNER declines, the Step-2 gate stays exact-second and the 10145 run is the
arbiter of whether exact-second alignment is achievable at all.

---

## 4. Per-sleeve isolation

- **Magic numbers.** Slot-pinned: slot 0 = host USDJPY, slot 1 = XAUUSD, slot 2 = satellite-2
  symbol; magic `= <JEID>*10000 + slot` (RECON 1 `:335-339`). Registered in `OnInit` via
  `QM_MagicFor(<JEID>, slot)` (binds slot→symbol context + registers with the kill switch,
  which the explicit-magic path requires — `QM5_20180...mq5:180-190`). Each leg opens with
  its own magic: host slot via the default path (`explicit_magic=0`), non-host slots via the
  basket path which resolves `QM_MagicChecked(ea_id, req.symbol_slot, req.symbol)` (RECON 1
  `:220-225`). Per-sleeve `OnInit` asserts `QM_MagicRegistered(<JEID>, slot)` (the QM5_1017
  guard, RECON 1 `:456-457`) so a slot↔symbol drift fails loud, not silent.
- **Position selection by magic.** Every management/exit/close loop filters
  `PositionGetString(POSITION_SYMBOL) == s.symbol && POSITION_MAGIC == s.magic` — the exact
  20180 module pattern (`QM_Mod_FtmoJointRangeBreakout_20180.mqh:156-172,294-302,357-372,
  380-390`), but with `s.symbol` in place of the hardcoded `_Symbol`. The two sleeves are
  independent state machines, each seeing only its own (symbol, magic).
- **Per-symbol state.** Each sleeve owns a `QM_FJ_*_State` struct (range levels, day keys —
  module `:60-76`); nothing is a shared global. State is `ArrayInit`'d in `OnInit`.
- **News filter `symbol_slot`.** Every order request sets `req.symbol_slot = s.slot`
  explicitly. `QM_BasketOrderRequest` has **no** default ctor (RECON 1 `:294-305`), so an
  unset slot sends stack garbage into magic resolution — every leg MUST set it (the shipped
  basket EAs all do). News itself is queried **per sleeve on its own symbol**:
  `QM_NewsAllowsTrade2(s.symbol, now, s.news_temporal, s.news_compliance)`. Configs are
  heterogeneous — 9936 = PRE30_POST30+DXZ, 10145 = OFF (`QM5_10145...mq5:55-56`) — so there
  is **no single global news gate**; each sleeve carries its own news inputs bound from its
  gated set. Index/CFD symbols map to their economy currency inside the filter
  (GDAXI→EUR; RECON 1 `:289-291`); the XAUUSD sleeve runs news OFF so its mapping is moot,
  but must be verified equal to standalone at Step 2, not assumed.
- **Indicator handles per symbol.** All indicator/price reads pass `s.symbol` explicitly:
  `QM_ATR(s.symbol, tf, …)`, `iClose(s.symbol, …)`, `SymbolInfoDouble(s.symbol, …)`. The
  framework pools handles per (symbol, params), so per-symbol handles are automatic once the
  symbol argument is threaded through — the single change the 20180 modules did not need
  (they were `_Symbol`-only) and the new modules must make everywhere.
- **History warmup (required for non-host symbols).** `OnInit` calls
  `QM_SymbolGuardInit({USDJPY, XAUUSD, sat2})` (basket mode, n>1) AFTER `QM_FrameworkInit`,
  then `QM_BasketWarmupHistory(list, tf, warmup_bars)` per symbol. Without it, non-host reads
  return nothing and the run fast-finishes to INVALID (RECON A `:130-136`; RECON 1
  `:254-265`). The runner (host) needs no warmup but the satellites do.

---

## 5. Account-level FTMO accounting

**One account, one real equity path.** Because it is one EA on one host chart, MT5 computes
ONE `ACCOUNT_EQUITY` from every open leg's floating P&L continuously — the real path the
20180 instrument was built to capture (`QM5_20180...mq5:14-17`). This closes the
a5768d03 gap: the shipped `QM_EquityStreamOnNewBar` emits only one snapshot per day-close, so
the intraday low the −5% daily rule is a predicate on is invisible
(`a5768d03_equity_export_gap_2026-07-27.md:36-43`).

**Sampler = `QM_Mod_JointEquitySampler.mqh`**, the 20180 sampler generalised to N symbols
(`QM_Mod_FtmoJointEquitySampler_20180.mqh`). Row types unchanged:
- `EQUITY_BAR` — one per host H1 closed bar (account equity/balance + per-magic floating
  breakdown, so post-hoc re-leveraging by RISK_FIXED linearity is exact; module `:108-133`).
- `EQUITY_LOW` — every new per-broker-day intraday low of `ACCOUNT_EQUITY`, plus a
  day-rollover anchor (module `:139-161`).
- Path host-keyed: `Common\Files\QM\q08_equity\<JEID>_USDJPY_DWX.jsonl` (module `:92-95`).

**The one change from 20180 that this book forces (adversarial-review C4 now bites).** 20180
was USDJPY-only, so every account-equity move happened on a host tick and the per-`OnTick`
sampler saw every intraday low at full resolution (module `:28-33`). This book carries
**non-host** symbols (XAUUSD, and GDAXI/12969) whose intraday troughs can fall **between host
ticks**, where `OnTick` is blind. Fix: **drive the low-sampler from BOTH `OnTick` (host-tick
resolution) AND `OnTimer` (1 s resolution)** — the `QM_JEq_OnTick()` call at the top of
`OnTimer` (§2) samples the real `ACCOUNT_EQUITY` every model-second, which already reflects
all non-host legs' floating P&L. Residual, stated honestly: a true intraday low that occurs
and reverts entirely **within one 1 s window** on a non-host symbol is missed to <1 s — a
bounded, conservative under-read of the −5% daily depth, not an unbounded proxy.

**Predicates are post-hoc reads (RECORD, never ENFORCE).** The instrument is a measurement
tool: `prop_phase` guarded OFF, `RISK_PERCENT` guarded 0, stress guarded 0, refuses to init
outside the tester and refuses any non-USDJPY host (the 20180 guards,
`QM5_20180...mq5:113-145`). `challenge_campaign.py` / the FTMO reader then evaluate, off the
sampled stream:
- **−5% daily**: for each broker day, `min(EQUITY_LOW.equity) / day_open − 1 ≤ −0.05`.
- **−10% total**: `min(all EQUITY_LOW.equity) / initial_balance − 1 ≤ −0.10`.
- **+10% / +5% pass targets**: `balance` crossing on the `EQUITY_BAR` series.

No enforcement, no flatten, no `QM_PropEntryAllowed` gating in the trade path — enforcement
would perturb the trades and break the singleton-replay control. The account is a passive
recorder; the FTMO verdicts are computed downstream from the equity JSONL at any leverage
vector.

---

## 6. Build order — piece by piece (OWNER: "Stück für Stück", admit each at match_rate == 1.0)

Each step is gated; a later sleeve is not started until the earlier one is admitted at
`match_rate == 1.0`. **After adding any sleeve, re-run the joint EA with all admitted sleeves
enabled and confirm every already-admitted sleeve STILL matches 1.0** (a new sleeve must not
perturb an admitted one — separate magics, symbols, state; this regression check is the joint
integrity proof, run at every step).

**Step 0 — Scaffold (no strategy).** Build the shell: backtest-only guards; host guarded to
USDJPY == `_Symbol`; `QM_FrameworkInit`; `QM_SymbolGuardInit` + `QM_BasketWarmupHistory` for
all three symbols; `QM_MagicFor` + `QM_MagicRegistered` asserts for slots 0/1/2 (magics
registered dirs→CSV→`update_magic_resolver.py`→verify→compile, serially — RECON 1
`:362-386`); equity sampler wired on `OnTick` and `OnTimer`; `EventSetTimer(1)`. All sleeves
DISABLED. Register the EA in `multisymbol_eas.txt` + payload markers (RECON 1 `:392-404`).
- **Admission gate:** compiles clean (0/0); a short reserved-terminal run warms all three
  symbols (no `NO_REAL_TICKS`/INVALID), emits a non-empty `EQUITY_BAR`/`EQUITY_LOW` stream,
  and places **zero trades**. Fail ⇒ fix the harness (warmup, magic registration, or RAM
  wedge) before any sleeve.

**Step 1 — Runner alone (9936:USDJPY, host, `OnTick`).** Enable slot 0 only. Build the
pinned same-vintage control (§3). Run standalone 9936 and joint-runner-only sequentially on
one reserved terminal; harvest each stream first.
- **Admission gate:** `compare_joint_replay.py` → `match_rate == 1.0`, zero unmatched, vs
  standalone 9936. The runner is host + default entry path, so this is expected to pass by
  construction once the control is pinned; it is the proof that the 20180 cross-vintage
  defect is gone. **Fail ⇒ do NOT add any satellite.** Trace the first differing entry and
  first shared-entry/different-close (20180 §4 step 5,
  `2026-07-27_joint_ea_fidelity_diagnosis.md:149-163`); the runner must be exact before the
  book has any return engine.

**Step 2 — Satellite-1 (10145:XAUUSD, `OnTimer`, TIMER-SAFE) — ALSO the harness validator.**
Enable slot 1. Pinned control vs standalone 10145.
- **Admission gate:** `match_rate == 1.0` vs standalone 10145 (with the §3 non-host-entry
  refinement only if OWNER-ratified). Because 10145 is provably timer-safe and
  closed-D1-deterministic (RECON B `:144-148`), if it CANNOT reach 1.0 the **OnTimer harness
  is broken** (timestamp alignment, basket order path, or warmup) and no cadence tuning on
  the others will help (RECON B `:169-173`). **Fail ⇒ fix the harness; do NOT touch
  satellite-2.** This step is where the deep non-host `entry_time` question (§7 risk 1) is
  detected early, not at the end. Also confirm the runner (slot 0) STILL matches 1.0 in the
  two-sleeve joint run.

**Step 3 — Satellite-2 (measurement-gated).** BEFORE writing any satellite-2 code, run the
GDAXI trail-materiality measurement (§0) on the durable gated `13301:GDAXI` Q08 stream.
- **If zero trail-stop-hit exits:** implement 13301:GDAXI (M5 `OnTimer`), pinned control vs
  standalone 13301. Admission: `match_rate == 1.0`.
- **If any trail-stop-hit exits:** implement the fallback 12969:USDJPY as a co-hosted
  `OnTick` sleeve (slot 2, host symbol), pinned control vs standalone 12969. Admission:
  `match_rate == 1.0`.
- **Fail (either):** exclude satellite-2 and ship the proven 2-sleeve book `{9936, 10145}`
  (still an OOS-positive drawdown improvement over the runner alone —
  `..._runner_satellite_composition.md:13`), and escalate the satellite-2 choice to OWNER
  with the diagnostic categories. Confirm slots 0 and 1 STILL match 1.0 in the three-sleeve
  joint run.

Only after all admitted sleeves match 1.0 in the combined run does the instrument go to the
pipeline (Q08 host-keyed stream → Q09 portfolio), which is downstream of this plan.

---

## 7. What could still make this fail (residual risks + early detection)

1. **Non-host `entry_time` quantisation (the deep one).** A timer observes a non-host bar's
   entry at a model-second that can differ from the standalone's tick-driven second by ≤1 s;
   within-second tester event ordering is NOT ESTABLISHED (RECON A `:281-283`). The exact
   `(entry_time, close_time)` comparator (`compare_joint_replay.py:47-48`) would flag that as
   a mismatch even for a timer-safe sleeve. **Detected early at Step 2** (the 10145 harness
   gate) — the whole reason 10145 goes before any risky sleeve. Mitigation is the
   OWNER-ratified, narrowly-scoped bar-resolution entry refinement (§3), applied only if the
   diagnostics show ≤1 s same-bar shifts as the sole mismatch.

2. **GDAXI per-tick trail unreproducible under `OnTimer`.** RECON B `:106-123` — non-host +
   per-tick trailing stop cannot reach 1.0 at any interval. **Resolved before any code
   ships** by the Step-3 measurement gate; if the trail binds, GDAXI is replaced by the
   host-symbol 12969 fallback. This is the one place the composition adapts, and it adapts on
   evidence, not hope.

3. **Basket order path ≠ single-symbol path (sizing/normalisation drift).** Non-host legs use
   `QM_BasketOpenPosition`; standalone sleeves use `QM_TM_OpenPosition`. Both size via
   `QM_LotsForRisk(symbol, …)` (RECON 1 `:243,271-274`), so volumes should match, but a
   normalisation or send-policy difference could shift net or volume. **Detected by the
   singleton replay** (the comparator matches net/volume; price/reason are ignored, so only a
   *real* sizing difference fails). Traced per 20180 §4 step 5 if it appears.

4. **Equity sampler under-samples a sub-1 s non-host low.** §5 — a low that reverts within one
   1 s timer window on a non-host symbol is missed to <1 s. Bounded and conservative.
   **Detected** by cross-checking `EQUITY_LOW` density against per-trade MAE in the harvested
   streams; if a trade's MAE implies an equity trough deeper than any sampled `EQUITY_LOW`
   that day, the sampler is under-resolved and the interval is tightened.

5. **Q06 stress memoisation assumes all legs open in one `OnTick`** (RECON 1 `:434-440`). This
   book staggers entries across symbols/bars, which would mis-reject under Q06/Q07. **N/A for
   the measurement instrument** (stress guarded 0), but it MUST stay guarded; a future stress
   run of this joint EA is unsafe without reworking the per-basket memoisation. Stated so it
   is not silently inherited.

6. **RAM / launch_fault on the multi-symbol load** (3 symbols; RECON 1 `:392-404`). **Detected
   at Step 0** — if the scaffold run wedges (`launch_fault`, real-rate ~0), the EA is missing
   its `multisymbol_eas.txt` registration / payload markers, or the fleet ran it concurrently
   with another heavy load. Test SERIALLY; never several multi-symbol runs at once.

7. **host_symbol stream mis-keying → trades=0 / INVALID** (RECON 1 `:194-208`). The joint EA
   emits Q08 under host=USDJPY; the aggregator must resolve the host-keyed stream. **Detected
   at Step 0** (zero-but-expected trades is fine there; a later `trades=0/INVALID` with
   sleeves enabled points at stream keying). The fidelity gates read the EA's own harvested
   stream directly, so this bites only downstream at pipeline Q08/Q09, not the replay gates.

8. **Magic-resolver race / slot↔symbol drift** (RECON 1 `:384-386,450-457`). Builds and regen
   run serially; the per-leg `QM_MagicRegistered` asserts (§4) fail loud on drift. **Detected
   at compile/OnInit**, not at runtime.

9. **Skipping the pinned control** reintroduces the exact 20180 failure (cross-vintage
   execution-identity drift). Not a residual so much as a discipline: every step's control is
   pinned to one commit + one tick-store image + sequential harvest, or its `match_rate` is
   meaningless (`2026-07-27_joint_ea_fidelity_diagnosis.md:149-163`).

---

## 8. Summary

One host, one timer, two order paths. The return engine (9936:USDJPY runner) stays on the
host `OnTick` path where its per-tick trailing stop is byte-faithful by construction; the
damping satellites run non-host on a 1 s `OnTimer` and must be TIMER-SAFE to reach
`match_rate == 1.0`. 10145:XAUUSD is timer-safe and goes first as both a sleeve and the
harness validator; 13301:GDAXI's per-tick trail makes it a non-host fidelity dead-end that a
measurement gate resolves (keep it only if its trail provably never binds, else swap to the
host-symbol 12969:USDJPY damper). Every sleeve is admitted only against a pinned same-vintage
singleton-replay control — the fix for the 20180 defect — and only at `match_rate == 1.0`
before the next is added.

# OnTimer semantics in the MT5 Strategy Tester — RECON A (2026-07-27)

Branch `agents/board-advisor` · `C:\QM\repo` · Author: Claude.
Task: establish, **empirically against this installation and our `.DWX` symbols**,
whether an `OnTimer`-driven multi-symbol EA is viable in the MT5 Strategy Tester.
This document decides that question. Every claim is anchored to a `file:line`, a
tester journal line, or a probe-run row. Where a fact was not established it is
marked **NOT ESTABLISHED**.

Method: static analysis of the framework, plus **one short empirical probe run**
on a reserved free terminal (T2), released after use. A first attempt on T9 was
invalidated by a factory-worker claim that beat the reservation by 34 s (see §7);
the T2 run is clean and is the evidence of record.

---

## 0. Bottom line for the designer

- **`OnTimer` fires in the Strategy Tester, and its cadence is driven by SIMULATED
  (model) time, not wall-clock.** Empirically: `EventSetMillisecondTimer(100)` fired
  **2,591,989** times over **259,196** simulated seconds = **10.0001 fires per
  simulated second** — i.e. exactly one fire per 100 ms of *model* time
  (`2026-07-27_ontimer_probe_journal.txt`, `PROBE_DONE`). If it were wall-clock it
  would have fired ~a few times (the whole 3-day test computed in ~0.6 s of wall
  time). So a timer-driven design **is** deterministic and reproducible in the
  tester. This is the single fact that makes OWNER's design mechanically viable.
- **A non-host `.DWX` symbol's completed bars are readable from inside `OnTimer`,
  with NO look-ahead.** `iTime/iClose` on `XAUUSD.DWX` while the chart ran
  `USDJPY.DWX` returned only bars at or before simulated time in **0 / 3,960**
  logged events (and 0 / 1,069 tick-context reads). The secondary symbol must be
  history-synced first (`SymbolSelect` + a `CopyClose` warmup — the framework's
  FW9 pattern); the probe's warmup returned 300/300 bars and the tester loaded
  `XAUUSD.DWX` **real ticks** alongside the host.
- **Sub-second timers buy nothing in the tester.** Simulated `TimeCurrent()` has
  **1-second** resolution, so all 10 fires inside a model-second report the *same*
  timestamp. The useful floor is **1 second** (`EventSetTimer(1)`).
- **Cost is model-time-bounded and can be enormous.** Fire count =
  `sim_seconds / interval`. Over an 8-year window that is **≈2.5×10⁸** fires at a
  1 s timer and **≈2.5×10⁹** at 100 ms. The *fire overhead* is cheap (2.59 M
  trivial fires added ~0.25 s of compute), but a real per-symbol poll
  (`CopyRates`/indicator reads × K symbols) **per fire** is the true cost and would
  dominate an 8-year run. Gating real work to bar-close (`QM_IsNewBar`) is
  `O(bars)`, not `O(fires)`.
- **There is ZERO prior precedent in this repo for a timer-driven tester EA.** The
  whole framework is `OnTick`-driven; the only `EventSetTimer` caller is the LIVE
  account monitor, and it is explicitly tester-hardened to arm nothing (§5). The
  gate-proven multi-symbol EA (`QM5_12781`, reached Q05–Q08) does per-symbol
  polling from `OnTick`+`CopyClose` with **no timer at all** (§5, §6).
- **Design consequence (the load-bearing one):** every framework evidence and
  risk hook — MAE sampling, kill-switch, Friday-close, news gate, equity-stream,
  new-bar entry — is wired into `OnTick` and is **not** invoked from `OnTimer`
  (§4). A timer-driven EA that manages exits from `OnTimer` runs those exits on a
  code path the framework has never exercised in the tester. This is exactly the
  fault surface behind the `QM5_20180` exit-fidelity failure
  (`2026-07-27_joint_ea_fidelity_diagnosis.md`): same entries, shifted exits. Any
  timer design must re-home (or duplicate) the `OnTick` lifecycle deliberately, not
  inherit it.

---

## 1. Q1 — Does OnTimer fire in the tester, in the factory's tick model, and on simulated or wall-clock time?

**Tick model the factory uses: Model 4 ("Every tick based on real ticks").**
`framework/registry/tester_defaults.json:16-19` (`p2_real_tick_policy.model: 4`).
The probe ran Model 4 and the journal confirms real ticks for **both** the host
and the secondary symbol:

```
USDJPY.DWX : real ticks begin from 2018.01.02 00:00:00
XAUUSD.DWX : real ticks begin from 2018.01.02 00:00:00
USDJPY.DWX,H1: 769186 ticks, 72 bars generated. Test passed in 0:00:00.614
```
(`2026-07-27_ontimer_probe_journal.txt`.)

**Fires: YES.** `PROBE_DONE ... timers=2591989`. `OnTimer` was called 2.59 million
times in a 3-simulated-day run.

**Cadence: SIMULATED (model) time.** `EventSetMillisecondTimer(100)` over a
`sim_span_s=259196` window produced `fires_per_sim_sec=10.0001` — one fire per
100 ms of *model* time, independent of wall-clock. Cross-check: the entire test
(769 K ticks + 2.59 M timer fires) completed in **0.614 s** of wall time
(`Test passed in 0:00:00.614`); a wall-clock 100 ms timer would have fired ~6
times, not 2.59 M. **Model-time cadence is therefore proven, not assumed.**

---

## 2. Q2 — Granularity floor and run-time cost of a fast timer

- **`EventSetMillisecondTimer` works in the tester and is honored at 100 ms**
  (10.0001 fires/sim-sec). `EventSetTimer` (seconds) is the coarser cousin and
  necessarily fires too (probe used the millisecond API, which is a strict
  superset).
- **Effective useful floor = 1 second.** Simulated `TimeCurrent()` is
  second-resolution: all ten 100 ms fires within a model-second carry the *same*
  `sim_iso`/`sim_epoch` (see the CSV — rows 1-300 all read `2018.01.02 00:00:00`).
  Sub-second polling cannot be distinguished by the simulated clock, so anything
  finer than `EventSetTimer(1)` adds fires without adding decidable information.
- **Bursts.** Fires are model-time-scheduled, not evenly delivered:
  `max_fires_per_sim_sec=797` — up to 797 `OnTimer` callbacks shared a single
  1-second `TimeCurrent()` value (observed at a start/gap boundary; the first 300+
  logged fires all occur at `sim=00:00:00` with `tick_no=0`, before the first
  tick). A real handler must be **idempotent to bursts** and must not assume even
  spacing.
- **Cost model.** Fire count over a window = `sim_seconds / interval_seconds`:

  | interval | fires / 8-yr window (≈2.52×10⁸ sim-sec) |
  |---|---|
  | 1 s   | ≈ 2.5×10⁸ |
  | 100 ms | ≈ 2.5×10⁹ |
  | 1 min | ≈ 4.2×10⁶ |
  | 1 hr  | ≈ 7.0×10⁴ |

  The probe shows the *fire mechanism* is cheap (2.59 M fires ≈ 0.25 s compute with
  a trivial body). The **real** cost is the per-fire work of a genuine EA
  (`CopyRates`/indicator reads on each polled symbol). At a 1 s timer that is
  ~10⁸ heavy polls over 8 years — expensive on a saturated fleet. **Recommendation:
  use the coarsest timer the strategy tolerates**, and inside `OnTimer` gate the
  heavy per-symbol work to that symbol's bar-close, so real work stays `O(bars)`.

---

## 3. Q3 — Reading a non-host symbol's completed bars from OnTimer; unsynced history; look-ahead

- **Readable: YES, reliably, once synced.** The probe called `iTime`/`iClose` on
  `XAUUSD.DWX` (non-host) from inside `OnTimer` throughout a `USDJPY.DWX` chart run.
  Reads succeeded from the first fire (`sec_close1` populated with real gold prices,
  e.g. `1303.310` → `1321.920`).
- **Unsynced history behaviour (established, framework-anchored):** `SymbolSelect`
  alone does **not** load a secondary symbol's history in the tester; the first
  per-symbol read returns 0 bars / stale data and the run fast-finishes to INVALID.
  The fix is a `CopyClose` warmup that forces the sync
  (`framework/include/QM/QM_SymbolGuard.mqh:100-141`, FW9; reused by every basket
  EA via `QM_BasketWarmupHistory`). The probe replicated this in `OnInit`
  (`SymbolSelect` + `CopyClose(...,300)`) and `PROBE_INIT ... sec_warm_bars=300`
  confirms the sync succeeded. **A timer-driven joint EA MUST warm every secondary
  symbol the same way**, or the non-host sleeve reads nothing.
- **Look-ahead: NONE observed.** Two hazards were instrumented per event:
  `la_forming` (secondary exposes a bar that *opens* after simulated time) and
  `la_closed` (secondary's "last closed" bar has not yet closed in simulated time).
  Both were `0` across **all 3,960** logged events (0 timer-context, 0 tick-context;
  `2026-07-27_ontimer_probe_events.csv`). Concretely, at `sim=2018.01.02 00:00:00`
  the secondary's most-recent visible bars were `2017.12.29 23:00 / 22:00` — behind
  simulated time, because gold had no ticks over the New-Year holiday. The tester
  exposes a non-host symbol's bars **only up to the current simulated instant**;
  `CopyRates`/`iClose` from `OnTimer` cannot see a bar the host has not reached.

---

## 4. Q4 — Coexistence and ordering of OnTimer and OnTick; which hooks assume OnTick

- **They coexist and share one model-time-ordered event stream.** The probe kept a
  single monotonic `seq` incremented by both handlers. `OnTimer` fired **610 times
  before the first `OnTick`** (`2026-07-27_ontimer_probe_events.csv` row 611:
  `TICK, tick_no=1, timer_no=610`), and thereafter the two interleave by simulated
  time (e.g. row `TICK tick_no=1000` at `seq=16891, timer_no=15891`). So in the
  tester, timer and tick events are drawn from a merged queue ordered by model time;
  `OnTimer` can fire **before, between, and after** ticks.
- **Ordering is model-time, not "tick then timer".** There is no fixed
  per-tick pairing; over the run 2.59 M timer fires interleaved with 769 K ticks.
- **The framework hooks that assume `OnTick`** (all wired in `OnTick`, none invoked
  from `OnTimer`):
  - `QM_FrameworkTrackOpenPositionMae()` — Q08 MAE/equity sampling
    (`framework/templates/EA_Skeleton.mq5:178`).
  - `QM_KillSwitchCheck()` (`:180`).
  - `QM_FrameworkHandleFridayClose()` (`:186`).
  - the two-axis news gate `QM_NewsAllowsTrade2/…` (`:220-226`).
  - `QM_IsNewBar()` closed-bar gate + `QM_EquityStreamOnNewBar()` equity snapshot
    (`:228-233`).
  - `Strategy_ManageOpenPosition()` / `Strategy_ExitSignal()` — **exit management**
    (`:197-212`).
  - The framework's own `OnTimer` does **only** a chart-UI refresh:
    `QM_FrameworkOnTimer()` → `QM_ChartUI_Refresh()`
    (`framework/include/QM/QM_Common.mqh:694-699`) — inert in the tester.
  **Implication:** an EA that manages exits from `OnTimer` gets *none* of the above
  for free. Exit management, the news gate, MAE sampling and equity streaming would
  all have to be re-invoked from the timer path. This is the precise mechanism of
  the `QM5_20180` exit-fidelity miss (same entries, shifted exits;
  `2026-07-27_joint_ea_fidelity_diagnosis.md`): establishing how each target sleeve
  manages exits, and re-homing that code deliberately, is the first design task —
  not a detail.

---

## 5. Q5 — Prior evidence of an OnTimer-driven tester EA in this repo

**None. The repo is uniformly `OnTick`-driven.**

- Every EA carries the skeleton's inert `OnTimer(){ QM_FrameworkOnTimer(); }`
  hook (that is why a naive grep for `OnTimer` matches ~all EAs), but **no**
  pipeline/tester EA calls `EventSetTimer`/`EventSetMillisecondTimer`. A framework
  grep for the timer *starters* returns exactly **one** hit:
  `framework/monitor/QM_AccountMonitor.mq5:618  EventSetTimer(secs)`.
- That one caller is the **LIVE** account monitor and is explicitly
  **tester-hardened**: `OnInit` sets `g_in_tester = MQLInfoInteger(MQL_TESTER)` and
  `if(g_in_tester) return INIT_SUCCEEDED; // arm nothing, touch nothing`
  (`QM_AccountMonitor.mq5:591-593`) — the `EventSetTimer` at `:615-618` is never
  reached in the tester, and `OnTimer(){ if(g_in_tester) return; … }` (`:634-639`)
  is a no-op there. It also uses a ≥5 s wall-clock interval, i.e. it is a
  live-only device.
- **`QM5_12781`** (USDJPY/AUDJPY cointegration — the known multi-symbol precedent,
  reached Q05–Q08) is **entirely `OnTick`-driven**. Its whole cross-symbol path —
  `CopyClose` on both legs, spread z-score, open/close of both legs — runs inside
  `OnTick` gated by `QM_IsNewBar()`
  (`framework/EAs/QM5_12781_edgelab-usdjpy-audjpy-cointegration/QM5_12781_edgelab-usdjpy-audjpy-cointegration.mq5:436-493`,
  cross-symbol reads at `:174-177`); its `OnTimer` is the inert framework stub
  (`:495-498`). **The precedent solves per-symbol polling with no timer at all.**

So the timer-driven design OWNER proposes is *new to this codebase*. That is not a
blocker — Q1–Q4 show it works in the tester — but it means there is no in-repo
harness, no gate history, and no framework lifecycle behind it yet.

---

## 6. Design read-out (recon, not design)

1. **A timer is not required to poll a non-host symbol.** `OnTick` on the host chart
   already fires far more often than any bar close, and (`QM5_12781`) can read every
   non-host symbol's closed bars via `CopyClose`. For **bar-close-cadence** sleeves
   (D1/H1 decisions), the existing `OnTick`+`QM_IsNewBar` pattern is faithful and
   free. A timer earns its cost only when a sleeve must act on a schedule that host
   ticks cannot supply — e.g. **intraday exit management on a non-host symbol** whose
   price moves when the host is quiet. That is the real gap OWNER is targeting.
2. **If a timer is used**, from this evidence: use the **coarsest** interval the
   strategy tolerates (≥1 s; sub-second is wasted); make `OnTimer` **idempotent**
   (bursts up to ~797/sec, fires before the first tick); **warm every secondary
   symbol** (`QM_BasketWarmupHistory`) or reads return nothing; and **re-home the
   `OnTick` lifecycle** (MAE, kill-switch, news, Friday-close, equity-stream, exit
   management) into the timer path explicitly — do not assume it is inherited.
3. **Exit fidelity is the load-bearing risk.** Establish, per target sleeve
   (9936:USDJPY runner, 10145:XAUUSD, 13301:GDAXI), whether exits are managed
   per-tick or at bar-close *before* choosing tick- vs timer-driven exits. A
   bar-close sleeve does not need a timer; a per-tick-exit sleeve on a non-host
   symbol is exactly where the timer (or a host-per-symbol split) is needed, and is
   exactly where `QM5_20180` broke.

---

## 7. The probe — reproducibility and provenance

- **Probe EA** (bare MQL5, no framework, no magic, no orders, no live path):
  `docs/ops/evidence/2026-07-27_ontimer_probe.mq5`. Compiled clean (0 errors,
  0 warnings) via `framework/scripts/compile_one.ps1`.
- **Run of record:** terminal **T2**, agent `Agent-127.0.0.1-3002` / `Core 01`,
  2026-07-27 16:29Z. tester.ini: `Model=4`, `Symbol=USDJPY.DWX`, `Period=H1`,
  `FromDate=2018.01.02`, `ToDate=2018.01.05`, `Deposit=100000 USD`, `Leverage=100`
  (canonical `tester_defaults.json`). EA inputs: `Probe_Secondary=XAUUSD.DWX`,
  `Probe_UseMsTimer=true`, `Probe_TimerMs=100`.
- **Raw evidence (committed):**
  - `docs/ops/evidence/2026-07-27_ontimer_probe_journal.txt` — `PROBE_INIT` /
    `PROBE_DONE` + tester summary lines.
  - `docs/ops/evidence/2026-07-27_ontimer_probe_events.csv` — 3,960 per-event rows
    (seq, handler, tick_no, timer_no, sim time, wall_ms, host/secondary bar opens,
    secondary close, look-ahead flags).
- **The EA placed no orders** (it has no trade calls); the terminal connected to
  Darwinex-Live only for the standard symbol/history sync the factory always uses.
  Terminal launched on a reserved terminal with `ShutdownTerminal=1` and exited
  cleanly; the deployed probe binary was removed from T2 and T9 and the reservation
  released after harvest.

### First-attempt failure (operational note, not evidence)
The first launch targeted **T9**. A factory worker had claimed T9 for `QM5_12512`
at 16:21:15Z — **34 s before** the reservation registered at 16:21:49Z — so the
probe terminal collided with the worker on T9's shared `bases` store
(`'EURUSD.DWX' file opening or reading error [32]`, the documented shared-bases
lock-storm), produced no output, and self-shut. Root cause: `reserve-terminal` is
honored at *claim* time, so it cannot evict a claim already in flight. The T2 retry
added a pre-launch guard (abort if any `terminal64` is already bound to the
terminal root) and ran clean. **Lesson for future ad-hoc runs:** reserve, then
re-confirm the terminal is idle immediately before launch; prefer a quiet fleet
window (the fleet was hot, 6/9 usable terminals busy, at run time).

---

## 8. NOT ESTABLISHED / caveats

- The probe window was 3 simulated days on a warm cache. The **model-time cadence,
  look-ahead absence, warmup requirement, and OnTick/OnTimer interleaving** are
  structural and hold regardless of window length. The **8-year cost figures** in
  §2 are arithmetic extrapolations from the measured fire-per-sim-second rate, not a
  measured 8-year run.
- The exact simulated-time location of the `max_fires_per_sim_sec=797` burst was
  not pinned (the CSV samples 1/1000 after warmup); the burst magnitude and the
  start-of-test pre-tick burst are established, its precise mid-run position is not.
- `EventSetTimer` (seconds API) was not run in isolation; it is inferred to fire
  from the millisecond-API result (a strict superset). Confidence: high, but not a
  separate measurement.
- Whether an `OnTimer`-driven EA's account-equity path is aggregated correctly by
  Q08/Q09 for a joint host is a **separate** gap (`a5768d03_equity_export_gap_2026-07-27.md`)
  and is out of scope here.

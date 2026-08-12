# Joint FTMO Backtest-Only EA (QM5_20180) — RUN RESULTS (2026-07-27)

Branch `agents/board-advisor`. Author: Claude. Consumes the build
(`docs/ops/evidence/2026-07-27_joint_backtest_ea_build.md`).

## 0. Verdict

**The joint backtest was NOT executed. No numbers were produced.** Not because the
build is bad — the EA compiles clean (0/0) and its fidelity/equity mechanisms are in
place — but because the **non-negotiable terminal-safety constraint could not be
satisfied**: at run time there was **no exclusively-free, production-build MT5 terminal**
available, and the instruction is explicit that in that case I "report that instead of
forcing it." I re-checked repeatedly across the session; the fleet is structurally
saturated, not transiently busy. This matches the build doc's own disposition (§3, §8):
the replay + joint run were deferred to "a quiet fleet window, or via the factory
phase-runner." That window did not exist during this session.

Everything needed to run it turnkey is established and recorded below (exact window,
commission parity proof, deploy steps, run order, diff commands). Nothing here is
inferred — each load-bearing fact is anchored to a path/command/hash, or marked NOT
ESTABLISHED.

## 1. Why no terminal was usable (the block, evidenced)

### 1.1 Fleet is deeply saturated (not a transient)
`python tools/strategy_farm/farmctl.py mt5-slots` + the state DB, sampled several times
over ~15 min (10:24–10:40 UTC 2026-07-27):

- Work-item queue depth (`D:/QM/strategy_farm/state/farm_state.sqlite`, `work_items`):
  **`pending` = 2072** (Q02 2002, Q04 31, Q03 26, Q07 10, Q05 3), `active` = 8. This is
  days of backlog, not a lull.
- All non-dead factory terminals carry a live `terminal_worker.py` (workers present for
  T1,T2,T3,T4,T6,T7,T8,T9,T10). Each worker's `run_loop`
  (`tools/strategy_farm/terminal_worker.py:2902-2965`) claims the next of the 2072 queued
  items whenever disk/RAM/commit guards allow — it does **not** honor any per-terminal
  reservation flag (`claim_atomic`, `:960-1060`, has no `disabled_terminals` check;
  `disabled_terminals.txt` is consulted only by the supervisor at spawn,
  `farmctl.py:285-304`).
- The box is **commit-bound**: `terminal_worker_T10.log` shows repeated
  `commit_headroom_low_pause` (≈59.7 GB reserved, incl. QM5_11028 reserving 44 GB;
  effective headroom ≈18 GB < the 24 GB threshold). A commit-parked terminal is **not
  free** — it resumes claiming the instant commit frees (observed: T10 was parked at
  10:24, then claimed item `9a4079d9-...` and was running by 10:40).
- Terminals with no `terminal64.exe` in a given instant (e.g. T4/T8/T9 at 10:40) are
  **between claims**, not free — they fast-fail/complete an item (many INFRA_FAIL /
  ONINIT_FAILED in `terminal_worker_T9.log`) and re-claim within seconds. Sampled T9
  claim events seconds apart: `93077cce-...`, `db80ecd8-...`, `e74c1bfa-...`.

**Consequence:** launching a second `terminal64.exe` on any factory terminal's
`/portable` dir would share that install's tester cache / MQL5 state with the worker's
own launch within seconds → corruption and a disrupted factory item. That is exactly the
"do not interrupt/reuse a terminal running factory work" hard constraint. There is no
supported way to exclusively hold a factory terminal without stopping its worker or
using Factory_OFF — both explicitly forbidden.

### 1.2 DEV1/DEV2 (the only non-factory MT5 lanes) are the WRONG BUILD
DEV1/DEV2 are dedicated non-factory terminals (factory = T1–T10 only,
`farmctl.py:185`) and *would* be collision-free, but:

- `terminal64.exe` size/date: **DEV1 = DEV2 = 109,817,456 B, dated 2026-04-26**; factory
  **T1/T9/T10 = 125,065,008 B, dated 2026-07-25**. Different size ⇒ different MT5 build
  (~3 months older on DEV).
- The `QM5_20180` `.ex5` was compiled 2026-07-27 on the current (Jul-25) build. A
  newer-compiled `.ex5` is generally refused by an older terminal, and even if it loaded,
  the **older build's real-tick tester engine** (run_smoke.ps1 itself carries
  "Build-5833"-specific handling) would not reproduce the production-build gated streams.
- Independent second divergence: DEV2's `bases/Custom/ticks/USDJPY.DWX` is a **separate
  tick-store vintage** from the factory's post-de-junction stores — NOT ESTABLISHED to be
  identical, so it could differ regardless of build.

Either divergence would make a replay `match_rate < 1.0` for a reason that is **not** an
EA-fidelity defect — a fabricated finding the build doc explicitly refused to produce.
Neutralising both would require recompiling current 9936 + 13213 + 20180 on DEV's build
and running standalone references there too (a build-internal control) — a large, fragile
detour that abandons the task's premise of a faithful replay against the **existing
production-build gated streams**. Not done.

## 2. What IS established and ready (turnkey inputs for the run)

| item | value | evidence |
|---|---|---|
| EA compiles | PASS 0 errors / 0 warnings | build doc §0; `framework/build/compile/20260727_100733/QM5_20180_ftmo-joint-sim-backtest-only.compile.log` |
| Built `.ex5` | `framework/EAs/QM5_20180_ftmo-joint-sim-backtest-only/QM5_20180_ftmo-joint-sim-backtest-only.ex5` (374,162 B) | `ls` |
| Host / TF | USDJPY.DWX / H1 (hard-coded, `OnInit` refuses other charts) | `QM5_20180_...mq5:141-145` |
| **Exact window** | **FromDate=2017.01.01, ToDate=2025.12.31** | gated Q08 runs `D:/QM/reports/pipeline/QM5_9936/20260727_051717/raw/run_01/tester.ini` and `.../QM5_13213/20260725_212855/.../tester.ini` (both) |
| Model / deposit / leverage / currency | Model=4, Deposit=100000, Leverage=100, USD | those tester.ini + `framework/registry/tester_defaults.json` (100000/USD/100) |
| **Commission parity** | canonical Darwinex groups file is **byte-identical** across factory + DEV2 + repo — SHA256 `25314333af81faf48e2afe2db5d52beea640cc74ec33a85a46b7c43aadb921dd` for `T1/.../Groups/Darwinex-Live_real.txt`, `DEV2/.../Groups/Darwinex-Live_real.txt`, `framework/registry/tester_groups/Darwinex-Live_real.canonical.txt` | `sha256sum` |
| Gated commission is real (not zero) | e.g. 9936 trade: `net -5.25, commission -8.13, volume 3.25` ⇒ ≈ $2.50/lot round-trip | `sleeve_streams/QM/q08_trades/9936_USDJPY_DWX.jsonl` (first TRADE_CLOSED) |
| Gated reference streams (replay targets) | `D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/9936_USDJPY_DWX.jsonl` (1252 closed trades), `.../13213_USDJPY_DWX.jsonl` (1596) | line count of TRADE_CLOSED |
| News calendar (present + fresh) | `C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/Common/Files/news_calendar_2015_2025.csv` (4.44 MB, mtime 2026-07-27 05:30) | `find -printf` |
| Streams the run emits (FILE_COMMON, shared Administrator Common) | trades → `.../Common/Files/QM/q08_trades/20180_USDJPY_DWX.jsonl`; equity → `.../Common/Files/QM/q08_equity/20180_USDJPY_DWX.jsonl` | `QM_Common.mqh` file conv.; `QM_Mod_FtmoJointEquitySampler_20180.mqh:94` |
| No pre-existing 20180 files in Common (clean) | none | `ls .../q08_trades/20180*` empty |
| Fidelity diff tool | `tools/strategy_farm/compare_joint_replay.py` (keys `(entry_time, close_time, net, volume)`; exit 0 iff match_rate==1.0) | read in full |
| Set files | `..._USDJPY.DWX_H1_backtest.set` (joint), `..._replay_s0.set` (9936 only), `..._replay_s1.set` (13213 only) | EA `sets/` dir |

Both sleeves are host-symbol USDJPY.DWX, so the run needs **no basket mode / no history
warmup / no basket manifest** (build doc §1); a factory terminal launched as
Administrator writes to the shared Administrator Common, so the new `20180_*` files are
conflict-free with the factory (build doc §3).

## 3. Ready-to-run protocol (execute on a genuine quiet window OR via the factory phase-runner)

For each config below: deploy then launch a **free, production-build** terminal
(`D:/QM/mt5/T{n}/terminal64.exe /portable /config:<tester.ini>`, ShutdownTerminal=1),
then harvest before the next config (each run truncates `20180_USDJPY_DWX.jsonl`).

Deploy (per terminal `Tn`):
- copy the `.ex5` → `D:/QM/mt5/Tn/MQL5/Experts/QM/QM5_20180_ftmo-joint-sim-backtest-only.ex5`
- copy the set → `D:/QM/mt5/Tn/MQL5/Profiles/Tester/<setname>.set`
- ensure `Tn/MQL5/Profiles/Tester/Groups/Darwinex-Live_real.txt` == the canonical hash above

`tester.ini` (identical except Report/ExpertParameters):
```
[Tester]
Expert=QM\QM5_20180_ftmo-joint-sim-backtest-only
Symbol=USDJPY.DWX
Period=H1
Model=4
ExecutionMode=0
Optimization=0
OptimizationCriterion=0
FromDate=2017.01.01
ToDate=2025.12.31
ForwardMode=0
Deposit=100000
Currency=USD
ProfitInPips=0
Leverage=100
UseLocal=1
Visual=0
Replace=1
ReplaceReport=1
ShutdownTerminal=1
Report=<ea>_USDJPY_DWX_<runtag>_<name>.htm
ExpertParameters=<setname>.set
```

Run order + admission gate:
1. `replay_s0.set` → copy `Common/.../q08_trades/20180_USDJPY_DWX.jsonl` to
   `20180_s0.jsonl`, then
   `python tools/strategy_farm/compare_joint_replay.py --joint 20180_s0.jsonl --gated .../9936_USDJPY_DWX.jsonl`.
2. `replay_s1.set` → same → diff vs `.../13213_USDJPY_DWX.jsonl`.
3. Admit each sleeve **only at `match_rate == 1.0`** (build/design admission gate; a low
   rate is a finding to report, not to tune). Once commission and window match (both
   established above) a bit-for-bit result is expected for sleeve 0 (default QM_Entry
   path, byte-identical to standalone 9936 per build doc §2).
4. `backtest.set` (both sleeves) → harvest `q08_trades/20180_USDJPY_DWX.jsonl`
   (per-sleeve realised P&L, grouped by magic 201800000/201800001) **and**
   `q08_equity/20180_USDJPY_DWX.jsonl` (EQUITY_BAR per H1 bar + EQUITY_LOW per new
   intraday low, with per-magic floating breakdown), **plus** the `.htm` tester report.
5. Post-analysis on the JOINT streams: (a) realised daily-P&L correlation between the two
   sleeves; (b) true account-equity path → observed max daily loss and max drawdown vs
   FTMO −5% / −10%; (c) count of −5%-daily breaches from OBSERVED intraday equity
   (EQUITY_LOW), not the MAE proxy. Record wall-clock + peak RAM of each run.

Sanctioned collision-free execution: route steps 1/2/4 through the **factory
phase-runner** (build doc §3, §8 — it owns the terminal and the shared-Common
compare-and-swap), or run them by hand on a terminal that is genuinely idle because the
2072-item queue has drained. Both remove the worker-collision hazard by construction.

## 4. Measured this run

- Correlation (9936↔13213 daily P&L): **NOT ESTABLISHED** — run not executed.
- True account equity path / max daily loss / max drawdown vs −5%/−10%: **NOT ESTABLISHED**.
- −5%-daily breach count from observed intraday equity: **NOT ESTABLISHED**.
- Wall-clock / peak RAM: **NOT ESTABLISHED**.

## 5. Status / risks / recommended next step

- **Status:** run blocked by terminal safety (fleet saturated, 2072-deep queue; DEV lanes
  wrong build). All non-run preconditions verified; commission + window parity proven;
  deploy/harvest/diff protocol fixed.
- **Risk if forced anyway (rejected):** sharing a factory `/portable` install with its
  worker corrupts tester state and disrupts a factory item; DEV lanes yield a
  build-/tick-divergent stream that fabricates a false fidelity mismatch.
- **Recommended next step:** execute §3 via the factory phase-runner (preferred), or on a
  genuinely idle terminal once the queue drains. No source or config change is required —
  only an execution window.

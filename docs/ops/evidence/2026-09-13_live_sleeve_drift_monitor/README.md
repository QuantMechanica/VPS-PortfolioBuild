# Live Sleeve Drift Monitor — evidence (2026-09-13)

**Tool:** `tools/strategy_farm/live_sleeve_drift_monitor.py` (schema `qm.live-sleeve-drift/v1`)
**Tests:** `tools/strategy_farm/tests/test_live_sleeve_drift_monitor.py` (11 passed)
**Trigger (OWNER 2026-09-13):** three live sleeves (12778 / 12969 / 13117) sat *dark*
for seven weeks and nothing compared live activity against backtest expectation, so
no alarm fired. This monitor closes that gap. **Read-only, exits 0 always (monitor,
not a gate).**

## What it does

For every deployed sleeve in `live_book_pulse.json → book_manifest.sleeves` it
compares what the sleeve has actually done on **T_Live** against its own sealed
backtest stream and raises deterministic alarms:

| Check | Source | Alarm |
|---|---|---|
| **Activity** | **FILLED positions** (not placements) vs Poisson(`λ_bt·days_live`) | `ALARM_DARK` (obs=0, P(X≤0)<0.01), `WARN_LOW_ACTIVITY` (P<0.05), `WARN_HIGH_ACTIVITY` (over-trading, P(X≥obs)<0.01) |
| **Performance** | live price R = `dir·(exit−entry)/(entry−SL)` vs backtest R = `net/1000` | `WARN_PERF` (n≥10, one-sided Mann-Whitney p<0.05) |
| **Heartbeat** | age of last EA-log line while terminal RUNNING | `ALARM_SILENT` (>2 trading days) |
| **Symbol sanity** | EA-log symbol vs manifest slot; `.DWX` literal; `BASKET_WARMUP loaded=0` | `ALARM_SYMBOL_MISMATCH`, `ALARM_WARMUP_EMPTY` |

**Observed = FILLED positions, not order placements** (OWNER refinement 2026-09-13):
several sleeves place pending stop orders daily and cancel the unfilled leg, so
`TM_OPEN ok=true` counts (now reported separately as `placements`) inflate activity.
`observed` = distinct entry order tickets (from `TM_OPEN ok=true`, per slot symbol)
that appear as a terminal-journal `deal … done (based on order #N)` line
(`observed_source=journal_fill_join`). Fallback when a lone sleeve owns the symbol
and TM_OPEN tickets are unavailable: distinct positions opened via a per-symbol deal
FIFO (`journal_deals_per_symbol`); if a symbol is shared and tickets are missing,
fills are left unresolved (`WARN_UNRESOLVED_FILLS`) — never guessed. In this run all
active sleeves resolved via `journal_fill_join` (the fallback did not fire).

**Deploy date** = manifest `ex5_deployed_mtime` (falls back to first `INIT_OK` in the
EA log; source is recorded per sleeve in `deploy_source`).
**λ_bt** = backtest trades ÷ Mon–Fri days spanned (holidays not modelled — a
documented, deterministic simplification; it slightly *raises* expected, which is
conservative for a DARK test). **days_live** = Mon–Fri days deploy→now.
Streams: `dxz_v2_20260913/streams_v2b` first, else `dxz_final_20260719` (where the
three dark sleeves live). All constants are declared at the top of the module and
echoed in the output `constants` block. Runtime: **~1.1 s** for 24 sleeves + 248
journal deals (< 60 s budget).

## Run

```bash
cd C:/QM/repo
python -X utf8 tools/strategy_farm/live_sleeve_drift_monitor.py \
  --out D:/QM/reports/state/live_sleeve_drift.json
# reproducible history / as-of run:
python -X utf8 tools/strategy_farm/live_sleeve_drift_monitor.py --now 2026-08-25T20:00:00Z --out <tmp>
```
CLI: `--pulse --ea-log-dir --journal-dir --stream-root (repeatable) --out --markdown --now`.
`--out` is refused if it resolves under `C:/QM/mt5/T_Live` (read-only contract).

## Read-only contract

Only `--out` (+ optional `--markdown`) is written, never under T_Live. T_Live files
are opened read-only; no MetaTrader5 API, no terminal/task control. `farm_state.sqlite`
is not touched. Journal deal lines carry account tickets (T_Live shares the DXZ
account with T1–T10 by OWNER design, OQ-17) — deals are attributed to a sleeve
**only** via order ticket, never counted blind.

## Alarm-source registration decision

`live_book_pulse.build_alarms(snapshot)` is a **monolithic, snapshot-only** function
with **no external alarm-producer hook** (verified: `main()` calls `build_alarms`
on its own internally-parsed snapshot and ingests no external alarm file). There is
no clean plug-in point, so per the task the monitor **writes a standalone JSON** to
`D:/QM/reports/state/live_sleeve_drift.json` instead of editing `live_book_pulse.py`.

### Hourly-watch wiring (proposed — the watch was NOT edited)

`tools/strategy_farm/session_tools/hourly_watch_0909.py` already reads state JSONs
and emits `ALERT` lines. Codex/OWNER should add (do not let me edit the watch):

```python
try:
    d = json.load(open('D:/QM/reports/state/live_sleeve_drift.json'))
    s = d.get('summary', {})
    print('sleeve_drift', d.get('verdict'), 'dark', s.get('dark'), 'warmup', s.get('warmup_empty'))
    if d.get('verdict') == 'ALARM':
        al.append(f"sleeve_drift ALARM dark={s.get('dark')} warmup_empty={s.get('warmup_empty')} silent={s.get('silent')}")
except Exception as e:
    print('sleeve_drift err', e)
```
A companion scheduled task should run the monitor before the watch reads it (e.g.
after `live_book_pulse`), so the state file is fresh.

## Live result (2026-09-13T20:43Z, terminal RUNNING — fill-based)

**24 sleeves → 19 OK / 2 WARN / 3 ALARM. Overall: ALARM.**
Full table: `drift_report.md`; machine copy: `drift_report.json` (= the state file).

**ALARM (3):**
| Sleeve | days_live | λ_bt | expected | fills | placements | P(X≤obs) | alarms |
|---|--:|--:|--:|--:|--:|--:|---|
| 12778\|AUDUSD | 45 | 0.1120 | 5.04 | 0 | 0 | 0.0065 | `ALARM_DARK`, `ALARM_WARMUP_EMPTY` |
| 12969\|USDJPY | 45 | 0.1542 | 6.94 | 0 | 0 | 0.0010 | `ALARM_DARK` |
| 13117\|EURGBP | 44 | 0.1042 | 4.59 | 0 | 0 | 0.0102 | `WARN_LOW_ACTIVITY`, `ALARM_WARMUP_EMPTY` |

**WARN (2) — survive the fill test:**
- `1556|XAUUSD` **WARN_HIGH_ACTIVITY** — 6 fills / 6 placements vs 1.34 expected,
  P(X≥6)=0.0026. *Genuine over-trading* (every placement filled).
- `10440|NDX` **WARN_LOW_ACTIVITY** — 10 fills / 10 placements vs 17.5 expected,
  P(X≤10)=0.039. *Genuine under-activity.*

**Fill vs placement — 5 over-trading WARNs were placement artefacts (now OK):**
these sleeves place pending stop orders daily and cancel the unfilled leg.

| Sleeve | placements | fills | expected | old verdict | now |
|---|--:|--:|--:|---|---|
| 10403\|XAUUSD | 56 | 4 | 4.57 | WARN_HIGH | **OK** |
| 13213\|USDJPY | 60 | 30 | 32.7 | WARN_HIGH | **OK** |
| 13301\|GDAXI | 30 | 15 | 18.5 | WARN_HIGH | **OK** |
| 11421\|EURUSD | 24 | 5 | 2.53 | WARN_HIGH | **OK** |
| 11421\|AUDUSD | 18 | 3 | 2.61 | WARN_HIGH | **OK** |

Multi-symbol EAs (11165 / 11421 / 12567) are counted **per slot symbol**. The 3 ALARM
sleeves are unaffected (0 placements → 0 fills).

**Performance metric activated on real data:** the two busiest sleeves reached n≥10 —
13213 (n=12, mean-pct 0.95, MW p=0.95) and 13301 (n=11, mean-pct 0.78, p=0.78) — i.e.
live R ranks *at or above* backtest, so **no** `WARN_PERF` (correct). All others n<10.

## The three formerly-dark sleeves — what it would have raised, and when

All three are ALARM today; **12778 & 12969 are `ALARM_DARK` now, 13117 crosses the
`ALARM_DARK` boundary on 2026-09-14** (P today = 0.0102, one trading day over the 1%
bar) and is already ALARM via `ALARM_WARMUP_EMPTY`. Deterministic crossing dates
(validated with `--now`: as-of 2026-08-25 → dark=[12969]; as-of 2026-09-16 →
dark=[12778, 12969, 13117]):

| Sleeve | root cause | `ALARM_WARMUP_EMPTY` | `WARN_LOW_ACTIVITY` | `ALARM_DARK` |
|---|---|---|---|---|
| 12778\|AUDUSD | 4-sym cointegration basket, `BASKET_WARMUP loaded=0` | **2026-07-13 (day 1)** | 2026-08-18 | 2026-09-08 |
| 12969\|USDJPY | single USDJPY (gotobi/nakane); never traded live | n/a (not a basket) | 2026-08-07 | **2026-08-21** |
| 13117\|EURGBP | 4-sym basket, `BASKET_WARMUP loaded=0` | **2026-07-14 (day 1)** | 2026-08-21 | 2026-09-14 |

**Headline:** the monitor would have raised an ALARM on **12778 and 13117 within one
day of deploy** (baskets never loaded constituent history → structurally unable to
signal) and on **12969 by 2026-08-21** — instead of seven weeks of silence. The
day-1 structural `ALARM_WARMUP_EMPTY` catch is decisive: a pure Poisson activity test
needs 5–6 weeks to reach the 1% bar on a low-λ sleeve (and 13117 only reaches it at
week 9), which is exactly why the structural checks are included alongside activity.

## Open issues / limitations

1. **13117 activity P = 0.0102** sits just over the 1% `ALARM_DARK` bar under
   full-history λ; it is caught as ALARM via `ALARM_WARMUP_EMPTY` (day 1) and crosses
   `ALARM_DARK` on 2026-09-14. Trailing-2y λ (0.130) would make it `ALARM_DARK` today,
   but a recency window is a tuning knob and was deliberately **not** introduced.
2. **Live R excludes commission/swap** by construction (price-based R from entry/SL +
   paired journal exit deal). Realized per-trade P&L is not present in EA logs
   (`TM_CLOSE` has no profit) or journals, and `EQUITY_SNAPSHOT` is account-level;
   fabricating costs is barred, so R is a cost-free approximation. Round-trips whose
   exit deal cannot be matched (position still open, or journal older than 2026-04-24)
   are dropped, not guessed — so perf n is a lower bound.
3. **Over-trading is mostly a placement artefact.** Under fill-based counting only
   `1556|XAUUSD` (6 fills vs 1.34) genuinely over-trades; the other five earlier
   WARN_HIGH sleeves place many pending orders that are cancelled unfilled (e.g.
   10403 fills 4 of 56 placements). A high `placements/fills` ratio is itself worth a
   glance (churned pending orders / spread cost) but is not an activity alarm here.
4. **`observed` depends on journal coverage** (2026-04-24 → today). A sleeve deployed
   before the earliest journal, or whose fills predate it, would under-count fills;
   all current deploys (Jun–Jul) are covered.
5. Holidays are not modelled in the trading-day count (Mon–Fri only).

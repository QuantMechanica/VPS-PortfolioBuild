# 2026-07-24 — Live Book Max-DD Guard (ESC-01 implementation)

**Context:** Factory audit 2026-07-24 found the max-DD kill dead in practice for all
24 live sleeves: KS_PORTFOLIO_DD is deployed armed in existence-trip mode
(`QM_KillSwitch.mqh:435-436` — halt_pct=0.0 ⇒ signal-file existence halts), but no
process ever wrote a signal file (`evidence/framework__killswitch_portfolio_dd.txt`).
OWNER directed implementation of the full audit package ("alles umsetzen", chat
2026-07-24).

**Decision (operator, per OWNER package approval):** Build the missing producer as
`tools/strategy_farm/live_book_dd_guard.py` + scheduled task
`QM_StrategyFarm_LiveBookDDGuard` (SYSTEM, 5-min cadence):

- Equity source: `live_book_pulse.json` → `ea_logs.book_equity.equity`
  (EQUITY_SNAPSHOT account scope, ~30-min granularity).
- High-water mark persisted in `D:\QM\reports\state\live_book_dd_guard_state.json`;
  seeded from a one-time EQUITY_SNAPSHOT scan of the T_Live QM logs
  (seed 2026-07-24: HWM 101,871.44).
- **Halt threshold: 10.0% book drawdown from HWM** (Edge-Lab charter total-DD bound;
  env override `QM_BOOK_DD_HALT_PCT`). **OWNER-confirmed 10.0% on 2026-07-24**
  (decisions/2026-07-24_owner_approvals_audit_package.md). Alarm-not-auto-halt
  stale-telemetry policy likewise OWNER-approved same day.
- On breach: writes `portfolio_dd.signal` (JSON payload with dd/hwm/equity/ts) to
  BOTH paths the post-fix binaries poll: T_Live sandbox
  `MQL5\Files\QM\halt\portfolio_dd.signal` and FILE_COMMON
  `%APPDATA%\MetaQuotes\Terminal\Common\Files\QM\halt\portfolio_dd.signal`; emits a
  CRITICAL line to `health_alarms.log`. The breach latches.
- **Clearing a breach is OWNER-only:** delete both signal files and reset
  `breached` in the state JSON, in writing, after reviewing the drawdown.
- Fail-safe on stale input: pulse older than 120 min ⇒ guard logs itself BLIND
  (WARN alarm) instead of acting on stale equity.

**Known limitations (accepted):**
1. 11 of 24 live instances run pre-`47f1d9709` binaries whose file channel is dead —
   they cannot receive this halt until the 26.07 recompile wave (ESC-03). The guard
   is fully effective for the 13 post-fix instances now, book-wide after the wave.
2. Granularity is the pulse cadence (~30 min) — this is a book-level backstop behind
   the per-EA hardcoded 3% daily-loss kill, not a tick-level stop.
3. Windows PID/HWM state lives outside the repo (D:\QM\reports\state) per reports
   convention.

**Verification evidence:** dry-run + live run logs `D:\QM\reports\state\live_book_dd_guard.log`
(2026-07-24 06:47–06:48Z: HWM_SEEDED 101871.44, OK dd=0.1846%), state JSON, scheduled
task run result 0. No signal written (no breach). T_Live untouched beyond the
(unused) signal path.


## Addendum (same day) — codex implementation-review hardening

Codex adversarial review (task 2aa92baa, findings 5-7) drove three changes:
1. **Freshness now measured on the equity OBSERVATION** (`book_equity.ts_utc`),
   not just the pulse wrapper; strict ISO parse, future stamps rejected; invalid
   `generated_at_utc` no longer bypasses the gate. Measured EQUITY_SNAPSHOT
   cadence (gaps up to 20.6h intraweek, silent weekends) sets the default
   equity-age limit to 3000min (env `QM_BOOK_DD_MAX_EQUITY_AGE_MIN`).
2. **Signal is TERMINAL-LOCAL only** — the FILE_COMMON target was removed: no EA
   anywhere calls `QM_KillSwitchSetBookTag`, so a common-scoped signal would also
   trip the FTMO terminal's sleeves; and under the SYSTEM task `%APPDATA%`
   resolved into systemprofile (dead path). Revisit after book tagging ships.
3. **BLIND behavior hardened:** escalating alarm (WARN, CRITICAL from the 3rd
   consecutive blind run), latched breach signal re-asserted even while blind.
   DELIBERATE divergence from the review's fail-closed-halt recommendation:
   auto-flattening 24 live positions on a telemetry outage is an OWNER risk
   decision (NEEDS_FABIAN item 6); the per-EA 3% daily-loss kill stays armed
   throughout. A timer-driven EQUITY_SNAPSHOT cadence (wave item) will let the
   staleness limit tighten to ~2h.

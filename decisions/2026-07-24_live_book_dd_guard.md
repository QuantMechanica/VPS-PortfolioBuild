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
  env override `QM_BOOK_DD_HALT_PCT`). ⚠ OWNER may retune — flagged in
  NEEDS_FABIAN.md.
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

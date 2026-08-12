# V5 EA Framework Architecture Audit — 2026-07-20

**Scope:** `framework/include/QM/*.mqh`, lifecycle contract, risk/sizing path, filter
modules, trade management/exits, observability + build toolchain.
**Method:** 5 parallel Opus area reviewers (read-only), every claim anchored to
file:line; full area reports archived in session scratchpad `fwaudit/` (this doc is the
durable synthesis).
**Trigger:** OWNER request 2026-07-20 ("Analysiere das EA Framework! Braucht es rework?").

## Verdict: NO structural rework. Targeted hardening bundle + one coordinated recompile wave.

The core architecture is sound and several past war-wounds are verifiably healed:

- **Single OrderSend chokepoint** with a NO_MONEY latch that can never block
  risk-reducing requests (`QM_TradeContext.mqh:41-50,80`) — fail-stop cannot become
  fail-open on the exit side.
- **Q08 evidence truth = deal-history walk at shutdown** (`QM_Common.mqh:866-937`),
  ownership decided on the opening deal → server-side SL/TP fills (magic 0) correctly
  attributed. The 4.5× stream-undercount class is fixed at the emission layer.
- **News column-misalignment fix landed** (header-driven `QM_NewsLoadCsv`,
  `QM_NewsFilter.mqh:421-480`); **KillSwitch FileIsExist drive-path fix landed**
  (sandbox-relative + FILE_COMMON fallback, `QM_KillSwitch.mqh:458-468`); **DST math
  verified correct 2024-2027** (`QM_DSTAware.mqh:61-95`).
- **FX sizing is venue-portable** (backtest reconstructs tick_value = contract × tick ×
  quote→account FX, `QM_RiskSizer.mqh:280-285`); lots always FLOOR to volume_step —
  never silent over-risk.
- **build_check.ps1 is a real gate**, not section-presence theater: real compile,
  magic-formula + collision check, 13 setfile header keys, ML/WebRequest ban, static
  catches for RISK_MODE-unset and missing input groups.
- Magic schema `ea_id*10000+slot` collision-free by construction; resolver regen race
  mitigated by serial builds; CSV appends do NOT force fleet recompiles.

## P0 — Live-money critical (fix before/with the 26.07 deploy wave)

| # | Finding | Evidence | Fix |
|---|---------|----------|-----|
| P0.1 | **Q08 full-history walk runs in LIVE OnDeinit unguarded** — ~quadratic HistorySelect work inside MT5's ~2.7s deinit budget → force-kill; the likely cause of the observed live-restart "Abnormal termination" (3 EAs). Pure waste: Q08 is a tester gate. | `QM_Common.mqh:1016` (unconditional call), `:875-937` (two full passes), `:542` (nested HistorySelect per closing deal) | Wrap `:1012-1022` in `if(MQLInfoInteger(MQL_TESTER))` |
| P0.2 | **Per-trade risk cap frozen as MONEY at init-time equity** — silently defeats compounding in RISK_PERCENT mode and jumps on every re-init. Dormant for DXZ book (~0.4% sleeves < 1% cap) but **bites the FTMO scaled legs** (5% cap frozen at boot equity). | `QM_Common.mqh:174`, `QM_FrameworkSetRiskCapPct:315-316`, `QM_RiskSizer.mqh:72-74` | Store cap_pct; evaluate `cap = pct × current_equity` per trade |
| P0.3 | **KillSwitch halt-coverage 13/24 root cause = recompile debt**: binaries predating commit 47f1d9709 carry the dead absolute-path default → KS_MANUAL / KS_PORTFOLIO_DD silently ignored. 11 live sleeves cannot be halted via the file channel. **VERIFIED 2026-07-20:** read-only vintage scan shows 12 of 24 QM5 sleeve binaries on T_Live built 06-28/07-04 (pre-fix, halt-channel dead), 12 post-fix. Evidence: `D:\QM\reports\state\tlive_ks_vintage_20260720.csv`. | `QM_KillSwitch.mqh:458-473` (correct post-fix); fix commit 47f1d9709 dated 2026-07-05 21:12 | 26.07 recompile wave rebuilds all 24 sleeves → debt fully retired |
| P0.4 | **No held-period exit primitive** — 20004/20010 hand-roll re-init-fragile day counters; OnInit resets `g_days_elapsed=0` and the restart branch re-adopts today discarding accrued days → a mid-hold restart extends a 3-day monthly hold by up to N extra days. Same drift class as EQUITY_SNAPSHOT. | QM5_20004:113-123,163-164; grep QM_TM_TimeStop/PeriodExit = 0 hits | New `QM_TM_HeldPeriodExit` rehydrating elapsed periods from `PositionGetInteger(POSITION_TIME)` + `QM_CalendarPeriodKey` — restart-correct by construction |
| P0.5 | **Duplicate guard checks positions only, not pending orders** — bracket/breakout EAs (20006, 20010, opening-range family) can stack a second pending bracket on a repeated signal before the first fills → doubled exposure. | `QM_Entry.mqh:103-123` (PositionsTotal only) | Add same-magic+symbol OrdersTotal scan to the guard |
| P0.6 | **P1.11 portability still half-done**: live OnInit hard-fails when calendar CSVs absent/zero-rows although live decisions use the native MT5 calendar → boot single-point-of-failure for every news-active live sleeve (lapsed seed job / fresh terminal bricks init). | `QM_NewsFilter.mqh:556-561,595-599` → `QM_Common.mqh:189-200` → INIT_FAILED | Outside MQL_TESTER downgrade CSV-missing to WARN (native-calendar selftest already exists) |

## P1 — Evidence integrity

| # | Finding | Evidence | Fix |
|---|---------|----------|-----|
| P1.1 | **MAE tracking wired in only 2/3181 EAs** — `QM_FrameworkTrackOpenPositionMae` exists but is missing from the canonical OnTick template, so fleet-wide Q08 MAE collapses to `MathMin(0, net)` (realized floor, not worst floating excursion). | `QM_Common.mqh:491,514-526,928-930`; grep 2/3181 | Add the call to the generated OnTick template; document lifecycle contract |
| P1.2 | **EQUITY_SNAPSHOT conflates account equity with per-symbol tag** — every sleeve on the shared live account emits identical account-wide equity/day_pnl under its own symbol → per-symbol attribution multiplies book equity by sleeve count. | `QM_EquityStream.mqh:109-122`; consumer `q08_davey/common.py:48` | Emit account scope explicitly (scope field) or per-magic realized PnL; fix consumers |
| P1.3 | **EQUITY_SNAPSHOT day/month baseline resets on every re-init** (no persistence, unlike KillSwitch state) → recompile wave zeroes day/month attribution mid-window. | `QM_EquityStream.mqh:85-93` | Persist baselines (GlobalVariables or file) keyed by day/month |
| P1.4 | **Silent sizing clamps leave no evidence** — per-trade cap and free-margin×0.90 binds reduce lots with no QM_LogEvent (violates evidence-over-claims; later-firing sleeves on a shared account size margin-dependent, invisibly). | `QM_RiskSizer.mqh:72-74,92-94,117-119,385-389,436-440,491-495` | Log when cap/margin binds below risk-target lots |
| P1.5 | **Tester news path has no symbol-scoped selftest** — currency-column drift that breaks symbol matching (but parses datetimes) would reintroduce the inert-filter mode undetectably. Live has the selftest; tester only asserts rows>0. | `QM_NewsFilter.mqh:595-599,1271-1279` vs live `:957-994` | Tester init assertion: count symbol-matched events, log NEWS_TESTER_CALENDAR_SELFTEST |
| P1.6 | **Event log unversioned + undocumented; bare TRADE_CLOSED second schema coexists** with the enveloped QM_LogEvent stream; build_check's logger-schema gate validates an embedded literal when no sample is supplied (vacuous PASS). | `QM_Logger.mqh:177-189`, `QM_Common.mqh:932`, `build_check.ps1:429,487-506` | `"sv":1` in envelope + checked-in event-vocabulary registry; wire `-LoggerSamplePath` from smoke runs |
| P1.7 | **SeedRNG "independent sub-streams" are not independent** — tagged draws XOR into the ONE global cursor; determinism holds only for fixed call order; a refactor adding a draw silently re-randomizes all downstream sequences (Q06/Q07 stress reproducibility). | `QM_SeedRNG.mqh:17-20,63-69,102-106` | Document the real guarantee now; true per-tag streams only if ever needed |
| P1.8 | **Non-FX sizing path unverified** (PLAUSIBLE): indices/metals/commodities bypass the reconstructed tick_value path; fallback `contract_size × point` ignores quote→account FX. Needs an MT5 tick_value dump on .DWX indices before weighting. | `QM_RiskSizer.mqh:249-294,301-312,325` | Verification script on a parked terminal; fix only if dump shows divergence |

## P2 — Hardening / quality (bundle opportunistically)

- **Stops/freeze-level clamp + per-ticket modify dedup** in `QM_TM_SendSLTPModify`
  (`QM_TradeManagement.mqh:55-89`; no SYMBOL_TRADE_STOPS_LEVEL check anywhere) — kills
  the per-tick `[Invalid stops]` spam loop for all trailing/BE users.
- **`QM_Sig_SessionMinutes(start_hhmm,end_hhmm)`** — session primitive is hour-granular
  only (`QM_Signals.mqh:191-201`); 20006 hand-rolled 16:30/22:30. Same copy-paste class
  that produced symbol_slot UB.
- **Partial-close reason overwrite** (`QM_Exit.mqh:314`) — keep true reason + separate
  `is_partial` flag (exit-surgery analytics parse cleanly).
- **Live SKIP_DAY window skewed 2-3h** (UTC-midnight math centered on server time,
  `QM_NewsFilter.mqh:1019-1023`) — real boundary error, rarely-used mode.
- **Friday-close has no half-day/holiday awareness** (`QM_Common.mqh:375-389`) — fine
  for FX, matters for index/commodity sleeves.
- **TM_CLOSE stream omits server-side fills by design** — document that live position
  truth = broker sync, never the event log (10940 lesson, contract note).
- **build_check waiver language repaired** (`build_check.ps1:237`) — warning
  waivers now require OWNER sign-off in gate evidence.
- **Resolver array**: keep compiled design (correct for live), prune retired rows +
  binary-search the lookup; T_Live verify must compare the EA's OWN row, never the
  whole-file SHA vs CSV.
- **Generalize the FTMO-governor compile-test pattern** to QM_Logger / QM_EquityStream /
  QM_SeedRNG / QM_RiskSizer / QM_KillSwitch (currently zero include-level coverage) —
  cheap regression insurance before recompile waves hit the live book.
- **RUN_CONFIG provenance event at INIT_OK** (model/seed/spread/commission) — proves
  Model-4 real-tick in the evidence file itself.
- **Deinit-budget telemetry** (warn >1s) — catches the P0.1 class before it bites.
- **Framework spread-guard primitive** (`QM_SpreadGuard(symbol,max_points)`).
- **Explicit lifecycle contract doc + wiring assertion** — design-doc skeleton is 3
  lines; the real required hooks live implicitly in the generator (root cause of P1.1).

## Deployment strategy

Include edits force a recompile wave across the live book — the **26.07 dual-book
deploy is the natural vehicle**: one wave ships the P0 bundle AND retires the
KillSwitch coverage debt (P0.3) simultaneously. Order: include edits → include
compile-tests → rebuild deploy candidates + live-book survivors serially → SHA manifest
→ standard T_Live procedure. FTMO demo book MUST carry P0.2 (frozen 5% cap) and P0.4
(held-period exits) — both bite FTMO harder than DXZ.

Deferred (explicitly not now): SeedRNG stream redesign, Friday-close exchange-calendar
coupling, resolver pruning, event-schema v2 beyond the version field.

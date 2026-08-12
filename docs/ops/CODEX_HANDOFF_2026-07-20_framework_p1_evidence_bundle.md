# Codex Handoff 2026-07-20 — Framework P1 Evidence Bundle

**Context:** The 2026-07-20 framework audit (`docs/ops/EA_FRAMEWORK_AUDIT_2026-07-20.md`)
produced a P0 bundle that Claude has already landed and compile-verified
(commits 5b21b9b1d part 1 via pump sweep, 37196e79d part 2, compile test
0295ba5a6 — compile_one PASS 0/0). This handoff covers the **P1 evidence-integrity
items** that need consumer-side coordination. Work rules: serial builds, explicit
commit pathspecs, no manual exec sessions while factory automation runs, evidence
paths on every claim.

## H1 — MAE hook into the canonical OnTick (audit P1.1) — HIGHEST VALUE

`QM_FrameworkTrackOpenPositionMae()` exists (`QM_Common.mqh:491`) but only 2 of
3181 EAs call it, so the Q08 stream's `mae_acct` collapses to `MathMin(0, net)`
for the whole fleet (realized floor instead of worst floating excursion).

1. Add the call to the canonical per-tick sequence in the EA build template /
   generator prompt (the same place that wires news/friday-close/killswitch into
   OnTick), so every future build carries it.
2. Add a build_check static assertion (pattern: `EA_RISK_SIZER_UNCONFIGURED` at
   `build_check.ps1:650-680`): WARN when an EA source contains `OnTick` but no
   `QM_FrameworkTrackOpenPositionMae` call. WARN, not FAIL — existing fleet
   rebuilds should not brick on it during the 26.07 wave; flip to FAIL after the
   wave lands.
3. Note in the Q08 sub-gate docs that MAE-based evidence generated before the
   wave is realized-floor MAE (do NOT recalibrate MAE gates against old streams).

## H2 — EQUITY_SNAPSHOT scope + baseline persistence (audit P1.2 + P1.3)

`QM_EquityStream.mqh:85-122`: (a) emits account-wide equity/day_pnl/month_pnl
tagged with `_Symbol` → per-symbol consumers on the shared live account
over-count by the sleeve count; (b) day/month baselines reset to current equity
on every re-init.

1. Add `"scope":"account"` to the EQUITY_SNAPSHOT payload (schema-additive, no
   consumer breaks) and fix `q08_davey/common.py:load_equity_stream` consumers to
   never sum equity across symbols of one account.
2. Persist day/month baselines keyed by (ea_id, day-key/month-key) — GlobalVariables
   (`GlobalVariableSet/Get`, terminal-persistent) is sufficient; restore on init
   when the stored key matches the current day/month, else re-baseline. Mirror
   the KillSwitch `KS_STATE_RESTORED` logging pattern.

## H3 — Tester news symbol-scoped selftest (audit P1.5)

Live has `QM_NewsLiveSelfTest` (`QM_NewsFilter.mqh:957-994`); tester init only
asserts rows>0. A currency-column drift that breaks symbol matching (but parses
datetimes) would reintroduce the inert-filter mode invisibly.

- At tester init (news-active only): count events matching the chart symbol's
  currencies across the loaded array; emit `NEWS_TESTER_CALENDAR_SELFTEST`
  with the count; **FAIL init when count == 0** for a symbol whose currency set
  is non-empty — zero matches over a decade of calendar is always drift, never
  a valid state (same reasoning as the zero-rows guard at :595).

## H4 — Event-log versioning + vocabulary registry (audit P1.6)

1. Add `"sv":1` to the QM_LogEvent envelope (`QM_Logger.mqh:177-189`).
2. Generate `framework/registry/event_vocabulary.json` from the code (grep all
   `QM_LogEvent(` event names) with a small script under `framework/scripts/`;
   check it in; build_check asserts every event name an EA emits is registered
   (WARN on unknown). Include the bare TRADE_CLOSED line as an explicitly
   documented second schema (`stream: q08_trades`).
3. Wire `-LoggerSamplePath` in the farm's build_check invocation from the most
   recent smoke-run JSONL so the logger-schema gate stops validating its own
   embedded literal (`build_check.ps1:487-506`).

## H5 — Non-FX tick_value verification (audit P1.8, VERIFY before any fix)

Plausible-only finding: indices/metals/commodities bypass the reconstructed
tick_value path (`QM_RiskSizer.mqh:249-312`); fallback `contract_size*point`
ignores quote→account FX. Write an MT5 script (parked/free terminal only, ad-hoc
harness rules) that dumps `SYMBOL_TRADE_TICK_VALUE/TICK_SIZE/CONTRACT_SIZE` for
NDX/WS30/SP500/GDAXI/XAUUSD/XTIUSD/XNGUSD `.DWX` symbols + the account currency,
CSV to `D:\QM\reports\state\dwx_tickvalue_dump_<date>.csv`. Compare against what
`QM_LotsForRiskFromSnapshot` computes. Only if divergent: fix behind a flag and
coordinate with Claude — sizing changes shift backtest evidence.

## Sequencing

H1/H3/H4 are include+toolchain edits → they ride the **26.07 recompile wave**
(coordinate timing with Claude; includes must be final before the wave's serial
rebuilds start, target Fri 25.07 EOD). H2 consumer fix + H5 dump can land any
time. Do not start a manual exec session while factory automation runs — use the
agent_tasks lane.

# STR-097 / QM5_20096 — Build smoke record (2026-07-24)

## Verdict

**Smoke BLOCKED_INFRA** — no valid Model-4 tester host available. The EA itself
is compile-clean (0/0 strict), build_check PASS, and the zero-trade smoke
results below are **invalid environment evidence, not an EA defect** (proven by
control EA, see §3).

## 1. Smoke attempts (all on T5, GBPUSD.DWX H4 2024, `-MinTrades 1 -SmokeMode`)

| # | Binary | Result | Evidence |
|---|--------|--------|----------|
| 1 | committed 67d9a3d24 (source-faithful same-bar cross) | FAIL `MIN_TRADES_NOT_MET` (0 trades) | `D:\QM\reports\smoke\QM5_20096\20260724_101658\` (first attempt, pre-diagnosis) |
| 2 | diag set `strategy_stoch_zone=100` | FAIL 0 trades — **invalid diagnostic**: zone=100 trips the NoTradeFilter param sanity (`zone >= 100` blocks all ticks) | `D:\QM\reports\smoke\QM5_20096\...zone100` runs |
| 3 | variant XWIN3 (cross window 3) | FAIL 0 trades | `D:\QM\reports\smoke\QM5_20096\20260724_115204\` |
| 4 | instrumented diag build (counters) | FAIL 0 trades — **root cause isolated**, see §2 | `D:\QM\reports\smoke\QM5_20096\20260724_120758\`, `20260724_121153\`, `20260724_121659\` |

## 2. Root cause of 0 trades on T5 (instrumented evidence)

Diagnostic counters (STRATEGY_DIAG events in the tester agent logs) show over
28,000,000 ticks in 2024:

- `Strategy_EntrySignal` was **never called** (0 calls all year).
- `Strategy_NoTradeFilter` blocked **every tick** at the `BarsCalculated` warmup
  check: `BarsCalculated(handle) == -1` permanently for BOTH handles
  (iMA SMA100 H4 = handle 10, iStochastic 8,3,3 = handle 11), while
  `Bars(_Symbol, PERIOD_H4)` grew normally 1594 → 3083.
- Switching handle creation `PERIOD_H4` → `PERIOD_CURRENT` changed nothing.
- Wiping T5's tester agent scratch dirs (backed up to
  `D:\QM\mt5\T5\Tester\_agent_bak_20260724\`) changed nothing.

**T5's tester price engine works (ticks, bars, framework events, news calendar,
52 Friday sweeps) but its built-in indicator engine never computes
(BarsCalculated=-1 forever).** T5 was parked 2026-07-07 as
`t5_account_missing` (see
`D:\QM\strategy_farm\state\disabled_terminals.txt.bak_before_t5_account_missing_20260707T0622Z`);
its config now looks complete (accounts.dat/servers.dat present, common.ini
identical to T2), so the residual defect is deeper terminal state.

## 3. Control proof (EA innocent, environment guilty)

QM5_11144_vbt-macd-zero — a Q02-passed production EA — was smoked unchanged on
T5 (GBPUSD.DWX D1 2024): **also 0 trades / MIN_TRADES_NOT_MET**, twice
(pre- and post-agent-wipe). Evidence:
`D:\QM\reports\smoke\QM5_11144\20260724_122118\` and `...\20260724_122534\`.
An indicator-based EA cannot produce valid smoke evidence on T5.

## 4. XWIN3 amendment REVERTED

The interim variant HASTOCH_097_XWIN3 (stoch cross within last 3 closed bars)
was premised on the belief that the source-faithful same-bar-cross conjunction
was empirically empty. That belief rested entirely on invalid T5 evidence
(§2/§3) — the entry hook had in fact never executed. The working tree was
restored to the committed, source-faithful implementation (67d9a3d24); the
strategy card was never amended, so card, spec (04_spec_final.md) and source
remain consistent. If a **valid** smoke later shows genuine zero trades, the
XWIN3 question returns as a spec-level reconciliation item — not before.

## 5. Alternative hosts evaluated (all dead ends today)

- **Factory T1–T10 via dispatcher (`-Terminal any`):** `no_capacity` — 9 workers
  own all terminals, backtest queue 2311 pending (pre-wave saturation).
- **T_Export:** free, full config + DWX bar history, but `bases/Custom/ticks`
  is empty (4 KB vs 37 GB on T2) → Model-4 real-tick runs impossible
  (`NO_REAL_TICKS;INCOMPLETE_RUNS;MODEL4_MARKER_REQUIRED`). A temporary
  run_smoke ValidateSet extension for T_Export was tested and reverted.
- **DEV1/DEV2:** run_smoke's identity guard requires the isolated
  `WIN-B95G5LPSJ1O\QMDev1` SID; current session is Administrator. Guard is a
  deliberate policy — not overridden.
- **T_Live:** off limits (hard rule).

## 6. Path forward

Next legitimate smoke window: **Sunday 2026-07-26 wave OFF window** (all
factory terminals free before workers restart) — smoke all three harvest EAs
there, then enqueue Q02. Alternative: repair T5's indicator engine (terminal
state rebuild — OWNER-session task, see NEEDS_FABIAN). Decision item recorded
in `docs/ops/source_harvest/audit/NEEDS_FABIAN.md`.

## OWNER override (2026-07-24, mid-run)

OWNER directive: *"die neuen EAs einfach in die Factory einreihen, keine
Priorisierung!"* — the build-smoke requirement is consciously waived for the
saturated-factory situation; the EA joins the normal Q02 queue at default
priority. Q02's own MIN_TRADES/evidence discipline performs the aliveness check
this smoke would have provided (a dead EA fails Q02 quickly and cheaply). The
Sunday wave-OFF smoke plan in NEEDS_FABIAN item 7 is superseded.

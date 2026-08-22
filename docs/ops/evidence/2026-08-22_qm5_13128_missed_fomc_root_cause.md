# QM5_13128 missed 2026-07-29 FOMC event — read-only root cause

Date: 2026-08-22  
Scope: T_Live read-only evidence plus canonical repository lineage  
Verdict: `STALE_LIVE_BINARY_FIXED_EVENT_TABLE`; requalification required before any deploy

## Root cause

T_Live is running the pre-remediation July 13 binary. Its fixed FOMC date table ends at `2025-12-10`, so `2026-07-29` is not a signal date in the executing program.

This is deterministic and supersedes the earlier `BUG_SUSPECTED_EXACT_HOUR_VENUE_WINDOW` hypothesis in `2026-08-22_sp_e4_dead_dxz_sleeves_diagnosis.md`.

Evidence chain:

1. T_Live binary `C:/QM/mt5/T_Live/MT5_Base/MQL5/Experts/Live EAs/QM5_13128_pre-fomc-drift-ndx.ex5` has SHA-256 `364867a9fe8d58478ade5526aad19deb377a35b313cfdac29763bb2eb82d273b`, size 322,536 bytes, and a July 13 timestamp. It matches the older DEV1 binary.
2. Every live `INIT_OK` record reports `events:57` and lacks the later `calendar_valid_through` field.
3. The initial source at commit `7cc4e7f4258db5a52a0395e71cd42464c3828e84` contains exactly 57 dates, ends at `20251210`, and does not contain `20260729`.
4. Commit `2b7e73b83229a8b340e3ac1e57580c8613c8f240` added exactly eight 2026 dates, including `20260729`, plus an explicit `20261231` fail-closed horizon. Commit `027f45752cf50a38428f0365eff28d013442a1cd` completed the H1 gate correction.
5. The canonical binary now has SHA-256 `59b9d1657fb04a9f33a030d420da76a1cae92c4223f4404842a53feed1848370` and differs from T_Live.
6. `framework/registry/dxz23_execution_contracts.json` already marks QM5_13128 `REQUAL_REQUIRED` and promotion `BLOCKED`, including `remediated_binary_not_requalified` and the card/source calendar conflict.

The live program therefore evaluated `Strategy_IsEventDateKey(20260729)` as false. It could not emit an entry regardless of NDX session ticks, ATR, spread, or order routing. The exact-hour theory is not needed to explain the miss.

## Live log and entry-gate evidence

The structured live log contains 305 valid JSON rows from 2026-07-13 through 2026-08-21:

- 29 `INIT_OK` events, each with `events:57`;
- 28 `EQUITY_SNAPSHOT` events;
- zero `ENTRY_ACCEPTED`, `ENTRY_REJECTED`, `TM_OPEN`, or order-attempt events;
- no setup-data error for calendar coverage, because that fail-closed horizon was added only in the remediated source.

The EA was initialized on 2026-07-27 at broker `20:33` and remained present across the D-1 entry date. It reinitialized on the event day, but by then the intended D-1 window had passed. The log does not emit per-condition entry diagnostics. Source lineage nevertheless makes the missing calendar membership conclusive.

## Setfile and gate chain

Active chart profile: `C:/QM/mt5/T_Live/MT5_Base/MQL5/Profiles/Charts/DarwinexZero_V3/chart10.chr`, SHA-256 `7e2e5ce3857cf9bc3382110fc9d35d2b8bf0306f9eca4c7af3916cd849f75652`.

Effective inputs are:

- H1, entry broker hour 21, exit broker hour 20;
- ATR(14), stop 2.0 ATR;
- `RISK_PERCENT=1`, `RISK_FIXED=0`, portfolio weight 1;
- news temporal OFF, compliance NONE, legacy mode OFF;
- Friday close enabled at broker hour 21.

The effective entry path is kill switch → news hook → framework news gate → Friday handler → H1/D1-history filter → new-H1-bar gate → fixed-table tomorrow lookup → ATR/ask/stop checks → market order. On 2026-07-28 the fixed-table lookup was the decisive false condition.

## News calendar binding

QM5_13128 does not use the shared news CSV as its signal calendar. Its live log explicitly records `NEWS_CALENDAR_SKIPPED` with `all_news_axes_off`, `OFF/NONE/OFF`. The strategy signal is the compiled `g_event_dates[]` table.

The current canonical and FILE_COMMON `news_calendar_2015_2025.csv` copies are hash-identical (`42b02ae062271b643a9039410617a4c246ebed62c9a77db2e8b610fee6ce82bc`) and now include Federal Funds Rate and FOMC Statement rows at `2026-07-29 18:00:00`. A sibling NDX EA also logged a healthy shared-calendar self-test on the event day. These facts exclude the current shared calendar as the repair target for this miss; ticket `3260d15d` and the broader coverage-gap cohort cannot add a date to an already deployed compiled table.

There is a separate configuration conflict requiring adjudication: the live profile disables all news axes, while the Q10 confirmation set enables `PRE30_POST30/DXZ`. The canonical source comments say news is disabled to avoid blocking the timed exit. Because the active charter requires a mandatory news blackout, the remediated binary must not be copied into T_Live without resolving and requalifying this semantic mismatch.

## OWNER decision template

Recommended disposition: keep the sleeve unchanged but treat it as non-operational for future FOMC entries until a governed requalification and deploy approval are complete.

Proposed OWNER record:

> QM5_13128 is confirmed to have missed the 2026-07-29 signal because T_Live ran binary SHA-256 `364867...`, whose 57-date compiled calendar ended in 2025. I do not authorize an in-place binary or setfile change. Development must reconcile the approved card, fixed-calendar horizon, live-versus-Q10 news semantics, mandatory blackout, and flat-before-statement exit; then run the governed Q-only requalification on the exact proposed binary/set pair. LiveOps may deploy only under a separate OWNER-signed manifest that pins binary, setfile, calendar contract, evidence, and rollback target, with AutoTrading remaining under OWNER control.

Minimum proof before such a manifest:

1. exact binary and setfile hashes;
2. replay of at least one known 2026 meeting proving D-1 entry and event-day flat exit;
3. closed-market/session-boundary probe around broker hours 20/21;
4. explicit per-gate diagnostic evidence for calendar membership, new-bar availability, ATR, news, and order result;
5. reconciliation of live OFF/NONE with Q10 `PRE30_POST30/DXZ` and the charter's mandatory blackout;
6. current fixed-calendar horizon plus fail-closed behavior beyond it;
7. pipeline-produced requalification verdict and separate deploy verification.

## Safety record

No T_Live file, chart, setfile, binary, profile, terminal process, AutoTrading state, or position was modified. No recompile or pipeline phase was run.
